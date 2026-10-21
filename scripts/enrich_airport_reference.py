#!/usr/bin/env python3
"""Rebuild separate airport enrichment snapshots from pinned OurAirports CSVs.

Never alters the canonical runway register or deploys to Supabase.
Example:
 python scripts/enrich_airport_reference.py --airports airports.csv --runways runways.csv \
   --source-commit b529623d2a0b09a9be78d37fc7a7a5e1e16e3451
"""
from __future__ import annotations
import argparse
import csv
import pathlib
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parents[1]
MASTER = ROOT / "data/airports/airport_register.csv"
OVERRIDES = ROOT / "data/airports/runway_surface_overrides.csv"
DEFAULT_OUT = ROOT / "data/airports/enriched"
PAVEMENT = {"ASP", "ASPH", "ASPHALT", "ASPHALTE", "ASPHALTED",
            "ASPHALTCONCRETE", "CON", "CONC", "CONCRETE", "BETON", "BITUMEN",
            "ASP/CON", "CON/ASP", "ASPH/CONC", "CONC/ASPH", "ASPHALT/CONCRETE",
            "CONCRETE/ASPHALT", "ASP-CON", "CON-ASP"}

IDENTITY_COLUMNS = ("source_airport_id", "country_iso", "airport_name", "source_ident",
                    "gps_code", "icao_code", "iata_code", "local_code", "latitude_deg",
                    "longitude_deg", "elevation_ft", "municipality", "iso_region",
                    "airport_type", "scheduled_service_source", "source_type",
                    "coordinate_status", "code_status", "source_snapshot")
RUNWAY_COLUMNS = ("source_airport_id", "source_runway_id", "runway_low", "runway_high",
                  "length_m", "width_m", "surface_raw", "surface_qualified",
                  "lighted_source", "source_airport_ident", "le_latitude_deg",
                  "le_longitude_deg", "he_latitude_deg", "he_longitude_deg",
                  "le_heading_deg", "he_heading_deg", "qualification_evidence",
                  "source_url", "source_snapshot")
REVIEW_COLUMNS = ("source_airport_id", "country_iso", "passenger_permission",
                  "cargo_permission", "commercial_readiness",
                  "scheduled_passenger_observed", "cargo_facilities", "passenger_terminal",
                  "operating_hours", "curfew", "noise_restrictions", "contact_gates",
                  "remote_stands", "apron_stands", "published_runway_movements_per_hour",
                  "game_estimated_runway_movements_per_hour", "actual_passengers_annual",
                  "actual_cargo_tonnes_annual", "game_passenger_demand_daily",
                  "game_cargo_demand_tonnes_daily", "evidence_status")
EXCEPTION_COLUMNS = ("source_airport_id", "country_iso", "issue", "detail", "review_status")
COUNTRY_COLUMNS = ("country_iso", "airports", "with_coordinates", "icao_source_reported",
                   "iata_source_reported", "qualifying_runway_rows", "exceptions")

def read(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))

def write(path, columns, records):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(records)

def pavement(value):
    normalized = "".join((value or "").strip().strip("'\"").upper().split())
    if normalized in PAVEMENT:
        return True
    import re
    return bool(re.search(r"[/+;&-]", normalized)) and all(
        part in PAVEMENT for part in re.split(r"[/+;&-]", normalized))

def number(value):
    try:
        return float(value) if value not in (None, "") else None
    except ValueError:
        return None

def coord(value, minval, maxval):
    parsed = number(value)
    return parsed if parsed is not None and minval <= parsed <= maxval else None

def f(value, decimals):
    return "" if value is None else str(round(value, decimals))

