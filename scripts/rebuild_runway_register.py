#!/usr/bin/env python3
"""Rebuild runway-only master from all screened groups PLUS durable fictional airport definitions.

Do not replace older groups or discard fictional designs on a group refresh.
Final six-tier classification remains blank for source-screened airports.
"""
from __future__ import annotations
import argparse
import csv
import pathlib
from collections import defaultdict
from airport_surface import surface_type

ROOT=pathlib.Path(__file__).resolve().parents[1]
GENERATED=ROOT/"data/airports/generated"
REGISTER=ROOT/"data/airports/airport_register.csv"
FICTIONAL=ROOT/"data/airports/fictional_airports.csv"
CODE_CONFLICTS=ROOT/"data/airports/airport_code_conflicts.csv"
COLUMNS=("source_airport_id","country_iso","airport_name","ident","gps_code",
         "runway_length_m","runway_surface","minimum_eligible_level",
         "runway_status","source_type","assigned_category")
CATEGORIES={"Local","Regional","Medium","Large","Major Hub","Mega Hub"}
CONFLICT_COLUMNS=("country_iso","airport_code","source_airport_ids","airport_names","status")

def code_conflicts(records):
    """Record shared raw-source airport codes without discarding runway-qualified airports."""
    codes=defaultdict(list)
    for row in records:
        code=(row["gps_code"] or row["ident"]).strip()
        if code:
            codes[(row["country_iso"],code)].append(row)
    result=[]
    for (country,code),items in sorted(codes.items()):
        if len(items)<=1: continue
        if any(item["source_type"]!="OURAIRPORTS" for item in items):
            raise ValueError(f"Airport code collision with fictional record: {country}/{code}")
        items=sorted(items,key=lambda r:r["source_airport_id"])
        result.append({"country_iso":country,"airport_code":code,
                       "source_airport_ids":";".join(r["source_airport_id"] for r in items),
                       "airport_names":";".join(r["airport_name"] for r in items),
                       "status":"SOURCE_CODE_CONFLICT_REVIEW"})
    return result


def sources():
    paths=sorted(GENERATED.glob("group*/group*_technical_candidates.csv"))
    if not paths: raise ValueError("No group screens found; refusing to erase master")
    return paths

def build(target: pathlib.Path=REGISTER)->int:
    records=[]
    ids=set()
    codes=set()
    countries={}
    screens=sources()
    for path in screens:
        group=path.parent.name
        with path.open(newline="",encoding="utf-8-sig") as f:
            group_rows=list(csv.DictReader(f))
        if not group_rows:
            if group != "group49":
                raise ValueError(f"Screen unexpectedly empty: {group}")
            counts_path=path.parent/"group49_country_counts.csv"
            with counts_path.open(newline="",encoding="utf-8-sig") as counts_file:
                count_rows=list(csv.DictReader(counts_file))
            if len(count_rows)!=2 or {x["country_iso"] for x in count_rows}!={"AQ","TOTAL"} or any(x["technical_candidates"]!="0" for x in count_rows):
                raise ValueError("Group 49 requires AQ/TOTAL zero-count evidence")
            continue
        for row in group_rows:
            airport_id=row["ourairports_id"].strip()
            country=row["iso_country"].strip()
            name=row["airport_name"].strip()
            code=(row.get("gps_code") or row.get("ident") or "").strip()
            length=float(row["longest_reported_eligible_runway_m"])
            if not airport_id.isdigit() or not country or not name or length<1200:
                raise ValueError(f"Invalid runway row {airport_id} in {group}")
            if surface_type(row["surface"].strip().strip(chr(39)+chr(34)))!="ELIGIBLE_LABEL":
                raise ValueError(f"Invalid paved surface in {group}: {airport_id}")
            if airport_id in ids: raise ValueError(f"Duplicate source airport ID: {airport_id}")
            ids.add(airport_id)
            # Duplicate raw airport codes are recorded for future manual verification,
            # not used to reject independently runway-qualified source airports.
            if code: codes.add((country,code))
            if country in countries and countries[country]!=group:
                raise ValueError(f"Country appears in multiple screening groups: {country}")
            countries[country]=group
            records.append({"source_airport_id":airport_id,"country_iso":country,
                            "airport_name":name,"ident":row.get("ident",""),
                            "gps_code":row.get("gps_code",""),
                            "runway_length_m":row["longest_reported_eligible_runway_m"],
                            "runway_surface":row["surface"],"minimum_eligible_level":"1",
                            "runway_status":"RUNWAY_QUALIFIED",
                            "source_type":"OURAIRPORTS","assigned_category":""})
    with FICTIONAL.open(newline="",encoding="utf-8-sig") as f:
        reader=csv.DictReader(f)
        if set(reader.fieldnames or []) != set(COLUMNS):
            raise ValueError("Fictional overlay header must exactly match master fields")
        custom=list(reader)
    if not custom: raise ValueError("Fictional overlay unexpectedly empty")
    for row in custom:
        ident=row["source_airport_id"]
        country=row["country_iso"]
        code=(row["gps_code"] or row["ident"]).strip()
        if row["source_type"]!="FICTIONAL" or not ident.startswith("fictional:"):
            raise ValueError("Invalid fictional source ID/type")
        if ident in ids: raise ValueError(f"Duplicate custom ID {ident}")
        ids.add(ident)
        if code:
            if (country,code) in codes: raise ValueError(f"Fictional/real airport code collision {country}/{code}")
            codes.add((country,code))
        if len(country)!=2 or not row["airport_name"].strip():
            raise ValueError(f"Missing fictional country/name: {ident}")
        if float(row["runway_length_m"])<1200 or surface_type(row["runway_surface"].strip().strip(chr(39)+chr(34)))!="ELIGIBLE_LABEL":
            raise ValueError(f"Fictional airport fails Level-1 runway test: {ident}")
        if row["minimum_eligible_level"]!="1" or row["runway_status"]!="RUNWAY_QUALIFIED":
            raise ValueError(f"Fictional airport missing runway status: {ident}")
        if row["assigned_category"] not in CATEGORIES:
            raise ValueError(f"Fictional airport category must use the exact six-tier system: {ident}")
        records.append(dict(row))
    # Retain the historic real-airport order; custom airports join by country/name.
    records.sort(key=lambda row:(row["country_iso"],row["airport_name"],
                 (0,int(row["source_airport_id"])) if row["source_airport_id"].isdigit()
                 else (1,row["source_airport_id"])))
    conflicts=code_conflicts(records)
    CODE_CONFLICTS.parent.mkdir(parents=True,exist_ok=True)
    with CODE_CONFLICTS.open("w",newline="",encoding="utf-8") as f:
        writer=csv.DictWriter(f,fieldnames=CONFLICT_COLUMNS)
        writer.writeheader()
        writer.writerows(conflicts)
    target.parent.mkdir(parents=True,exist_ok=True)
    with target.open("w",newline="",encoding="utf-8") as f:
        # The committed airport_register.csv uses LF. Python csv defaults to CRLF,
        # which makes a no-op rebuild appear to replace all 8,152 airport rows.
        # Keep airport_code_conflicts.csv on its existing CRLF convention.
        writer=csv.DictWriter(f,fieldnames=COLUMNS,lineterminator="\n")
        writer.writeheader()
        writer.writerows(records)
    print(f"MASTER: {len(records)} airports; {len(records)-len(custom)} screened, {len(custom)} fictional; {len(screens)} groups; {len(conflicts)} source-code conflicts for review")
    return len(records)

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--out",type=pathlib.Path,default=REGISTER)
    args=p.parse_args()
    build(args.out)
