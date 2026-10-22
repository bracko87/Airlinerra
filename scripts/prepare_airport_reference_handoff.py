#!/usr/bin/env python3
"""Build a deterministic, non-operational airport data handoff. Never contacts Supabase."""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AIRPORTS = Path("data/airports")
B02_CODES = {"BO", "CL", "CO", "EC", "FK", "GF", "GY", "PY", "PE", "GS", "SR", "UY", "VE"}
CATEGORIES = {"Local", "Regional", "Medium", "Large", "Major Hub", "Mega Hub"}
REFERENCE_FIELDS = (
    "airport_key", "source_airport_id", "source_type", "country_iso", "airport_name",
    "source_ident", "gps_code", "longest_qualified_runway_m", "longest_qualified_surface",
    "technical_minimum_level", "runway_status", "qualified_runway_count",
    "qualification_group", "final_assigned_category", "provisional_category",
    "review_decision_status", "game_active", "gameplay_access_status",
)
RUNWAY_FIELDS = (
    "airport_key", "source_airport_id", "source_runway_id", "qualification_group",
    "source_record_type", "individual_runway_dimensions_verified",
)
TRAFFIC_FIELDS = (
    "airport_key", "source_airport_id", "country_iso", "airport_name", "final_assigned_category",
    "provisional_category", "decision_status", "passenger_activity_signal", "cargo_activity_signal",
    "regular_passenger_proxy", "nonregular_passenger_proxy", "regular_cargo_proxy_kg",
    "nonregular_cargo_proxy_kg", "evidence_year", "annual_total_passenger_proxy",
    "passenger_measure", "annual_cargo_tonnes_proxy", "domestic_passenger_floor_proxy",
    "evidence_source_url",
)
CAPACITY_FIELDS = (
    "airport_key", "source_airport_id", "country_iso", "icao_or_ident",
    "airport_name", "as_of_date", "metric", "observed_capacity_per_hour", "unit",
    "scope", "source_url", "qualification_note", "game_slot_capacity_approved",
)
ACCESS_FIELDS = (
    "airport_key", "source_airport_id", "passenger_permission_review",
    "cargo_permission_review", "review_classification", "passenger_evidence_url",
    "cargo_evidence_url", "access_evidence_url", "verification_as_of", "review_notes",
    "operational_access_status", "import_source_status",
)

def load_csv(root: Path, relative: Path, used: dict[str, str]) -> list[dict[str, str]]:
    path = root / relative
    if not path.is_file():
        raise ValueError(f"Missing source: {relative}")
    payload = path.read_bytes()
    used[relative.as_posix()] = hashlib.sha256(payload).hexdigest()
    with io.StringIO(payload.decode("utf-8-sig"), newline="") as stream:
        rd = csv.DictReader(stream)
        if not rd.fieldnames or len(rd.fieldnames) != len(set(rd.fieldnames)):
            raise ValueError(f"Invalid or repeated source columns: {relative}")
        rows = list(rd)
    if any(None in r or any(v is None for v in r.values()) for r in rows):
        raise ValueError(f"Malformed CSV input: {relative}")
    return rows

def unique(rows: list[dict[str, str]], key: str, label: str) -> dict[str, dict[str, str]]:
    result: dict[str, dict[str, str]] = {}
    for row in rows:
        ident = row.get(key, "")
        if not ident or ident in result:
            raise ValueError(f"Blank or duplicate {label}: {ident!r}")
        result[ident] = row
    return result