def build(airports_file, runways_file, source_commit, out=DEFAULT_OUT):
    if len(source_commit) != 40 or not all(ch in "0123456789abcdef" for ch in source_commit):
        raise ValueError("Pin a complete 40-character lowercase OurAirports commit SHA")
    master = read(MASTER)
    by_id = {r["source_airport_id"]: r for r in master}
    if len(by_id) != len(master) or not master:
        raise ValueError("Master airport IDs not unique")
    airports = {r["id"]: r for r in read(airports_file)}
    overrides = {r["ourairports_id"]: r for r in read(OVERRIDES)}
    runway_records, airport_runways = [], defaultdict(list)
    for raw in read(runways_file):
        airport_id = raw.get("airport_ref", "")
        record = by_id.get(airport_id)
        if not record or record["source_type"] != "OURAIRPORTS":
            continue
        if raw.get("closed", "").strip().lower() in ("1", "true", "yes"):
            continue
        raw_length = number(raw.get("length_ft"))
        if raw_length is None:
            continue
        length_m = raw_length * 0.3048
        surface = raw.get("surface", "")
        evidence, evidence_url = "RAW_EXPLICIT", ""
        override = overrides.get(airport_id)
        if (override and not pavement(surface) and
                surface.strip().lower() == override["previous_surface_label"].strip().lower()):
            length_m = float(override["reference_runway_length_m"])
            surface = override["verified_surface"]
            evidence, evidence_url = "AIRPORT_SPECIFIC_OVERRIDE", override["source_url"]
        if length_m < 1200 or not pavement(surface):
            continue
        width_ft = number(raw.get("width_ft"))
        result = dict(
            source_airport_id=airport_id, source_runway_id=raw["id"],
            runway_low=raw["le_ident"], runway_high=raw["he_ident"],
            length_m=f(length_m, 1), width_m=f(width_ft * 0.3048 if width_ft is not None else None, 1),
            surface_raw=raw.get("surface", ""), surface_qualified=surface,
            lighted_source=raw.get("lighted", ""),
            source_airport_ident=raw.get("airport_ident", ""),
            le_latitude_deg=raw.get("le_latitude_deg", ""),
            le_longitude_deg=raw.get("le_longitude_deg", ""),
            he_latitude_deg=raw.get("he_latitude_deg", ""),
            he_longitude_deg=raw.get("he_longitude_deg", ""),
            le_heading_deg=raw.get("le_heading_degT", ""),
            he_heading_deg=raw.get("he_heading_degT", ""),
            qualification_evidence=evidence, source_url=evidence_url, source_snapshot=source_commit)
        runway_records.append(result)
        airport_runways[airport_id].append(result)
    identities, reviews, exceptions = [], [], []
    for item in master:
        ident = item["source_airport_id"]
        fictional = item["source_type"] == "FICTIONAL"
        raw = None if fictional else airports.get(ident)
        lat = coord(raw.get("latitude_deg"), -90, 90) if raw else None
        lon = coord(raw.get("longitude_deg"), -180, 180) if raw else None
        valid = lat is not None and lon is not None
        identities.append(dict(source_airport_id=ident, country_iso=item["country_iso"],
            airport_name=item["airport_name"], source_ident=item["ident"], gps_code=item["gps_code"],
            icao_code=raw.get("icao_code", "") if raw else "",
            iata_code=raw.get("iata_code", "") if raw else "",
            local_code=raw.get("local_code", "") if raw else "",
            latitude_deg=f(lat, 7) if valid else "",
            longitude_deg=f(lon, 7) if valid else "",
            elevation_ft=raw.get("elevation_ft", "") if raw else "",
            municipality=raw.get("municipality", "") if raw else "",
            iso_region=raw.get("iso_region", "") if raw else "",
            airport_type=raw.get("type", "") if raw else "FICTIONAL",
            scheduled_service_source=(raw.get("scheduled_service", "").upper() or "UNKNOWN")
                if raw else "UNKNOWN",
            source_type=item["source_type"],
            coordinate_status="FICTIONAL_UNSPECIFIED" if fictional else
                ("SOURCE_REPORTED" if valid else "REVIEW_REQUIRED"),
            code_status="OWNER_DEFINED" if fictional else "SOURCE_REPORTED_NOT_VERIFIED",
            source_snapshot="" if fictional else source_commit))
        reviews.append(dict(source_airport_id=ident, country_iso=item["country_iso"],
            passenger_permission="UNKNOWN", cargo_permission="UNKNOWN",
            commercial_readiness="NEEDS_REVIEW", scheduled_passenger_observed="UNKNOWN",
            cargo_facilities="UNKNOWN", passenger_terminal="UNKNOWN", operating_hours="UNKNOWN",
            curfew="UNKNOWN", noise_restrictions="UNKNOWN", contact_gates="", remote_stands="",
            apron_stands="", published_runway_movements_per_hour="",
            game_estimated_runway_movements_per_hour="", actual_passengers_annual="",
            actual_cargo_tonnes_annual="", game_passenger_demand_daily="",
            game_cargo_demand_tonnes_daily="", evidence_status="UNVERIFIED"))
        if not fictional and raw is None:
            exceptions.append(dict(source_airport_id=ident, country_iso=item["country_iso"],
                issue="SOURCE_AIRPORT_ID_NOT_FOUND", detail="", review_status="OPEN"))
        if not fictional and not valid:
            exceptions.append(dict(source_airport_id=ident, country_iso=item["country_iso"],
                issue="INVALID_OR_MISSING_COORDINATES",
                detail=f"{raw.get('latitude_deg','')},{raw.get('longitude_deg','')}" if raw else "",
                review_status="OPEN"))
        if not fictional and not airport_runways[ident]:
            exceptions.append(dict(source_airport_id=ident, country_iso=item["country_iso"],
                issue="QUALIFYING_RUNWAY_NOT_RECONCILED",
                detail=f"master {item['runway_length_m']}m {item['runway_surface']}; inspect group source and overrides",
                review_status="OPEN"))
        if not fictional and airport_runways[ident]:
            longest = max(float(r["length_m"]) for r in airport_runways[ident])
            if longest < float(item["runway_length_m"]) - 1.1:
                exceptions.append(dict(source_airport_id=ident, country_iso=item["country_iso"],
                    issue="RAW_RUNWAY_SHORTER_THAN_MASTER",
                    detail=f"master {item['runway_length_m']}m; largest current source {longest}m",
                    review_status="OPEN"))
    countries = []
    for code in sorted({r["country_iso"] for r in master}):
        countries.append(dict(country_iso=code,
            airports=sum(r["country_iso"] == code for r in master),
            with_coordinates=sum(r["country_iso"] == code and r["coordinate_status"] == "SOURCE_REPORTED"
                                 for r in identities),
            icao_source_reported=sum(r["country_iso"] == code and bool(r["icao_code"]) for r in identities),
            iata_source_reported=sum(r["country_iso"] == code and bool(r["iata_code"]) for r in identities),
            qualifying_runway_rows=sum(by_id[r["source_airport_id"]]["country_iso"] == code
                                       for r in runway_records),
            exceptions=sum(r["country_iso"] == code for r in exceptions)))
    write(out / "airport_identity.csv", IDENTITY_COLUMNS, identities)
    write(out / "qualifying_runways.csv", RUNWAY_COLUMNS, runway_records)
    write(out / "commercial_review_queue.csv", REVIEW_COLUMNS, reviews)
    write(out / "enrichment_exceptions.csv", EXCEPTION_COLUMNS, exceptions)
    write(out / "country_counts.csv", COUNTRY_COLUMNS, countries)
    (out / "SOURCE.txt").write_text(
        "Airlinerra identity/runway bulk enrichment\n"
        f"OurAirports source commit: {source_commit}\n"
        f"https://raw.githubusercontent.com/davidmegginson/ourairports-data/{source_commit}/airports.csv\n"
        f"https://raw.githubusercontent.com/davidmegginson/ourairports-data/{source_commit}/runways.csv\n"
        "No live commercial permissions inferred; fictional LYAL location is deliberately blank.\n",
        encoding="utf-8")
    print(f"ENRICHED {len(identities)} airports; source coordinates {sum(x['coordinate_status']=='SOURCE_REPORTED' for x in identities)}; runways {len(runway_records)}; exceptions {len(exceptions)}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--airports", required=True, type=pathlib.Path)
    parser.add_argument("--runways", required=True, type=pathlib.Path)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--out", type=pathlib.Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    build(args.airports, args.runways, args.source_commit, args.out)
