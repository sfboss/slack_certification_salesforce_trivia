#!/usr/bin/env python3
"""
Bulk-load every *.sample.json question pack in sample_data/ into the target org,
then publish all imported questions so they are immediately playable in Slack.

Usage:
    python scripts/import_all_packs.py [--org certgame] [--no-publish] [--only PATTERN]

Requires the Salesforce CLI (`sf`) to be authenticated to the target org.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PACKS_DIR = REPO_ROOT / "sample_data"


def apex_escape(s: str) -> str:
    return (
        s.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("\n", "\\n")
        .replace("\r", "")
    )


def run_apex(org: str, snippet: str) -> tuple[bool, str]:
    with tempfile.NamedTemporaryFile("w", suffix=".apex", delete=False) as f:
        f.write(snippet)
        path = f.name
    try:
        proc = subprocess.run(
            ["sf", "apex", "run", "-o", org, "-f", path],
            capture_output=True,
            text=True,
        )
        out = proc.stdout + ("\n" + proc.stderr if proc.stderr else "")
        return proc.returncode == 0, out
    finally:
        try:
            os.unlink(path)
        except OSError:
            pass


def import_pack(org: str, pack_path: Path) -> bool:
    raw = pack_path.read_text()
    # Validate JSON parses before sending to org
    try:
        json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"  SKIP — invalid JSON: {e}")
        return False
    escaped = apex_escape(raw)
    snippet = (
        f"String j = '{escaped}';\n"
        "CertGameImportService.ImportResult r = CertGameImportService.importPack(j);\n"
        "System.debug('IMPORT_RESULT success=' + r.success + ' created=' + r.questionsCreated"
        " + ' updated=' + r.questionsUpdated + ' errors=' + r.errors);\n"
    )
    ok, out = run_apex(org, snippet)
    for line in out.splitlines():
        if "IMPORT_RESULT" in line or "ERROR" in line.upper() and "DEBUG" not in line:
            print("  " + line.strip())
    return ok


def publish_all(org: str) -> bool:
    snippet = (
        "Integer n = CertGameExamManager.publishAll(null);\n"
        "System.debug('PUBLISH_RESULT count=' + n);\n"
    )
    ok, out = run_apex(org, snippet)
    for line in out.splitlines():
        if "PUBLISH_RESULT" in line:
            print(line.strip())
    return ok


def print_summary(org: str) -> None:
    snippet = (
        "for (CertGameExamManager.ExamStats s : CertGameExamManager.listAll()) {\n"
        "    System.debug('EXAM ' + s.code + ' active=' + s.active"
        " + ' published=' + s.published + ' draft=' + s.draft + ' total=' + s.total);\n"
        "}\n"
    )
    ok, out = run_apex(org, snippet)
    print("\n=== Exam catalog ===")
    for line in out.splitlines():
        if "EXAM " in line and "DEBUG" in line:
            # strip "USER_DEBUG|...|" prefix
            idx = line.find("EXAM ")
            print("  " + line[idx:].strip())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--org", default="certgame", help="sf org alias (default: certgame)")
    parser.add_argument("--no-publish", action="store_true", help="Skip the bulk-publish step")
    parser.add_argument("--only", default=None, help="Glob substring filter for pack filenames")
    args = parser.parse_args()

    packs = sorted(PACKS_DIR.glob("*.json"))
    if args.only:
        packs = [p for p in packs if args.only in p.name]
    if not packs:
        print(f"No packs found in {PACKS_DIR}")
        return 1

    print(f"Found {len(packs)} pack(s) to import into org '{args.org}'.")
    failures = []
    for p in packs:
        print(f"\n>>> {p.name}")
        if not import_pack(args.org, p):
            failures.append(p.name)

    if args.no_publish:
        print("\nSkipping publish step (--no-publish).")
    else:
        print("\n>>> Publishing all Draft/Reviewed questions")
        publish_all(args.org)

    print_summary(args.org)
    if failures:
        print(f"\nFailed packs: {failures}")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
