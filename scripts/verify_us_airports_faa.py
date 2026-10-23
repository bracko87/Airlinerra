#!/usr/bin/env python3
"""Independent FAA NASR physical/civilian screen for 2,077 US Airlinerra candidates.

Keeps all game approvals on hold. FAA public-use/qualified pavement does NOT
establish commercial carrier or charter permissions. No production mutations.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import math
import re
import urllib.request
import zipfile
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
US = ROOT / "data/airports/local_regional_expansion/us_verification"
CYCLE = "2026-10-01"
SOURCE_URL = "https://nfdc.faa.gov/webContent/28DaySub/extra/01_Oct_2026_APT_CSV.zip"
SOURCE_PAGE = "https://www.faa.gov/air_traffic/flight_info/aeronav/Aero_Data/NASR_Subscription/2026-10-01/"
OUTPUT_FIELDS = [
    "source_airport_id", "airport_name", "state", "proposed_category",
    "source_airport_ident", "source_faa_code_hints_unverified",
    "faa_match_status", "faa_identifier", "faa_site_number", "faa_name",
    "faa_state", "faa_city", "faa_distance_km",
    "faa_airport_status", "faa_facility_use", "faa_ownership_type",
    "faa_icao_identifier_if_reported",
    "faa_runways_reported", "faa_qualifying_paved_runway_count",
    "faa_best_qualifying_runway_designator", "faa_best_length_m",
    "faa_best_width_m", "faa_best_surface",
    "faa_runway_length_source_date", "faa_runway_surface_condition",
    "runway_evidence_status", "civilian_access_evidence_status",
    "overall_review_status", "commercial_approval_status",
    "playable", "faa_source_effective", "faa_source_url",
    "faa_cycle_zip_sha256", "review_note",
]


def read_csv(path: Path):
    with path.open(newline="", encoding="utf-8-sig") as file:
        return list(csv.DictReader(file))


def member_rows(archive: zipfile.ZipFile, basename: str):
    names = [n for n in archive.namelist() if n.upper().split("/")[-1] == basename.upper()]
    if len(names) != 1:
        raise ValueError(f"Expected one {basename} in FAA ZIP, got {names}")
    with archive.open(names[0]) as binary:
        text = io.TextIOWrapper(binary, encoding="utf-8-sig", errors="replace", newline="")
        return list(csv.DictReader(text))


def validate_columns(rows, columns, label):
    if not rows or not set(columns).issubset(rows[0]):
        raise ValueError(f"{label}: missing data or required columns: {set(columns) - set(rows[0] if rows else ())}")


def dist_km(lat1, lon1, lat2, lon2):
    a, b = math.radians(float(lat1)), math.radians(float(lat2))
    dlat = b-a
    dlon = math.radians(float(lon2)-float(lon1))
    h = math.sin(dlat/2)**2 + math.cos(a)*math.cos(b)*math.sin(dlon/2)**2
    return 6371.0088 * 2 * math.asin(min(1, math.sqrt(max(0, h))))


def confirmed_surface(label):
    """Accept only fully asphalt/concrete surfaces, never partial gravel/grass."""
    normalized = re.sub(r"\s+", "", (label or "").upper())
    parts = [p for p in re.split(r"[-/+]", normalized) if p]
    return bool(parts) and all(p in {"ASPH", "ASPHALT", "CONC", "CONCRETE"} for p in parts)


def numeric(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def select_faa_match(source, by_identifier):
    """Require an exact official identifier hint plus geographic proximity.

    Different FAA sites may share name fragments, but must never be joined
    on name alone. Unmatched sites remain on hold, not 'does not exist'.
    """
    hints = [s.strip().upper() for s in source["faa_identifier_candidates_NOT_VERIFIED"].split("|") if s.strip()]
    candidates = []
    for key in hints:
        for r in by_identifier.get(key, []):
            if r.get("SITE_TYPE_CODE", "").strip() != "A":
                continue
            lat, lon = numeric(r.get("LAT_DECIMAL")), numeric(r.get("LONG_DECIMAL"))
            if lat is None or lon is None:
                continue
            distance = dist_km(source["latitude_deg"], source["longitude_deg"], lat, lon)
            if distance <= 5:
                candidates.append((distance, r))
    unique = {}
    for distance, r in candidates:
        key = r.get("SITE_NO", "") or (r.get("ARPT_ID", ""), r.get("STATE_CODE", ""))
        if key not in unique or distance < unique[key][0]:
            unique[key] = (distance, r)
    if len(unique) == 1:
        return "EXACT_FAA_IDENTIFIER_AND_WITHIN_5KM", list(unique.values())[0]
    if len(unique) > 1:
        return "AMBIGUOUS_FAA_IDENTIFIER", None
    return "NOT_MATCHED_TO_FAA_BY_IDENTIFIER_AND_LOCATION", None


def classify(faa, runways):
    status = faa.get("ARPT_STATUS", "").strip().upper()
    use = faa.get("FACILITY_USE_CODE", "").strip().upper()
    qualified = []
    for r in runways:
        length_ft, width_ft = numeric(r.get("RWY_LEN")), numeric(r.get("RWY_WIDTH"))
        if length_ft is not None and length_ft*0.3048 >= 1200 and confirmed_surface(r.get("SURFACE_TYPE_CODE", "")):
            qualified.append((length_ft, width_ft, r))
    qualified.sort(key=lambda v: v[0], reverse=True)
    best = qualified[0] if qualified else None
    if status != "O":
        decision = "FAA_AIRPORT_NOT_OPEN_HOLD"
    elif not qualified:
        decision = "FAA_NO_CONFIRMED_1200M_ASPHALT_CONCRETE_RUNWAY_HOLD"
    elif use != "PU":
        decision = "FAA_NON_PUBLIC_USE_ACCESS_HOLD"
    else:
        decision = "FAA_PHYSICAL_AND_PUBLIC_USE_VERIFIED_COMMERCIAL_REVIEW"
    return status, use, qualified, best, decision


def run_review(baseline, base, runways, *, zip_sha256: str):
    validate_columns(baseline, ["source_airport_id", "faa_identifier_candidates_NOT_VERIFIED", "latitude_deg", "longitude_deg"], "Airlinerra baseline")
    validate_columns(base, ["EFF_DATE", "SITE_NO", "ARPT_ID", "ARPT_STATUS", "SITE_TYPE_CODE", "LAT_DECIMAL", "LONG_DECIMAL", "FACILITY_USE_CODE"], "FAA APT_BASE")
    validate_columns(runways, ["EFF_DATE", "SITE_NO", "ARPT_ID", "RWY_ID", "RWY_LEN", "RWY_WIDTH", "SURFACE_TYPE_CODE"], "FAA APT_RWY")
    if len(baseline) != 2077 or len({x["source_airport_id"] for x in baseline}) != 2077:
        raise ValueError("US candidate population changed; re-create baseline before review.")
    if len(base) < 5000 or len(runways) < 5000:
        raise ValueError("FAA download appears incomplete.")
    expected_eff = "2026/10/01"
    if any(r["EFF_DATE"] != expected_eff for r in base[:20] + base[-20:] + runways[:20] + runways[-20:]):
        raise ValueError("FAA dataset cycle is different from pinned October 1, 2026 cycle.")
    by_ident = defaultdict(list)
    by_site_runways = defaultdict(list)
    for r in base:
        if r.get("ARPT_ID"):
            by_ident[r["ARPT_ID"].strip().upper()].append(r)
    for r in runways:
        by_site_runways[r.get("SITE_NO", "").strip()].append(r)
    result = []
    for source in baseline:
        match, found = select_faa_match(source, by_ident)
        v = {k: "" for k in OUTPUT_FIELDS}
        v.update({
            "source_airport_id": source["source_airport_id"],
            "airport_name": source["airport_name"],
            "state": source["us_state"],
            "proposed_category": source["proposed_category"],
            "source_airport_ident": source["source_ident"],
            "source_faa_code_hints_unverified": source["faa_identifier_candidates_NOT_VERIFIED"],
            "faa_match_status": match,
            "faa_source_effective": CYCLE,
            "faa_source_url": SOURCE_PAGE,
            "faa_cycle_zip_sha256": zip_sha256,
            "playable": "NO",
            "commercial_approval_status": "NOT_VERIFIED",
            "runway_evidence_status": "NOT_INDEPENDENTLY_VERIFIED",
            "civilian_access_evidence_status": "NOT_INDEPENDENTLY_VERIFIED",
            "overall_review_status": "HOLD_NO_UNAMBIGUOUS_FAA_MATCH",
            "review_note": "Unmatched by strict identifier+5km test; manual facility research needed.",
        })
        if found:
            distance, faa = found
            site = faa.get("SITE_NO", "").strip()
            status, use, qualifies, best, decision = classify(faa, by_site_runways[site])
            v.update({
                "faa_identifier": faa.get("ARPT_ID", ""),
                "faa_site_number": site,
                "faa_name": faa.get("ARPT_NAME", ""),
                "faa_state": faa.get("STATE_CODE", ""),
                "faa_city": faa.get("CITY", ""),
                "faa_distance_km": f"{distance:.3f}",
                "faa_airport_status": status,
                "faa_facility_use": use,
                "faa_ownership_type": faa.get("OWNERSHIP_TYPE_CODE", ""),
                "faa_runways_reported": len(by_site_runways[site]),
                "faa_qualifying_paved_runway_count": len(qualifies),
                "runway_evidence_status": "CONFIRMED_FAA_1200M_PAVED" if qualifies else "FAA_NO_QUALIFYING_RUNWAY_NEEDS_REVIEW",
                "civilian_access_evidence_status": "FAA_OPEN_PUBLIC_USE" if status == "O" and use == "PU" else "FAA_NOT_OPEN_OR_PUBLIC",
                "overall_review_status": decision,
                "review_note": ("FAA public use and pavement alone do not establish permitted commercial flights. "
                                "Review authority/operator, aircraft compatibility and final game approval." if qualifies
                                else "FAA runway evidence fails/conflicts with technical source; hold pending validation."),
            })
            if best:
                length_ft, width_ft, runway = best
                v.update({
                    "faa_best_qualifying_runway_designator": runway.get("RWY_ID", ""),
                    "faa_best_length_m": f"{length_ft*0.3048:.1f}",
                    "faa_best_width_m": f"{width_ft*0.3048:.1f}" if width_ft is not None else "",
                    "faa_best_surface": runway.get("SURFACE_TYPE_CODE", ""),
                    "faa_runway_length_source_date": runway.get("LENGTH_SOURCE_DATE", ""),
                    "faa_runway_surface_condition": runway.get("COND", ""),
                })
        result.append(v)
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--faa-zip", type=Path, help="Offline FAA APT CSV ZIP archive; otherwise download the official pinned cycle.")
    p.add_argument("--output-dir", type=Path, default=US)
    args = p.parse_args()
    if args.faa_zip:
        payload = args.faa_zip.read_bytes()
    else:
        request = urllib.request.Request(SOURCE_URL, headers={"User-Agent": "Airlinerra-research/1.0"})
        with urllib.request.urlopen(request, timeout=90) as response:
            payload = response.read()
    sha = hashlib.sha256(payload).hexdigest()
    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        faa_airports = member_rows(archive, "APT_BASE.csv")
        faa_runways = member_rows(archive, "APT_RWY.csv")
    baseline = read_csv(US / "us_2077_baseline.csv")
    rows = run_review(baseline, faa_airports, faa_runways, zip_sha256=sha)
    if len(rows) != 2077 or any(r["playable"] != "NO" for r in rows):
        raise ValueError("Unsafe FAA admission output.")
    output = args.output_dir
    output.mkdir(parents=True, exist_ok=True)
    with (output / "us_faa_review_2026_10_01.csv").open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=OUTPUT_FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    counts = Counter(r["overall_review_status"] for r in rows)
    summary = {
        "as_of": CYCLE, "candidate_count": len(rows), "faa_source": SOURCE_PAGE,
        "faa_zip_url": SOURCE_URL, "faa_zip_sha256": sha,
        "faa_base_rows": len(faa_airports), "faa_runway_rows": len(faa_runways),
        "statuses": dict(sorted(counts.items())), "approved_for_game": 0,
        "output_status": "INDEPENDENT_FAA_SCREEN_REQUIRES_COMMERCIAL_AND_OWNER_REVIEW",
        "notes": [
            "Open public-use FAA airports with qualifying pavement are NOT necessarily commercially approved.",
            "Source airports without unambiguous coordinate+identifier match remain on hold.",
            "FAA no-runway/closed/private findings require source-conflict resolution, not silent deletion.",
            "All six Airlinerra tiers and the original 3,140 airport shortlist remain unchanged.",
            "No live game/Supabase writes; no fictional official codes created.",
        ],
    }
    (output / "us_faa_summary_2026_10_01.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2)+"\n", encoding="utf-8"
    )
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
