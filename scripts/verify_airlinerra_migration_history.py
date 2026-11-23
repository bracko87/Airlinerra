#!/usr/bin/env python3
"""Verify Airlinerra migration filenames and immutable production-verified SQL.

This script has no network access. The manifest records 14 files that were
byte-for-byte compared with their original SQL bodies stored in the connected
Airlinerra Supabase migration history on 2026-11-23.
It does not assert that the remaining migration archive is production-ready.
"""
from __future__ import annotations
from pathlib import Path
import hashlib
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / "supabase" / "migrations"

PROVENANCE = json.loads((ROOT / "data" / "migrations" / "airlinerra_recorded_sql_provenance_2026-11-23.json").read_text(encoding="utf8"))["entries"]

def git_blob_sha(contents: bytes) -> str:
    header = b"blob " + str(len(contents)).encode("ascii") + b"\0"
    return hashlib.sha1(header + contents).hexdigest()

def main() -> int:
    errors = []
    paths = sorted(MIGRATIONS.glob("*.sql"))
    version_map = {}
    for path in paths:
        if not re.fullmatch(r"\d{14}_.+\.sql", path.name):
            errors.append(f"Invalid migration filename: {path.name}")
        version_map.setdefault(path.name[:14], []).append(path.name)
    for version, names in version_map.items():
        if len(names) != 1:
            errors.append(f"Duplicate migration timestamp {version}: {names}")
    for entry in PROVENANCE:
        old = MIGRATIONS / entry["historical"]
        new = MIGRATIONS / entry["verified"]
        if old != new and old.exists():
            errors.append(f"Old duplicate name reappeared: {old.name}")
        if not new.is_file():
            errors.append(f"Verified migration missing: {new.name}")
        elif git_blob_sha(new.read_bytes()) != entry["blob"]:
            errors.append(f"Authoritative SQL modified in place (use a forward-only migration): {new.name}")

    # Check runtime references, not historical docs or this manifest itself.
    for folder in (".github/workflows", "scripts", "server", "tests", "website"):
        root = ROOT / folder
        if not root.is_dir():
            continue
        for file in root.rglob("*"):
            if not file.is_file() or file == Path(__file__) or file.stat().st_size > 3_000_000:
                continue
            if file.suffix not in (".py", ".mjs", ".js", ".ts", ".yml", ".yaml", ".sql", ".json", ".md"):
                continue
            try:
                body = file.read_text(encoding="utf8")
            except UnicodeDecodeError:
                continue
            for entry in PROVENANCE:
                if entry["historical"] != entry["verified"] and entry["historical"] in body:
                    errors.append(f"Stale migration filename reference in {file.relative_to(ROOT)}: {entry['historical']}")

    if errors:
        print("\n".join("BLOCKER: " + s for s in errors))
        return 1
    print(f"PASS: {len(paths)} unique migration versions; {len(PROVENANCE)} byte-verified historical SQL bodies preserved")
    print("NOTE: This is provenance/integrity validation, not proof of full local database replay.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
