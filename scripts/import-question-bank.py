#!/usr/bin/env python3
"""
Import a Cert Game question pack into a Salesforce org via Apex anonymous.

Usage:
  python3 scripts/import-question-bank.py --org certgame --file sample_data/adm201-question-pack.sample.json

Requires `sf` CLI configured for the target org. Validates locally first.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path


def run_sf(org: str, apex: str) -> int:
    return subprocess.call(
        ["sf", "apex", "run", "-o", org, "-f", "/dev/stdin"],
        stdin_data=apex,
    ) if False else _exec(["sf", "apex", "run", "-o", org], apex)


def _exec(cmd, stdin: str) -> int:
    proc = subprocess.run(cmd + ["--file", "-"], input=stdin, text=True)
    return proc.returncode


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--org", required=True, help="sf CLI alias for the target org")
    parser.add_argument("--file", required=True, help="Path to pack JSON")
    args = parser.parse_args()

    path = Path(args.file)
    pack = json.loads(path.read_text())

    # Local validate first
    validator = Path(__file__).parent / "validate-question-json.py"
    rc = subprocess.call([sys.executable, str(validator), str(path)])
    if rc != 0:
        print("Local validation failed. Aborting.", file=sys.stderr)
        sys.exit(rc)

    payload = json.dumps(pack).replace("\\", "\\\\").replace("'", "\\'")
    apex = (
        "String body = '"
        + payload
        + "';\n"
        + "CertGameImportService.ImportResult r = CertGameImportService.importPack(body);\n"
        + "System.debug(LoggingLevel.INFO, '##CGIMPORT## ' + JSON.serialize(r));"
    )

    tmp = Path(".sf-import-apex.txt")
    tmp.write_text(apex)
    try:
        rc = subprocess.call(["sf", "apex", "run", "-o", args.org, "-f", str(tmp)])
    finally:
        tmp.unlink(missing_ok=True)
    sys.exit(rc)


if __name__ == "__main__":
    main()
