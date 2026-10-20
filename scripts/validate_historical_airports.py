#!/usr/bin/env python3
"""Validate recovered historical airport names; never activate them automatically."""
import csv
import pathlib
from collections import Counter

ROOT = pathlib.Path(__file__).resolve().parents[1]
PATH = ROOT / "data/airports/historical_approved_recovery.csv"
GROUPS = {"1": {"AL","AM","AT","AZ"}, "2": {"BY","BE","BA","BG","HR"}, "3": {"CY","CZ","DK","EE","FI"}}
BASELINE = {"1": 9, "2": 11, "3": 36}
with PATH.open(encoding="utf-8-sig",newline="") as source:
    reader=csv.DictReader(source)
    expected={"group","country_iso","airport_name","reported_code","reported_code_type","historical_category","historical_decision","validation_status","gameplay_import","provenance"}
    assert expected.issubset(set(reader.fieldnames or [])), "Missing required recovery fields"
    rows=list(reader)
seen=set()
counts=Counter()
for number,row in enumerate(rows,2):
    group=row["group"]
    country=row["country_iso"]
    name=row["airport_name"].strip()
    assert group in GROUPS and country in GROUPS[group], f"Row {number}: invalid group/country"
    assert name and (country,name.casefold()) not in seen, f"Row {number}: blank or duplicate"
    seen.add((country,name.casefold()))
    code=row["reported_code"]
    typ=row["reported_code_type"]
    assert (not code and not typ) or (typ in ("IATA","ICAO") and len(code)==(3 if typ=="IATA" else 4)), f"Row {number}: invalid code"
    assert row["historical_category"]=="Local", f"Row {number}: not Local"
    assert row["historical_decision"]=="APPROVED_IN_PRIOR_AUDIT", f"Row {number}: missing historical decision"
    assert row["validation_status"]=="PENDING_SOURCE_AND_CURRENT_RUNWAY_CHECK", f"Row {number}: source not yet cleared"
    assert row["gameplay_import"]=="NO", f"Row {number}: unverified airport must not activate"
    assert row["provenance"].strip(), f"Row {number}: missing provenance"
    counts[group]+=1
assert all(counts[g]>=n for g,n in BASELINE.items()), f"Missing previously recovered airports: {counts}"
assert len(rows)<=110, "More rows than historical approvals"
print(f"VALID: {len(rows)} recovered historical airports ({dict(counts)}); zero game imports")
