#!/usr/bin/env python3
"""Verify worldwide airport enrichment does not alter the runway-qualified master."""
from __future__ import annotations
import csv
import math
import pathlib
from collections import Counter, defaultdict
from enrich_airport_reference import pavement

ROOT = pathlib.Path(__file__).resolve().parents[1]
DATA = ROOT / "data/airports/enriched"
MASTER = ROOT / "data/airports/airport_register.csv"

def read(path):
    with path.open(encoding="utf-8-sig", newline="") as f:
        rd = csv.DictReader(f)
        if not rd.fieldnames or len(set(rd.fieldnames)) != len(rd.fieldnames):
            raise ValueError(f"Invalid CSV header {path}")
        rows = list(rd)
        if any(None in row for row in rows):
            raise ValueError(f"Malformed CSV {path}")
        return rows

def validate():
    master = read(MASTER)
    original = {r["source_airport_id"]: r for r in master}
    identity = read(DATA / "airport_identity.csv")
    runways = read(DATA / "qualifying_runways.csv")
    reviews = read(DATA / "commercial_review_queue.csv")
    exceptions = read(DATA / "enrichment_exceptions.csv")
    countries = read(DATA / "country_counts.csv")
    pilot = read(DATA / "serbia_commercial_pilot.csv")
    assert len(master) == len(identity) == len(reviews) == len(original), "Dropped/duplicate airport"
    assert set(x["source_airport_id"] for x in identity) == set(original), "Identity IDs differ"
    assert set(x["source_airport_id"] for x in reviews) == set(original), "Review IDs differ"
    assert {x["source_airport_id"] for x in pilot} == {x["source_airport_id"] for x in master if x["country_iso"]=="RS"}, "Serbia pilot incomplete"
    assert len(pilot)==7, "Unexpected Serbia pilot size"
    ids = set()
    counted = Counter()
    location_count = Counter()
    icao_count = Counter()
    iata_count = Counter()
    for r in identity:
        m = original[r["source_airport_id"]]
        code = r["country_iso"]
        assert (code,r["airport_name"],r["source_ident"])==(m["country_iso"],m["airport_name"],m["ident"])
        counted[code]+=1
        if m["source_type"]=="FICTIONAL":
            assert r["source_airport_id"]=="fictional:RS:LYAL"
            assert not r["latitude_deg"] and not r["longitude_deg"] and not r["icao_code"]
            assert r["coordinate_status"]=="FICTIONAL_UNSPECIFIED"
        else:
            assert r["source_snapshot"] and len(r["source_snapshot"])==40
            if r["coordinate_status"]=="SOURCE_REPORTED":
                lat,lon=float(r["latitude_deg"]),float(r["longitude_deg"])
                assert math.isfinite(lat) and math.isfinite(lon)
                assert -90<=lat<=90 and -180<=lon<=180
                location_count[code]+=1
            else:
                assert not r["latitude_deg"] and not r["longitude_deg"]
        if r["icao_code"]: icao_count[code]+=1
        if r["iata_code"]: iata_count[code]+=1
    runway_count=Counter()
    by_airport=defaultdict(list)
    for r in runways:
        airport=r["source_airport_id"]
        assert airport in original and original[airport]["source_type"]=="OURAIRPORTS"
        source_id=r["source_runway_id"]
        assert source_id not in ids, f"Duplicate source runway {source_id}"
        ids.add(source_id)
        assert float(r["length_m"])>=1200 and pavement(r["surface_qualified"])
        assert not r["width_m"] or float(r["width_m"])>0
        if r["qualification_evidence"]=="AIRPORT_SPECIFIC_OVERRIDE":
            assert r["source_url"].startswith("https://")
        else:
            assert r["qualification_evidence"]=="RAW_EXPLICIT" and not r["source_url"]
        runway_count[original[airport]["country_iso"]]+=1
        by_airport[airport].append(r)
    for m in master:
        if m["source_type"]=="OURAIRPORTS":
            assert by_airport[m["source_airport_id"]], f"No qualifying runway for {m['source_airport_id']}"
        else:
            assert m["source_airport_id"] not in by_airport
    exc_count=Counter(r["country_iso"] for r in exceptions)
    assert not any(e["issue"]=="SOURCE_AIRPORT_ID_NOT_FOUND" for e in exceptions)
    assert not any(e["issue"]=="QUALIFYING_RUNWAY_NOT_RECONCILED" for e in exceptions)
    assert len(countries)==len(counted)
    for c in countries:
        iso=c["country_iso"]
        assert iso in counted
        for key,value in [
            ("airports", counted[iso]),
            ("with_coordinates", location_count[iso]),
            ("icao_source_reported", icao_count[iso]),
            ("iata_source_reported", iata_count[iso]),
            ("qualifying_runway_rows", runway_count[iso]),
            ("exceptions", exc_count[iso])]:
            assert int(c[key])==value, f"{iso} {key}"
    for r in reviews:
        assert r["passenger_permission"]=="UNKNOWN" and r["cargo_permission"]=="UNKNOWN"
        assert r["commercial_readiness"]=="NEEDS_REVIEW"
        assert r["curfew"]=="UNKNOWN" and r["noise_restrictions"]=="UNKNOWN"
        assert not r["game_passenger_demand_daily"] and not r["game_cargo_demand_tonnes_daily"]
    print(f"ENRICHMENT VALIDATED: {len(identity)} airports, {len(runways)} runways, {sum(location_count.values())} source geolocations, {len(pilot)} Serbia pilot records, {len(exceptions)} exceptions")

if __name__=="__main__":
    validate()
