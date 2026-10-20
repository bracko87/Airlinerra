#!/usr/bin/env python3
"""Rebuild runway-only master from all screened groups PLUS durable fictional airport definitions.

Do not replace older groups or discard fictional designs on a group refresh.
Final six-tier classification remains blank for source-screened airports.
"""
from __future__ import annotations
import argparse
import csv
import pathlib
from screen_group4 import surface_type

ROOT=pathlib.Path(__file__).resolve().parents[1]
GENERATED=ROOT/"data/airports/generated"
REGISTER=ROOT/"data/airports/airport_register.csv"
FICTIONAL=ROOT/"data/airports/fictional_airports.csv"
COLUMNS=("source_airport_id","country_iso","airport_name","ident","gps_code",
         "runway_length_m","runway_surface","minimum_eligible_level",
         "runway_status","source_type","assigned_category")
CATEGORIES={"Local","Regional","Medium","Large","Major Hub","Mega Hub"}

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
        if not group_rows: raise ValueError(f"Screen unexpectedly empty: {group}")
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
            if code:
                if (country,code) in codes: raise ValueError(f"Duplicate airport code: {country}/{code}")
                codes.add((country,code))
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
    target.parent.mkdir(parents=True,exist_ok=True)
    with target.open("w",newline="",encoding="utf-8") as f:
        writer=csv.DictWriter(f,fieldnames=COLUMNS)
        writer.writeheader()
        writer.writerows(records)
    print(f"MASTER: {len(records)} airports; {len(records)-len(custom)} screened, {len(custom)} fictional; {len(screens)} groups")
    return len(records)

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--out",type=pathlib.Path,default=REGISTER)
    args=p.parse_args()
    build(args.out)
