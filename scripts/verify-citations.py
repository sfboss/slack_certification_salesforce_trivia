#!/usr/bin/env python3
"""Verify Question_Citation__c URLs are reachable (HTTP 2xx/3xx) via HEAD requests.

Usage:
  python scripts/verify-citations.py --username me@example.com [--limit 500]

Reads citations from the org via simple-salesforce, then issues HEAD requests
(falling back to GET when HEAD is disallowed) with a short timeout, printing a
summary and a list of failed URLs. Optionally writes a CSV report.
"""
from __future__ import annotations

import argparse
import csv
import os
import sys
from typing import List, Tuple

import requests
from simple_salesforce import Salesforce

DEFAULT_TIMEOUT = 10
DEFAULT_LIMIT = 1000


def fetch_citations(sf: Salesforce, limit: int) -> List[Tuple[str, str, str]]:
    soql = (
        "SELECT Id, Title__c, URL__c FROM Question_Citation__c "
        f"WHERE URL__c != null LIMIT {limit}"
    )
    rows = sf.query_all(soql)["records"]
    return [(r["Id"], r.get("Title__c") or "", r["URL__c"]) for r in rows]


def check(url: str) -> Tuple[int, str]:
    try:
        r = requests.head(url, timeout=DEFAULT_TIMEOUT, allow_redirects=True)
        if r.status_code == 405:
            r = requests.get(url, timeout=DEFAULT_TIMEOUT, allow_redirects=True, stream=True)
        return r.status_code, ""
    except requests.RequestException as e:
        return 0, str(e)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--username")
    ap.add_argument("--password")
    ap.add_argument("--token", default=os.environ.get("SF_TOKEN", ""))
    ap.add_argument("--domain", default=os.environ.get("SF_DOMAIN", "login"))
    ap.add_argument("--limit", type=int, default=DEFAULT_LIMIT)
    ap.add_argument("--csv", default="")
    args = ap.parse_args()

    sf = Salesforce(
        username=args.username or os.environ["SF_USERNAME"],
        password=args.password or os.environ["SF_PASSWORD"],
        security_token=args.token,
        domain=args.domain,
    )
    rows = fetch_citations(sf, args.limit)
    print(f"Checking {len(rows)} citations…")

    failed: List[Tuple[str, str, str, int, str]] = []
    for cid, title, url in rows:
        status, err = check(url)
        ok = 200 <= status < 400
        if not ok:
            failed.append((cid, title, url, status, err))
            print(f"FAIL [{status}] {url} {err}")
    print(f"Done. {len(failed)} failures.")
    if args.csv:
        with open(args.csv, "w", newline="") as fp:
            w = csv.writer(fp)
            w.writerow(["Id", "Title", "URL", "Status", "Error"])
            w.writerows(failed)
        print(f"Wrote {args.csv}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
