#!/usr/bin/env python3
"""Produce six-tier airport proposals without changing final gameplay assignments."""
from __future__ import annotations

import argparse
import csv
import io
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "data/airports/airport_register.csv"
ANAC = ROOT / "data/airports/commercial/group46/group46_brazil_anac_2025_official_crosswalk.csv"
AR_ANAC = ROOT / "data/airports/commercial/group46/group46_argentina_anac_2025_official_passenger_totals.csv"
PE_ANNUAL = ROOT / "data/airports/commercial/batchB02/b02_peru_2025_official_regular_passenger_totals.csv"
EC_CARGO = ROOT / "data/airports/commercial/batchB02/b02_ecuador_2025_official_airport_cargo.csv"
CL_DOMESTIC = ROOT / "data/airports/commercial/batchB02/b02_chile_2025_official_domestic_quarterly_totals.csv"
B02_ADDITIONAL = ROOT / "data/airports/commercial/batchB02/b02_additional_2025_verified_airport_totals.csv"
EXCLUSIONS = ROOT / "data/airports/reconciliation/BR_2026_OFFICIAL_RUNWAY_EXCLUSIONS.csv"
OUTPUT = ROOT / "data/airports/classification/airport_classification_review.csv"
CATEGORIES = ("Local", "Regional", "Medium", "Large", "Major Hub", "Mega Hub")
FIELDS = (
    "source_airport_id", "country_iso", "airport_name", "final_assigned_category",
    "provisional_category", "decision_status", "passenger_activity_signal",
    "cargo_activity_signal", "regular_passenger_proxy", "nonregular_passenger_proxy",
    "regular_cargo_proxy_kg", "nonregular_cargo_proxy_kg", "evidence_year",
    "annual_total_passenger_proxy", "passenger_measure", "annual_cargo_tonnes_proxy",
    "domestic_passenger_floor_proxy", "evidence_source_url",
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
               exclusions: list[dict[str, str]],
               argentina: list[dict[str, str]] | None = None,
               peru: list[dict[str, str]] | None = None,
               ecuador_cargo: list[dict[str, str]] | None = None,
               chile_domestic: list[dict[str, str]] | None = None,
               b02_additional: list[dict[str, str]] | None = None) -> list[dict[str, str]]:
    by_id: dict[str, dict[str, str]] = {}
    for source in anac:
        key = source["source_airport_id"]
        if key in by_id:
            raise ValueError(f"Duplicate ANAC source airport ID: {key}")
        if source["year"] != "2025":
            raise ValueError(f"Unexpected ANAC traffic year for {key}")
        by_id[key] = source
    argentina_by_id: dict[str, dict[str, str]] = {}
    for source in argentina or []:
        key = source["source_airport_id"]
        if key in argentina_by_id or source["year"] != "2025":
            raise ValueError(f"Invalid or duplicate Argentina source row: {key}")
        annual = nonnegative(source["passenger_total_estimate"], f"Argentina pax at {key}")
        if annual <= 0 or source.get("metric") != "ANAC_TOTAL_PAX_ROUNDED_1000":
            raise ValueError(f"Missing or unsupported Argentina annual total at {key}")
        thousands = source.get("reported_2025_thousands", "")
        if not thousands or not thousands.replace(".", "").isdigit():
            raise ValueError(f"Malformed Argentina ANAC thousands figure at {key}")
        if annual != int(thousands.replace(".", "")) * 1_000:
            raise ValueError(f"Argentina rounded-thousands conversion mismatch at {key}")
        argentina_by_id[key] = source
    peru_by_id: dict[str, dict[str, str]] = {}
    for src in peru or []:
        sid = src["source_airport_id"]
        if sid in peru_by_id or src["country_iso"] != "PE" or src["year"] != "2025" or src["metric"] != "PERU_DGAC_REGULAR_PAX_ROUNDED_1000":
            raise ValueError(f"Invalid or duplicate Peru 2025 regular-passenger evidence: {sid}")
        thousands = src["reported_2025_thousands"]
        if not re.fullmatch(r"[0-9]+", thousands) or int(thousands) <= 0:
            raise ValueError(f"Malformed Peru annual thousands figure: {sid}")
        if nonnegative(src["regular_passenger_estimate"], f"Peru regular passengers at {sid}") != int(thousands) * 1000:
            raise ValueError(f"Peru annual thousands conversion mismatch: {sid}")
        peru_by_id[sid] = src
    ecuador_by_id: dict[str, dict[str, str]] = {}
    for src in ecuador_cargo or []:
        sid = src["source_airport_id"]
        if sid in ecuador_by_id or src["country_iso"] != "EC" or src["year"] != "2025" or src["metric"] != "EC_DGAC_ANNUAL_CARGO_TONNES":
            raise ValueError(f"Invalid or duplicate Ecuador cargo evidence: {sid}")
        tonnes = src["annual_cargo_tonnes"]
        if not re.fullmatch(r"[0-9]+\\.[0-9]{2}", tonnes) or int(tonnes.replace(".", "")) <= 0:
            raise ValueError(f"Invalid Ecuador cargo tonnes: {sid}")
        ecuador_by_id[sid] = src
    chile_by_id: dict[str, dict[str, str]] = {}
    for src in chile_domestic or []:
        sid = src["source_airport_id"]
        if (sid in chile_by_id or src["country_iso"] != "CL" or src["year"] != "2025" or
                src["metric"] != "CHILE_MOP_2025_DOMESTIC_ONLY_ROUNDED_1000"):
            raise ValueError(f"Invalid or duplicate Chile source row: {sid}")
        quarters = [nonnegative(src[f"quarter{q}_domestic_thousands"], f"Chile Q{q} at {sid}")
                    for q in range(1, 5)]
        annual_thousands = nonnegative(src["annual_domestic_thousands"], f"Chile total at {sid}")
        annual = nonnegative(src["annual_domestic_estimate"], f"Chile annual at {sid}")
        if any(n <= 0 for n in quarters) or annual_thousands != sum(quarters) or annual != sum(quarters) * 1000:
            raise ValueError(f"Chile quarterly-to-annual scale mismatch: {sid}")
        if any(not src[f"source_quarter{q}"].startswith("https://concesiones.mop.gob.cl/")
               for q in range(1, 5)):
            raise ValueError(f"Chile official quarterly provenance missing: {sid}")
        chile_by_id[sid] = src
    b02_by_id: dict[str, dict[str, str]] = {}
    supported_metrics = {"CL_OPERATOR_2025_TOTAL_PAX", "CO_OPERATOR_2025_TOTAL_PAX", "EC_OPERATOR_2025_ROUNDED_PAX", "EC_DGAC_2025_TOTAL_PAX", "GF_AIRPORT_2025_COMMERCIAL_PAX", "GY_GOV_2025_AIRPORT_TOTAL_PAX", "PY_DINAC_2025_MIXED_PAX", "PY_DINAC_2025_REGULAR_PAX", "UY_DINACIA_2025_COMMERCIAL_PAX", "CO_AEROCIVIL_2025_SECONDARY_ATTRIBUTED_PAX"}
    for src in b02_additional or []:
        sid = src["source_airport_id"]
        if (sid in b02_by_id or src["country_iso"] not in {"CL", "CO", "EC", "GF", "GY", "PY", "UY"}
                or src["year"] != "2025" or src["metric"] not in supported_metrics):
            raise ValueError(f"Invalid or duplicate B02 2025 airport evidence: {sid}")
        pax = src["passenger_estimate"]
        if not re.fullmatch(r"[0-9]+", pax) or nonnegative(pax, f"B02 pax at {sid}") <= 0:
            raise ValueError(f"Invalid B02 passenger count at {sid}")
        if not src["source_url"].startswith("https://") or not src["qualification_note"]:
            raise ValueError(f"Missing B02 official/source provenance at {sid}")
        b02_by_id[sid] = src
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
    active_argentina = {m["source_airport_id"] for m in master if m["country_iso"] == "AR"}
    if set(argentina_by_id) - active_argentina:
        raise ValueError("Argentina ANAC source row absent from technical master")
    for airport in master:
        if airport["country_iso"] != "AR":
            continue
        source = argentina_by_id.get(airport["source_airport_id"])
        if source and source["icao_or_ident"] not in {airport.get("ident"), airport.get("gps_code")}:
            raise ValueError(f"Argentina ANAC airport code mismatch for {airport['source_airport_id']}")
    for airport in master:
        sid = airport["source_airport_id"]
        for evidence, expected_country, label in (
            (peru_by_id.get(sid), "PE", "Peru"),
            (ecuador_by_id.get(sid), "EC", "Ecuador"),
            (chile_by_id.get(sid), "CL", "Chile"),
        ):
            if evidence and (airport["country_iso"] != expected_country or
                             evidence["icao_or_ident"] not in {airport.get("ident"), airport.get("gps_code")}):
                raise ValueError(f"{label} official airport code/source ID mismatch: {sid}")
    if (set(peru_by_id) - set(master_ids) or set(ecuador_by_id) - set(master_ids) or
            set(chile_by_id) - set(master_ids) or set(b02_by_id) - set(master_ids)):
        raise ValueError("B02 evidence references unknown technical airport source IDs")
    for airport in master:
        src = b02_by_id.get(airport["source_airport_id"])
        if src and (airport["country_iso"] != src["country_iso"] or
                    src["icao_or_ident"] not in {airport.get("ident"), airport.get("gps_code")}):
            raise ValueError(f"B02 airport code/source ID mismatch: {airport['source_airport_id']}")
    if set(b02_by_id) & (set(peru_by_id) | set(chile_by_id) | set(argentina_by_id) | set(by_id)):
        raise ValueError("B02 additional evidence overlaps another passenger source")
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
        elif m["country_iso"] == "AR":
            source = argentina_by_id.get(ident)
            if source is None:
                row.update(decision_status="EXISTING_FINAL_ASSIGNMENT" if final else "NEEDS_EVIDENCE",
                           passenger_activity_signal="NO_NAMED_2025_TOTAL",
                           cargo_activity_signal="NOT_RESEARCHED")
            else:
                annual = nonnegative(source["passenger_total_estimate"], f"Argentina pax at {ident}")
                row.update(provisional_category=provisional_tier(annual),
                           decision_status="EXISTING_FINAL_ASSIGNMENT" if final else "PROVISIONAL_OFFICIAL_ANNUAL_TOTAL",
                           passenger_activity_signal="PASSENGER_TOTAL_REPORTED",
                           cargo_activity_signal="NOT_RESEARCHED",
                           annual_total_passenger_proxy=str(annual),
                           passenger_measure="ANAC_TOTAL_PAX_ROUNDED_1000",
                           evidence_year="2025", evidence_source_url=source["source_url"])
        elif ident in b02_by_id:
            src = b02_by_id[ident]
            annual = nonnegative(src["passenger_estimate"], f"B02 pax at {ident}")
            # Ecuador freight evidence must survive the additional passenger source.
            cargo_source = ecuador_by_id.get(ident)
            row.update(provisional_category=provisional_tier(annual),
                       decision_status=("EXISTING_FINAL_ASSIGNMENT" if final else
                           "PROVISIONAL_B02_SECONDARY_REPORTED_2025" if src["metric"] == "CO_AEROCIVIL_2025_SECONDARY_ATTRIBUTED_PAX" else
                           "PROVISIONAL_B02_2025_AIRPORT_TRAFFIC"),
                       passenger_activity_signal="2025_AIRPORT_PAX_REPORTED",
                       cargo_activity_signal="ANNUAL_CARGO_TONNES_REPORTED" if cargo_source else "NOT_RESEARCHED",
                       annual_total_passenger_proxy=str(annual),
                       annual_cargo_tonnes_proxy=cargo_source["annual_cargo_tonnes"] if cargo_source else "",
                       evidence_year="2025", passenger_measure=src["metric"],
                       evidence_source_url=src["source_url"])
        elif m["country_iso"] == "PE" and ident in peru_by_id:
            src = peru_by_id[ident]
            annual = nonnegative(src["regular_passenger_estimate"], f"Peru pax at {ident}")
            row.update(provisional_category=provisional_tier(annual),
                       decision_status="EXISTING_FINAL_ASSIGNMENT" if final else "PROVISIONAL_OFFICIAL_REGULAR_TRAFFIC",
                       passenger_activity_signal="REGULAR_OBSERVED_OFFICIAL_2025",
                       cargo_activity_signal="NOT_RESEARCHED",
                       regular_passenger_proxy=str(annual),
                       evidence_year="2025",
                       passenger_measure="PERU_DGAC_REGULAR_PAX_ROUNDED_1000",
                       evidence_source_url=src["source_url"])
        elif m["country_iso"] == "EC" and ident in ecuador_by_id:
            src = ecuador_by_id[ident]
            row.update(decision_status="EXISTING_FINAL_ASSIGNMENT" if final else "CARGO_ONLY_REVIEW",
                       passenger_activity_signal="NOT_RESEARCHED",
                       cargo_activity_signal="ANNUAL_CARGO_TONNES_REPORTED",
                       annual_cargo_tonnes_proxy=src["annual_cargo_tonnes"],
                       evidence_year="2025",
                       evidence_source_url=src["source_url"])
        elif m["country_iso"] == "CL" and ident in chile_by_id:
            src = chile_by_id[ident]
            domestic = nonnegative(src["annual_domestic_estimate"], f"Chile domestic at {ident}")
            row.update(provisional_category=provisional_tier(domestic),
                       decision_status="EXISTING_FINAL_ASSIGNMENT" if final else "PROVISIONAL_DOMESTIC_FLOOR",
                       passenger_activity_signal="DOMESTIC_OBSERVED_OFFICIAL_2025",
                       cargo_activity_signal="NOT_RESEARCHED",
                       domestic_passenger_floor_proxy=str(domestic),
                       passenger_measure="CHILE_MOP_2025_DOMESTIC_ONLY_ROUNDED_1000",
                       evidence_year="2025", evidence_source_url=src["source_quarter4"])
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
    rows = build_rows(records(MASTER), records(ANAC), records(EXCLUSIONS), records(AR_ANAC),
                      records(PE_ANNUAL), records(EC_CARGO), records(CL_DOMESTIC),
                      records(B02_ADDITIONAL))
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
