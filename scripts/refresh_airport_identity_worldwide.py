#!/usr/bin/env python3
"""Bulk, source-ID-only identity refresh. Does not change runway master or activate airports."""
from __future__ import annotations
import argparse
import csv
import hashlib
import io
import json
import math
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "data/airports/airport_register.csv"
LOCATION = ROOT / "data/airports/identity/fictional_location_references.csv"
MILITARY = ROOT / "data/airports/identity/verified_military_only.csv"
DEFAULT_OUT = ROOT / "data/airports/identity"
FIELDS = (
    "source_airport_id", "country_iso", "airport_name", "source_ident", "source_type",
    "gps_code", "gps_code_status", "icao_code", "icao_code_status", "iata_code",
    "iata_code_status", "local_code", "latitude_deg", "longitude_deg",
    "coordinate_status", "municipality", "iso_region", "elevation_ft",
    "airport_type_source", "scheduled_service_source", "military_review_hint",
    "military_only_status", "gameplay_status", "location_reference",
    "source_snapshot",
)
EXCEPTION_FIELDS = ("source_airport_id", "country_iso", "issue", "detail", "status")

def read(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        if not reader.fieldnames or len(set(reader.fieldnames)) != len(reader.fieldnames):
            raise ValueError(f"Invalid header: {path}")
        result = list(reader)
    if any(None in r or any(v is None for v in r.values()) for r in result):
        raise ValueError(f"Malformed CSV: {path}")
    return result

def indexed(rows: list[dict[str, str]], field: str) -> dict[str, dict[str, str]]:
    output = {}
    for row in rows:
        ident = row[field]
        if not ident or ident in output:
            raise ValueError(f"Missing/duplicate {field}: {ident!r}")
        output[ident] = row
    return output

def valid_coord(s: str, low: int, high: int) -> bool:
    try:
        n = float(s)
        return math.isfinite(n) and low <= n <= high
    except (ValueError, TypeError):
        return False

def output_csv(fields: tuple[str, ...], rows: list[dict[str, str]]) -> bytes:
    s = io.StringIO(newline="")
    writer = csv.DictWriter(s, fieldnames=fields, extrasaction="raise", lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    return s.getvalue().encode("utf-8")

def build(source_csv: Path, source_sha: str, root: Path = ROOT) -> tuple[dict[str, bytes], dict]:
    if not re.fullmatch(r"[0-9a-f]{40}", source_sha):
        raise ValueError("OurAirports source commit must be exactly 40 lowercase hex characters")
    master = read(root / "data/airports/airport_register.csv")
    original = indexed(master, "source_airport_id")
    sources = indexed(read(source_csv), "id")
    sites = indexed(read(root / "data/airports/identity/fictional_location_references.csv"), "source_airport_id")
    military = indexed(read(root / "data/airports/identity/verified_military_only.csv"), "source_airport_id")
    if len(master) != 8153 and root == ROOT:
        raise ValueError(f"Unexpected canonical airport count {len(master)}")
    if set(sites) != {"fictional:RS:LYAL"}:
        raise ValueError("Fictional LYAL place record missing or unexpected")
    site = sites["fictional:RS:LYAL"]
    if (site["country_iso"] != "RS" or site["municipality"] != "Nova Crnja"
            or site["region"] != "Banat" or site["place_name"] != "Aleksandrovo"
            or site["coordinate_kind"] != "SETTLEMENT_CENTER_NOT_AIRPORT_SITE"):
        raise ValueError("LYAL reference is not approved village/region metadata")
    if not valid_coord(site["reference_latitude_deg"], -90, 90) or not valid_coord(site["reference_longitude_deg"], -180, 180):
        raise ValueError("Invalid Aleksandrovo settlement reference coordinates")
    for ident, restriction in military.items():
        if (ident not in original or original[ident]["source_type"] != "OURAIRPORTS"
                or original[ident]["country_iso"] != restriction["country_iso"]
                or restriction["verified_status"] != "MILITARY_ONLY_CONFIRMED"
                or not restriction["evidence_url"].startswith("https://")
                or not restriction["evidence_date"] or not restriction["review_note"]):
            raise ValueError(f"Military-only evidence invalid: {ident}")
    records, exceptions = [], []
    for m in master:
        ident = m["source_airport_id"]
        fictional = m["source_type"] == "FICTIONAL"
        if m["source_type"] not in ("OURAIRPORTS", "FICTIONAL"):
            raise ValueError(f"Invalid source type: {ident}")
        if fictional and (ident != "fictional:RS:LYAL" or m["ident"] != "LYAL" or m["country_iso"] != "RS"):
            raise ValueError("Fictional location must remain the owner-defined LYAL")
        raw = None if fictional else sources.get(ident)
        issues = []
        if not fictional and raw is None:
            issues.append(("SOURCE_ID_NOT_FOUND", "ID absent in chosen OurAirports snapshot"))
        if raw and raw.get("iso_country") != m["country_iso"]:
            issues.append(("COUNTRY_MISMATCH", f"master={m['country_iso']}; source={raw.get('iso_country','')}"))
            raw = None   # never import potentially misjoined identity information
        src = raw or {}
        gps = src.get("gps_code", "") or m["gps_code"]
        gps_status = ("OWNER_DEFINED" if fictional else "SOURCE_REPORTED" if src.get("gps_code")
                      else "MASTER_FALLBACK" if m["gps_code"] else "NOT_REPORTED")
        icao = src.get("icao_code", "") if not fictional else ""
        iata = src.get("iata_code", "") if not fictional else ""
        icao_status = "SOURCE_REPORTED_UNVERIFIED" if icao else "NOT_REPORTED"
        iata_status = "SOURCE_REPORTED_UNVERIFIED" if iata else "NOT_REPORTED"
        if raw and raw.get("ident") != m["ident"]:
            issues.append(("SOURCE_IDENT_CHANGED", f"master={m['ident']}; source={raw.get('ident','')}"))
        if (icao and not re.fullmatch("[A-Z]{4}", icao)) or (iata and not re.fullmatch("[A-Z]{3}", iata)):
            issues.append(("IDENTIFIER_FORMAT_REVIEW", f"icao={icao}; iata={iata}"))
        if raw and valid_coord(src.get("latitude_deg", ""), -90, 90) and valid_coord(src.get("longitude_deg", ""), -180, 180) and not (float(src["latitude_deg"]) == 0 and float(src["longitude_deg"]) == 0):
            lat, lon, pos_status = src["latitude_deg"], src["longitude_deg"], "SOURCE_COORDINATES_REPORTED"
        else:
            lat = lon = ""
            pos_status = "FICTIONAL_AIRPORT_SITE_UNSPECIFIED" if fictional else "MISSING_OR_INVALID"
            if not fictional:
                issues.append(("MISSING_OR_INVALID_COORDINATES", "Airport location must be resolved"))
        name = m["airport_name"].lower()
        hint = "NAME_SUGGESTS_MILITARY_REVIEW" if any(x in name for x in ("air base", "air force base", "airbase", "naval air station", "army airfield", "military airport", "raf station")) else "NONE"
        verified = ident in military
        loc_note = ("Aleksandrovo, municipality Nova Crnja, Central Banat, Vojvodina, Serbia; "
                    "village centre is not the fictional runway position") if fictional else ""
        records.append(dict(
            source_airport_id=ident, country_iso=m["country_iso"], airport_name=m["airport_name"],
            source_ident=m["ident"], source_type=m["source_type"], gps_code=gps,
            gps_code_status=gps_status, icao_code=icao, icao_code_status=icao_status,
            iata_code=iata, iata_code_status=iata_status, local_code=src.get("local_code", ""),
            latitude_deg=lat, longitude_deg=lon, coordinate_status=pos_status,
            municipality=src.get("municipality", "") if not fictional else site["municipality"],
            iso_region=src.get("iso_region", "") if not fictional else "",
            elevation_ft=src.get("elevation_ft", ""), airport_type_source=src.get("type", "") if not fictional else "FICTIONAL",
            scheduled_service_source=src.get("scheduled_service", "") if not fictional else "OWNER_DEFINED",
            military_review_hint=hint, military_only_status="MILITARY_ONLY_CONFIRMED" if verified else "UNVERIFIED",
            gameplay_status="EXCLUDED_MILITARY_ONLY" if verified else "DESIGN_ONLY_NOT_ACTIVE" if fictional else "RESEARCH_ONLY_NOT_ACTIVE",
            location_reference=loc_note, source_snapshot=source_sha if raw else "",
        ))
        for issue, detail in issues:
            exceptions.append(dict(source_airport_id=ident, country_iso=m["country_iso"], issue=issue, detail=detail, status="OPEN"))
    counts = Counter(r["coordinate_status"] for r in records)
    stats = {
        "format_version": 1, "source_commit": source_sha, "airports": len(records),
        "real_airports": sum(x["source_type"] == "OURAIRPORTS" for x in records),
        "coordinates_source_reported": counts["SOURCE_COORDINATES_REPORTED"],
        "source_icao_reported": sum(bool(x["icao_code"]) for x in records),
        "source_iata_reported": sum(bool(x["iata_code"]) for x in records),
        "gps_codes_available": sum(bool(x["gps_code"]) for x in records),
        "confirmed_military_only_excluded": len(military),
        "military_name_review_hints": sum(x["military_review_hint"] != "NONE" for x in records),
        "exceptions": dict(sorted(Counter(x["issue"] for x in exceptions).items())),
        "gameplay_activation_performed": False,
        "source_data_sha256": hashlib.sha256(source_csv.read_bytes()).hexdigest(),
    }
    content = {
        "airport_identity_worldwide.csv": output_csv(FIELDS, records),
        "identity_exceptions.csv": output_csv(EXCEPTION_FIELDS, exceptions),
    }
    stats["output_sha256"] = {name: hashlib.sha256(b).hexdigest() for name, b in sorted(content.items())}
    content["identity_summary.json"] = (json.dumps(stats, indent=2, sort_keys=True) + "\n").encode("utf-8")
    return content, stats

def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--airports", type=Path, required=True)
    p.add_argument("--source-commit", required=True)
    p.add_argument("--out", type=Path, default=DEFAULT_OUT)
    p.add_argument("--check", action="store_true")
    args = p.parse_args()
    payloads, summary = build(args.airports, args.source_commit)
    if args.check:
        for name, data in payloads.items():
            if not (args.out / name).is_file() or (args.out / name).read_bytes() != data:
                raise SystemExit(f"Identity refresh file needs rebuilding: {name}")
    else:
        args.out.mkdir(parents=True, exist_ok=True)
        for name, data in payloads.items():
            (args.out / name).write_bytes(data)
    print("WORLDWIDE IDENTITY: " + json.dumps({
        k: summary[k] for k in ("airports", "real_airports", "coordinates_source_reported",
                               "gps_codes_available", "source_icao_reported", "source_iata_reported",
                               "confirmed_military_only_excluded", "exceptions")
    }, sort_keys=True))

if __name__ == "__main__":
    main()
