#!/usr/bin/env python3
"""Produce six-tier airport proposals without changing final gameplay assignments."""
from __future__ import annotations

import argparse
import csv
import io
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "data/airports/airport_register.csv"
ANAC = ROOT / "data/airports/commercial/group46/group46_brazil_anac_2025_official_crosswalk.csv"
EXCLUSIONS = ROOT / "data/airports/reconciliation/BR_2026_OFFICIAL_RUNWAY_EXCLUSIONS.csv"
OUTPUT = ROOT / "data/airports/classification/airport_classification_review.csv"
CATEGORIES = ("Local", "Regional", "Medium", "Large", "Major Hub", "Mega Hub")
FIELDS = (
    "source_airport_id", "country_iso", "airport_name", "final_assigned_category",
    "provisional_category", "decision_status", "passenger_activity_signal",
    "cargo_activity_signal", "regular_passenger_proxy", "nonregular_passenger_proxy",
    "regular_cargo_proxy_kg", "nonregular_cargo_proxy_kg", "evidence_year",
)

def records(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        if not reader.fieldnames or len(set(reader.fieldnames)) != len(reader.fieldnames):
            raise ValueError(f"Invalid CSV header: {path}")
        rows = list(reader)
        if any(None in row for row in rows):
            raise ValueError(f"Malformed CSV: {path}")
        return rows

def nonnegative(value: str, label: str) -> int:
    try:
        count = int(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"Invalid {label}: {value!r}") from exc
    if count < 0:
        raise ValueError(f"Negative {label}: {count}")
    return count

def provisional_tier(regular_passengers: int) -> str:
    """Proposed game thresholds, never a real-world official category."""
    if regular_passengers <= 0:
        raise ValueError("Tier requires positive regular passenger evidence")
    if regular_passengers >= 50_000_000:
        return "Mega Hub"
    if regular_passengers >= 10_000_000:
        return "Major Hub"
    if regular_passengers >= 1_000_000:
        return "Large"
    if regular_passengers >= 100_000:
        return "Medium"
    if regular_passengers >= 10_000:
        return "Regional"
    return "Local"

def build_rows(master: list[dict[str, str]], anac: list[dict[str, str]],
               exclusions: list[dict[str, str]]) -> list[dict[str, str]]:
    by_id: dict[str, dict[str, str]] = {}
    for source in anac:
        key = source["source_airport_id"]
        if key in by_id:
            raise ValueError(f"Duplicate ANAC source airport ID: {key}")
        if source["year"] != "2025":
            raise ValueError(f"Unexpected ANAC traffic year for {key}")
        by_id[key] = source
    excluded = {r["source_airport_id"] for r in exclusions}
    master_ids = [m["source_airport_id"] for m in master]
    if len(master_ids) != len(set(master_ids)):
        raise ValueError("Duplicate source IDs in technical master")
    active_brazil = {m["source_airport_id"] for m in master if m["country_iso"] == "BR"}
    if active_brazil - set(by_id):
        raise ValueError("Eligible Brazil airports missing from ANAC crosswalk")
    if (set(by_id) - active_brazil) - excluded:
        raise ValueError("ANAC crosswalk contains unexplained excluded airports")
    if active_brazil & excluded:
        raise ValueError("Officially excluded runway still in technical master")
    result = []
    for m in master:
        ident = m["source_airport_id"]
        final = m["assigned_category"]
        if final and final not in CATEGORIES:
            raise ValueError(f"Category outside the exact six tiers: {ident}")
        row = dict.fromkeys(FIELDS, "")
        row.update(source_airport_id=ident, country_iso=m["country_iso"],
                   airport_name=m["airport_name"], final_assigned_category=final)
        if m["source_type"] == "FICTIONAL":
            if not final:
                raise ValueError(f"Fictional airport without explicit tier: {ident}")
            row.update(decision_status="OWNER_ASSIGNED", passenger_activity_signal="NOT_APPLICABLE",
                       cargo_activity_signal="NOT_APPLICABLE")
        elif m["source_type"] != "OURAIRPORTS":
            raise ValueError(f"Unknown source type for {ident}")
        elif m["country_iso"] != "BR":
            row.update(decision_status="EXISTING_FINAL_ASSIGNMENT" if final else "NEEDS_EVIDENCE",
                       passenger_activity_signal="NOT_RESEARCHED",
                       cargo_activity_signal="NOT_RESEARCHED")
        else:
            source = by_id[ident]
            rp = nonnegative(source["regular_passenger_movements"], f"regular pax at {ident}")
            np = nonnegative(source["nonregular_passenger_movements"], f"nonregular pax at {ident}")
            rc = nonnegative(source["regular_cargo_kg"], f"regular cargo at {ident}")
            nc = nonnegative(source["nonregular_cargo_kg"], f"nonregular cargo at {ident}")
            passenger = "REGULAR_OBSERVED" if rp else "NONREGULAR_ONLY" if np else "NO_POSITIVE_2025_OBSERVATION"
            cargo = "REGULAR_OBSERVED" if rc else "NONREGULAR_ONLY" if nc else "NO_POSITIVE_2025_OBSERVATION"
            proposal = provisional_tier(rp) if rp else ""
            status = ("EXISTING_FINAL_ASSIGNMENT" if final else
                      "PROVISIONAL_REGULAR_TRAFFIC" if rp else
                      "NONREGULAR_ONLY_REVIEW" if np else
                      "CARGO_ONLY_REVIEW" if rc or nc else "NEEDS_EVIDENCE")
            row.update(provisional_category=proposal, decision_status=status,
                       passenger_activity_signal=passenger, cargo_activity_signal=cargo,
                       regular_passenger_proxy=str(rp), nonregular_passenger_proxy=str(np),
                       regular_cargo_proxy_kg=str(rc), nonregular_cargo_proxy_kg=str(nc),
                       evidence_year="2025")
        result.append(row)
    if len(result) != len(master):
        raise ValueError("Classification review did not preserve every master airport")
    return result

def render(rows: list[dict[str, str]]) -> str:
    stream = io.StringIO(newline="")
    writer = csv.DictWriter(stream, fieldnames=FIELDS, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    return stream.getvalue()

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Check the committed review is reproducible")
    parser.add_argument("--out", type=Path, default=OUTPUT)
    args = parser.parse_args()
    rows = build_rows(records(MASTER), records(ANAC), records(EXCLUSIONS))
    content = render(rows)
    if args.check:
        if not args.out.exists() or args.out.read_text(encoding="utf-8") != content:
            raise SystemExit("Classification review needs rebuilding; run without --check")
    else:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(content, encoding="utf-8", newline="")
    print(f"CLASSIFICATION REVIEW: {len(rows)} airports, "
          f"statuses={dict(Counter(r['decision_status'] for r in rows))}; "
          "no real-airport final tier changed")

if __name__ == "__main__":
    main()
