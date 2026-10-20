#!/usr/bin/env python3
"""Validate Airlinerra's version-controlled airport registers (no network needed)."""
from __future__ import annotations
import csv
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
APPROVED = ROOT / "data/airports/airport_register.csv"
REVIEW = ROOT / "data/airports/group4_review.csv"
CATEGORIES = {"Local","Regional","Medium","Large","Major Hub","Mega Hub"}
ALLOWED = {"APPROVED","REVIEW","EXCLUDED"}
REQUIRED = {"country_iso","airport_name","icao","category","status"}
def load(path: pathlib.Path):
    with path.open(encoding="utf-8-sig",newline="") as f:
        reader=csv.DictReader(f)
        if not reader.fieldnames:
            raise ValueError(f"{path}: missing header")
        if len(reader.fieldnames) != len(set(reader.fieldnames)):
            raise ValueError(f"{path}: repeated headers")
        return reader.fieldnames, list(reader)
def check(path, reviewed_only=False):
    columns, rows = load(path)
    missing=REQUIRED-set(columns)
    if missing:
        raise ValueError(f"{path}: missing fields {sorted(missing)}")
    seen = set()
    for i,row in enumerate(rows,2):
        country=(row.get("country_iso") or "").strip()
        icao=(row.get("icao") or "").strip().upper()
        status=(row.get("status") or "").strip()
        category=(row.get("category") or "").strip()
        if len(country) != 2 or not country.isalpha() or country != country.upper():
            raise ValueError(f"{path}:{i} invalid country ISO")
        if not row.get("airport_name","").strip():
            raise ValueError(f"{path}:{i} missing airport name")
        if status not in ALLOWED:
            raise ValueError(f"{path}:{i} invalid status {status}")
        if reviewed_only and status!="REVIEW":
            raise ValueError(f"{path}:{i} candidate must remain REVIEW")
        if status=="APPROVED" and category not in CATEGORIES:
            raise ValueError(f"{path}:{i} approved airports need exact six-class category")
        if category and category not in CATEGORIES:
            raise ValueError(f"{path}:{i} invalid six-class category {category}")
        if icao:
            key=(country,icao)
            if key in seen:
                raise ValueError(f"{path}:{i} duplicate ICAO {key}")
            seen.add(key)
        if status=="APPROVED":
            required_approval={"source_url","verified_on","runway_surface","longest_eligible_runway_m","civilian_access"}
            if not required_approval.issubset(columns):
                raise ValueError(f"{path}:{i} missing required approval columns")
            if any(not row.get(field,"").strip() for field in required_approval):
                raise ValueError(f"{path}:{i} missing airport approval evidence")
            if float(row["longest_eligible_runway_m"]) < 1200:
                raise ValueError(f"{path}:{i} approved runway below 1200 m")
            if row["civilian_access"].upper() not in ("YES","CONDITIONAL"):
                raise ValueError(f"{path}:{i} civilian access not approved")
            if not any(t in row["runway_surface"].lower() for t in ("asphalt","concrete")):
                raise ValueError(f"{path}:{i} unverified surface")
    return len(rows)

if __name__=="__main__":
    try:
        a=check(APPROVED)
        r=check(REVIEW,True)
        print(f"VALIDATED: approved register {a} rows; Group 4 review {r} rows; exactly six possible classes")
    except Exception as err:
        print(f"VALIDATION FAILED: {err}",file=sys.stderr)
        sys.exit(1)
