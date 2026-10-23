#!/usr/bin/env python3
"""Cross-check US candidate FAA matches with Part 139 fields in the SAME pinned NASR cycle.

Creates an independent research-only airport certification indicator ledger.
Certification class is not permission to operate a route, and a blank NASR
indicator is not a finding that commercial charter or cargo is prohibited.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import re
import urllib.request
import zipfile
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIR = ROOT / "data/airports/local_regional_expansion/us_verification"
SOURCE_URL = "https://nfdc.faa.gov/webContent/28DaySub/extra/01_Oct_2026_APT_CSV.zip"
SOURCE_PAGE = "https://www.faa.gov/air_traffic/flight_info/aeronav/Aero_Data/NASR_Subscription/2026-10-01/"
CERT_STATUS_PAGE = "https://www.faa.gov/airports/airport_safety/part139_cert/part_139_airport_certification_status_list"
CLASS_PAGE = "https://www.faa.gov/airports/airport_safety/part139_cert/classes-of-airports"
EXPECTED_CYCLE = "2026/10/01"
OUTPUT = "us_part139_nasr_2026_10_01.csv"
SUMMARY = "us_part139_nasr_summary.json"
FIELDS = [
    "source_airport_id", "airport_name", "faa_identifier", "faa_site_number",
    "physical_public_use_status", "faa_record_match_status",
    "faa_part139_type_raw", "faa_part139_carrier_service_raw",
    "faa_part139_initial_cert_date_raw", "faa_part139_class", "faa_arff_index",
    "part139_nasr_evidence_status", "scheduled_10_30_passenger_seats_cert_indicator",
    "scheduled_31_plus_passenger_seats_cert_indicator",
    "unscheduled_31_plus_passenger_seats_cert_indicator",
    "small_charter_upto_9_seats", "cargo_operations",
    "alaska_part139_exception_note", "commercial_operator_permission",
    "final_game_approval", "playable", "source_faa_cycle", "source_zip_sha256",
    "source_url", "followup",
]
# Part 139 airport classes, from FAA official classes-of-airports guidance.
CLASS_PERMITTED = {
    "I": ("POTENTIAL_CLASS_SUPPORT_SUBJECT_TO_AUTHORIZATION",) * 3,
    "II": ("POTENTIAL_CLASS_SUPPORT_SUBJECT_TO_AUTHORIZATION",
           "NO_CLASS_SUPPORT_FOR_SCHEDULED_31_PLUS",
           "POTENTIAL_CLASS_SUPPORT_SUBJECT_TO_AUTHORIZATION"),
    "III": ("POTENTIAL_CLASS_SUPPORT_SUBJECT_TO_AUTHORIZATION",
            "NO_CLASS_SUPPORT_FOR_SCHEDULED_31_PLUS",
            "NO_CLASS_SUPPORT_FOR_UNSCHEDULED_31_PLUS"),
    "IV": ("NO_CLASS_SUPPORT_FOR_SCHEDULED_10_TO_30",
           "NO_CLASS_SUPPORT_FOR_SCHEDULED_31_PLUS",
           "POTENTIAL_CLASS_SUPPORT_SUBJECT_TO_AUTHORIZATION"),
}


def read_rows(path: Path):
    with path.open(encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
    if any(None in row or any(value is None for value in row.values()) for row in rows):
        raise ValueError(f"Invalid CSV: {path}")
    return rows


def load_apt_base(payload):
    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        names = [n for n in archive.namelist() if n.upper().split("/")[-1] == "APT_BASE.CSV"]
        if len(names) != 1:
            raise ValueError("Pinned NASR archive is missing a unique APT_BASE.csv")
        with archive.open(names[0]) as f:
            with io.TextIOWrapper(f, encoding="utf-8-sig", newline="", errors="replace") as txt:
                return list(csv.DictReader(txt))


def parse_class(raw):
    raw = (raw or "").strip().upper()
    if not raw:
        return "", "", "NO_PART139_TYPE_REPORTED_IN_NASR"
    match = re.fullmatch(r"(I|II|III|IV)\s*([ABCDE])", raw)
    if not match:
        return "", "", "UNRECOGNIZED_NASR_PART139_CODE_REVIEW"
    return match.group(1), match.group(2), "PART139_CLASS_INDICATOR_REPORTED_BY_NASR"


def build(audit, faa_base, source_hash, source_summary):
    if len(audit) != 2077 or len({r["source_airport_id"] for r in audit}) != 2077:
        raise ValueError("Unexpected audit population")
    required = {"SITE_NO", "ARPT_ID", "EFF_DATE", "FAR_139_TYPE_CODE",
                "FAR_139_CARRIER_SER_CODE", "ARFF_CERT_TYPE_DATE"}
    if not faa_base or not required.issubset(faa_base[0]):
        raise ValueError(f"FAA APT_BASE is missing mandatory certification fields: {required - set(faa_base[0] if faa_base else {})}")
    if len(faa_base) < 5000 or any(r["EFF_DATE"] != EXPECTED_CYCLE for r in faa_base[:10] + faa_base[-10:]):
        raise ValueError("FAA APT_BASE wrong cycle or truncated")
    if source_summary.get("faa_zip_sha256") != source_hash:
        raise ValueError("Downloaded NASR cycle differs from previously verified FAA screening ZIP")
    by_site = {}
    for rec in faa_base:
        site = rec["SITE_NO"].strip()
        if site in by_site:
            # Airport/site identity must be unique; ambiguous records must be held.
            raise ValueError("Duplicate FAA site number in APT_BASE: " + site)
        by_site[site] = rec
    result = []
    for airport in audit:
        has_verified_match = airport["faa_match_status"] == "EXACT_FAA_IDENTIFIER_AND_WITHIN_5KM"
        key = airport.get("faa_site_number", "").strip()
        rec = by_site.get(key) if has_verified_match else None
        if has_verified_match and (not rec or rec.get("ARPT_ID", "").strip() != airport["faa_identifier"]):
            raise ValueError("FAA site/identifier mismatch: " + airport["source_airport_id"])
        raw = rec.get("FAR_139_TYPE_CODE", "") if rec else ""
        klass, arff, status = parse_class(raw)
        if not rec:
            status = "NO_INDEPENDENT_FAA_MATCH_CANNOT_INFER_CERTIFICATION"
        potential = CLASS_PERMITTED.get(klass, ("HOLD_CERT_CLASS_NOT_EVIDENCED",) * 3)
        physical = airport["overall_review_status"] == "FAA_PHYSICAL_AND_PUBLIC_USE_VERIFIED_COMMERCIAL_REVIEW"
        if not physical:
            potential = ("HOLD_AIRPORT_ACCESS_OR_PAVEMENT",) * 3
        if klass and not physical:
            followup = "FAA Part 139 indicator exists but airport failed separate public-use/pavement gate; research conflict."
        elif klass:
            followup = ("FAA Part 139 class is a preliminary service-type indicator only; verify current AOC, "
                        "operating certificate conditions, individual airline/operator permissions, aircraft performance.")
        else:
            followup = ("No verified applicable Part 139 class from the matched 2026 FAA NASR record; "
                        "large scheduled passenger flights stay on hold; small charter and cargo need operator research.")
        result.append({
            "source_airport_id": airport["source_airport_id"],
            "airport_name": airport["airport_name"],
            "faa_identifier": airport["faa_identifier"],
            "faa_site_number": key,
            "physical_public_use_status": airport["overall_review_status"],
            "faa_record_match_status": airport["faa_match_status"],
            "faa_part139_type_raw": raw.strip(),
            "faa_part139_carrier_service_raw": rec.get("FAR_139_CARRIER_SER_CODE", "").strip() if rec else "",
            "faa_part139_initial_cert_date_raw": rec.get("ARFF_CERT_TYPE_DATE", "").strip() if rec else "",
            "faa_part139_class": klass,
            "faa_arff_index": arff,
            "part139_nasr_evidence_status": status,
            "scheduled_10_30_passenger_seats_cert_indicator": potential[0],
            "scheduled_31_plus_passenger_seats_cert_indicator": potential[1],
            "unscheduled_31_plus_passenger_seats_cert_indicator": potential[2],
            "small_charter_upto_9_seats": "FURTHER_OPERATOR_REVIEW" if physical else "HOLD_PHYSICAL_ACCESS",
            "cargo_operations": "FURTHER_OPERATOR_REVIEW" if physical else "HOLD_PHYSICAL_ACCESS",
            "alaska_part139_exception_note": ("FAA_ALASKA_EXCEPTION_REVIEW_REQUIRED" if airport["state"] == "AK" else ""),
            "commercial_operator_permission": "UNVERIFIED",
            "final_game_approval": "NO",
            "playable": "NO",
            "source_faa_cycle": "2026-10-01",
            "source_zip_sha256": source_hash,
            "source_url": SOURCE_PAGE,
            "followup": followup,
        })
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--faa-zip", type=Path, help="Path to pinned 2026-10-01 FAA APT_CSV ZIP (optional)")
    parser.add_argument("--output-dir", type=Path, default=DIR)
    args = parser.parse_args()
    if args.faa_zip:
        payload = args.faa_zip.read_bytes()
    else:
        req = urllib.request.Request(SOURCE_URL, headers={"User-Agent": "Airlinerra-research/1.0"})
        with urllib.request.urlopen(req, timeout=90) as response:
            payload = response.read()
    source_hash = hashlib.sha256(payload).hexdigest()
    official = load_apt_base(payload)
    audit = read_rows(DIR / "us_faa_review_2026_10_01.csv")
    source_summary = json.loads((DIR / "us_faa_summary_2026_10_01.json").read_text(encoding="utf-8"))
    rows = build(audit, official, source_hash, source_summary)
    if len(rows) != 2077 or any(r["playable"] != "NO" or r["final_game_approval"] != "NO" for r in rows):
        raise ValueError("Unintended commercial admission")
    output = args.output_dir
    output.mkdir(parents=True, exist_ok=True)
    with (output / OUTPUT).open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    status = Counter(r["part139_nasr_evidence_status"] for r in rows)
    classes = Counter(r["faa_part139_class"] for r in rows if r["faa_part139_class"])
    physically_passed = [r for r in rows if r["physical_public_use_status"] == "FAA_PHYSICAL_AND_PUBLIC_USE_VERIFIED_COMMERCIAL_REVIEW"]
    pass_classes = Counter(r["faa_part139_class"] for r in physically_passed if r["faa_part139_class"])
    summary = {
        "as_of": "2026-10-01", "generated_stage": "RESEARCH_ONLY_CERTIFICATION_INDICATOR_CROSSCHECK",
        "total_candidates": len(rows), "physically_and_public_use_qualified": len(physically_passed),
        "part139_indicator_statuses": dict(sorted(status.items())),
        "part139_classes_all_matched": dict(sorted(classes.items())),
        "part139_classes_among_public_use_physical_pass": dict(sorted(pass_classes.items())),
        "count_part139_class_I_among_public_use_physical_pass": pass_classes.get("I", 0),
        "eligible_for_game": 0, "actual_airline_permission_verified": 0,
        "alaska_candidate_count": sum(r["alaska_part139_exception_note"] != "" for r in rows),
        "faa_cycle_hash_sha256": source_hash, "faa_source": SOURCE_PAGE,
        "cert_status_list_for_additional_check": CERT_STATUS_PAGE,
        "faa_classes_reference": CLASS_PAGE,
        "cautions": [
            "2026 NASR FAR_139_TYPE_CODE is an FAA-reported certificate indicator; do not confuse with game category.",
            "Class I enables review of scheduled 31+ seats but does not by itself authorize a real airline, aircraft, route or airport usage.",
            "Absence of a Part 139 indicator is not proof a small-aircraft charter or cargo service is forbidden.",
            "An FAA nonpublic-use airport remains on hold even if Part 139 indicator appears.",
            "All 2077 remain unapproved for game, with no Supabase or original airport database changes."
        ],
    }
    (output / SUMMARY).write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