def render(fields: tuple[str, ...], rows: list[dict[str, str]]) -> bytes:
    stream = io.StringIO(newline="")
    writer = csv.DictWriter(stream, fieldnames=fields, extrasaction="raise", lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    return stream.getvalue().encode("utf-8")

def build_snapshot(root: Path) -> tuple[dict[str, bytes], dict[str, object]]:
    """Validate inputs and return reproducible payloads; no file/database mutations."""
    used: dict[str, str] = {}
    master_rows = load_csv(root, AIRPORTS / "airport_register.csv", used)
    review_rows = load_csv(root, AIRPORTS / "classification/airport_classification_review.csv", used)
    master = unique(master_rows, "source_airport_id", "master airport ID")
    review = unique(review_rows, "source_airport_id", "classification airport ID")
    if not master or set(master) != set(review):
        raise ValueError("Airport master/classification IDs are not identical")
    if len([r for r in master_rows if r.get("source_type") == "FICTIONAL"]) != 1:
        raise ValueError("Protected fictional airport count unexpected")
    fict = master.get("fictional:RS:LYAL")
    if not fict or fict["ident"] != "LYAL" or fict["assigned_category"] != "Local":
        raise ValueError("Protected LYAL definition missing or modified")

    group_rows: dict[str, tuple[str, dict[str, str]]] = {}
    source_runways: dict[str, str] = {}
    pattern = re.compile(r"group([1-9][0-9]*)_technical_candidates\.csv$")
    group_files = sorted((root / AIRPORTS / "generated").glob("group*/group*_technical_candidates.csv"))
    if not group_files:
        raise ValueError("No source group technical screens found")
    for group_file in group_files:
        match = pattern.fullmatch(group_file.name)
        if not match or group_file.parent.name != f"group{match.group(1)}":
            raise ValueError(f"Invalid source group file {group_file}")
        group = match.group(1)
        records = load_csv(root, group_file.relative_to(root), used)
        for r in records:
            source_id = r["ourairports_id"]
            if source_id in group_rows or source_id not in master:
                raise ValueError(f"Duplicate / orphan group candidate {source_id} in group {group}")
            m = master[source_id]
            if (m["source_type"] != "OURAIRPORTS" or r["iso_country"] != m["country_iso"]
                    or r["ident"] != m["ident"]):
                raise ValueError(f"Country/identifier mismatch for group candidate {source_id}")
            runway_ids = [x.strip() for x in r["runway_ids"].split(";") if x.strip()]
            if len(runway_ids) != int(r["eligible_runway_count"]) or not runway_ids:
                raise ValueError(f"Bad runway count / IDs at {source_id}")
            group_rows[source_id] = (group, r)
            for runway_id in runway_ids:
                if runway_id in source_runways:
                    raise ValueError(f"Duplicate source runway ID: {runway_id}")
                source_runways[runway_id] = source_id
    missing = sorted(source_id for source_id, m in master.items()
                     if m["source_type"] == "OURAIRPORTS" and source_id not in group_rows)
    if missing:
        raise ValueError(f"Technical source group not found for {len(missing)} real airports: {missing[:8]}")

    reviews: dict[str, dict[str, str]] = {}
    commercial_files = sorted((root / AIRPORTS / "commercial").glob("group*/group*_commercial_review.csv"))
    if not commercial_files:
        raise ValueError("No commercial-review source CSVs found")
    for commercial_file in commercial_files:
        for r in load_csv(root, commercial_file.relative_to(root), used):
            ident = r["source_airport_id"]
            if ident in reviews or ident not in master:
                raise ValueError(f"Duplicate or unknown commercial review: {ident}")
            if r["country_iso"] != master[ident]["country_iso"]:
                raise ValueError(f"Commercial review country mismatch: {ident}")
            reviews[ident] = r

    reference_out: list[dict[str, str]] = []
    traffic_out: list[dict[str, str]] = []
    access_out: list[dict[str, str]] = []
    runway_out: list[dict[str, str]] = []
    statuses: Counter[str] = Counter()
    b02_count = b02_total = 0
    for ident in sorted(master, key=lambda x: (master[x]["country_iso"], x)):
        m, t = master[ident], review[ident]
        if t["country_iso"] != m["country_iso"] or t["airport_name"] != m["airport_name"]:
            raise ValueError(f"Master/classification identity drift: {ident}")
        if m["assigned_category"] != t["final_assigned_category"]:
            raise ValueError(f"Final category drift between datasets: {ident}")
        if t["provisional_category"] and t["provisional_category"] not in CATEGORIES:
            raise ValueError(f"Invalid six-tier category: {ident}")
        if m["source_type"] == "OURAIRPORTS" and m["assigned_category"]:
            raise ValueError(f"Real airport has an unapproved final category: {ident}")
        source_type = m["source_type"]
        if source_type not in {"OURAIRPORTS", "FICTIONAL"}:
            raise ValueError(f"Invalid source type: {ident}")
        key = f"{source_type}:{ident}"
        screen = group_rows.get(ident)
        runway_ids = [x.strip() for x in screen[1]["runway_ids"].split(";") if x.strip()] if screen else []
        group = screen[0] if screen else ""
        reference_out.append(dict(
            airport_key=key, source_airport_id=ident, source_type=source_type,
            country_iso=m["country_iso"], airport_name=m["airport_name"],
            source_ident=m["ident"], gps_code=m["gps_code"],
            longest_qualified_runway_m=m["runway_length_m"],
            longest_qualified_surface=m["runway_surface"],
            technical_minimum_level=m["minimum_eligible_level"], runway_status=m["runway_status"],
            qualified_runway_count=str(len(runway_ids)) if screen else "",
            qualification_group=group, final_assigned_category=m["assigned_category"],
            provisional_category=t["provisional_category"],
            review_decision_status=t["decision_status"], game_active="false",
            gameplay_access_status="NOT_AUTHORIZED_FOR_LIVE_IMPORT"))
        traffic_out.append({"airport_key": key, **{name: t[name] for name in TRAFFIC_FIELDS if name != "airport_key"}})
        c = reviews.get(ident)
        access_out.append(dict(
            airport_key=key, source_airport_id=ident,
            passenger_permission_review=c["passenger_commercial_permission"] if c else "UNKNOWN",
            cargo_permission_review=c["cargo_commercial_permission"] if c else "UNKNOWN",
            review_classification=c["review_classification"] if c else "NOT_YET_REVIEWED",
            passenger_evidence_url=c["passenger_evidence_url"] if c else "",
            cargo_evidence_url=c["cargo_evidence_url"] if c else "",
            access_evidence_url=c["access_evidence_url"] if c else "",
            verification_as_of=c["verification_as_of"] if c else "",
            review_notes=c["review_notes"] if c else "",
            operational_access_status="UNVERIFIED",
            import_source_status="PRELIMINARY_COMMERCIAL_REVIEW" if c else "NO_COMMERCIAL_REVIEW"))
        for runway_id in runway_ids:
            runway_out.append(dict(airport_key=key, source_airport_id=ident,
                source_runway_id=runway_id, qualification_group=group,
                source_record_type="GROUP_TECHNICAL_SCREEN",
                individual_runway_dimensions_verified="false"))
        statuses[t["decision_status"]] += 1
        if m["country_iso"] in B02_CODES:
            b02_total += 1
            if t["provisional_category"]:
                b02_count += 1

    # Published capacity is a separate evidence stream: NEVER a player slot budget.
    capacity_raw = load_csv(root, AIRPORTS / "operations/b02_2025_published_capacity_evidence.csv", used)
    capacity_out: list[dict[str, str]] = []
    capacity_seen: set[tuple[str, str, str]] = set()
    for src in capacity_raw:
        sid = src["source_airport_id"]
        m = master.get(sid)
        if not m or m["country_iso"] != src["country_iso"] or src["icao_or_ident"] not in {m["ident"], m["gps_code"]}:
            raise ValueError(f"Capacity source airport/country/code mismatch: {sid}")
        key = (sid, src["as_of_date"], src["metric"])
        if key in capacity_seen:
            raise ValueError(f"Duplicate capacity evidence key: {key}")
        capacity_seen.add(key)
        if (not re.fullmatch(r"[0-9]+", src["observed_capacity_per_hour"])
                or int(src["observed_capacity_per_hour"]) <= 0
                or src["unit"] != "movements_per_hour"
                or not src["source_url"].startswith("https://")):
            raise ValueError(f"Invalid published capacity evidence: {sid}")
        capacity_out.append({
            "airport_key": f"{m['source_type']}:{sid}",
            **{name: src[name] for name in CAPACITY_FIELDS if name not in {"airport_key", "game_slot_capacity_approved"}},
            "game_slot_capacity_approved": "false",
        })

    payloads = {
        "airport_capacity_evidence.csv": render(CAPACITY_FIELDS, capacity_out),
        "airport_reference.csv": render(REFERENCE_FIELDS, reference_out),
        "airport_traffic_review.csv": render(TRAFFIC_FIELDS, traffic_out),
        "airport_access_review.csv": render(ACCESS_FIELDS, access_out),
        "airport_runway_source_links.csv": render(RUNWAY_FIELDS, runway_out),
    }
    manifest: dict[str, object] = {
        "format_version": 1,
        "scope": "NON_OPERATIONAL_AIRPORT_REFERENCE_HANDOFF",
        "source_of_truth": "GitHub Airlinerra airport CSVs",
        "supabase_applied": False,
        "gameplay_activation_authorized": False,
        "airport_count": len(master),
        "technical_runway_reference_count": len(runway_out),
        "commercial_review_count": len(reviews),
        "published_capacity_evidence_count": len(capacity_out),
        "b02_qualified_airports": b02_total,
        "b02_provisional_passenger_tiers": b02_count,
        "final_real_airport_assignments": 0,
        "decision_status_counts": dict(sorted(statuses.items())),
        "source_sha256": dict(sorted(used.items())),
        "output_sha256": {name: hashlib.sha256(data).hexdigest() for name, data in sorted(payloads.items())},
    }
    payloads["snapshot_manifest.json"] = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode("utf-8")
    return payloads, manifest

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify source crosswalk; do not write anything")
    parser.add_argument("--out-dir", type=Path, help="Write a portable local reference snapshot; NO DB changes")
    args = parser.parse_args()
    if args.check == bool(args.out_dir):
        parser.error("Specify exactly one of --check or --out-dir")
    payloads, summary = build_snapshot(ROOT)
    if args.out_dir:
        args.out_dir.mkdir(parents=True, exist_ok=True)
        for name, data in payloads.items():
            (args.out_dir / name).write_bytes(data)
    print("AIRPORT HANDOFF: " + json.dumps({
        "airports": summary["airport_count"],
        "runway_source_links": summary["technical_runway_reference_count"],
        "commercial_reviews": summary["commercial_review_count"],
        "b02_passenger_tiers": summary["b02_provisional_passenger_tiers"],
        "supabase_applied": False,
    }, sort_keys=True))

if __name__ == "__main__":
    main()
