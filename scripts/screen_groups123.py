#!/usr/bin/env python3
"""Backfill Airlinerra Groups 1, 2, 3 by the CURRENT runway-only rule.

Reuses Group 4's exact paving classification and conversion logic.
This screens every country in each group, not just prior historical selections.
It does not decide final category, civilian status, or gameplay activation.
"""
import argparse
import collections
import datetime
import pathlib

from screen_group4 import load, surface_type, write, sha256

GROUPS = {
    "1": {"AL":"Albania","AM":"Armenia","AT":"Austria","AZ":"Azerbaijan"},
    "2": {"BY":"Belarus","BE":"Belgium","BA":"Bosnia and Herzegovina","BG":"Bulgaria","HR":"Croatia"},
    "3": {"CY":"Cyprus","CZ":"Czechia","DK":"Denmark","EE":"Estonia","FI":"Finland"},
}
SOURCE_COLS=("ourairports_id","iso_country","airport_name","ident","gps_code",
             "longest_reported_eligible_runway_m","surface","eligible_runway_count","runway_ids")

def build(airports_file, runways_file, base):
    airports=load(airports_file)
    runways=load(runways_file)
    by_id={row["id"]: row for row in airports if row.get("type")!="closed"}
    groups={code:g for g,countries in GROUPS.items() for code in countries}
    eligible=collections.defaultdict(list)
    ambiguous=collections.defaultdict(list)
    for runway in runways:
        a=by_id.get(runway.get("airport_ref",""))
        if not a or a.get("iso_country") not in groups:
            continue
        if runway.get("closed","").lower().strip() in ("true","1","yes"):
            continue
        try: length=float(runway.get("length_ft") or 0)*0.3048
        except ValueError: continue
        if length<1200: continue
        kind=surface_type(runway.get("surface",""))
        if kind=="ELIGIBLE_LABEL": eligible[a["id"]].append((length,runway))
        elif kind=="CHECK_SURFACE": ambiguous[a["id"]].append((length,runway))
    for group,countries in GROUPS.items():
        folder=base/("group"+group)
        screened=[]
        uncert=[]
        for ident,matches in eligible.items():
            a=by_id[ident]
            if a["iso_country"] not in countries: continue
            length,r=max(matches,key=lambda x:x[0])
            screened.append({
                "ourairports_id":ident, "iso_country":a["iso_country"],
                "airport_name":a.get("name",""), "ident":a.get("ident",""),
                "gps_code":a.get("gps_code",""),
                "longest_reported_eligible_runway_m":round(length,1),
                "surface":r.get("surface",""),"eligible_runway_count":len(matches),
                "runway_ids":";".join(sorted(str(x.get("id","")) for _,x in matches)),
            })
        for ident,matches in ambiguous.items():
            if ident in eligible:continue
            a=by_id[ident]
            if a["iso_country"] not in countries:continue
            length,r=max(matches,key=lambda x:x[0])
            uncert.append({"ourairports_id":ident,"iso_country":a["iso_country"],
                           "airport_name":a.get("name",""),"ident":a.get("ident",""),
                           "longest_runway_m":round(length,1),
                           "reported_surface":r.get("surface",""),
                           "decision":"SURFACE_VERIFICATION_REQUIRED"})
        screened.sort(key=lambda x:(x["iso_country"],x["airport_name"],int(x["ourairports_id"])))
        uncert.sort(key=lambda x:(x["iso_country"],x["airport_name"]))
        write(folder/f"group{group}_technical_candidates.csv", SOURCE_COLS, screened)
        write(folder/f"group{group}_surface_review.csv",
              ("ourairports_id","iso_country","airport_name","ident","longest_runway_m","reported_surface","decision"),
              uncert)
        counts=collections.Counter(x["iso_country"] for x in screened)
        lines=[{"country_iso":code,"country":name,"technical_candidates":counts[code],
                "minimum_eligible_level":"1"} for code,name in countries.items()]
        lines.append({"country_iso":"TOTAL","country":"TOTAL",
                      "technical_candidates":len(screened),"minimum_eligible_level":"1"})
        write(folder/f"group{group}_country_counts.csv",
              ("country_iso","country","technical_candidates","minimum_eligible_level"),lines)
        folder.mkdir(parents=True,exist_ok=True)
        (folder/"SOURCE.txt").write_text(
            f"Group {group} RUNWAY-ONLY screen. This is NOT the historically approved airport list.\n"
            f"Generated at {datetime.datetime.now(datetime.timezone.utc).isoformat()}\n"
            "Source: https://github.com/davidmegginson/ourairports-data\n"
            f"airports.csv SHA256: {sha256(airports_file)}\n"
            f"runways.csv SHA256: {sha256(runways_file)}\n"
            "Rule: open runway >=1200m; asphalt/concrete surface; not airport.type=closed.\n"
            "Minimum eligible level=1; final category and other data deferred.\n"
            f"Result {len(screened)} airports; surface-review queue {len(uncert)}.\n",
            encoding="utf-8")
        print(f"Group {group}: {len(screened)} minimum-Level-1 technical airports; by country {dict(counts)}; surface reviews {len(uncert)}")

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--airports",type=pathlib.Path,required=True)
    parser.add_argument("--runways",type=pathlib.Path,required=True)
    parser.add_argument("--out",type=pathlib.Path,default=pathlib.Path("data/airports/generated"))
    args=parser.parse_args()
    build(args.airports,args.runways,args.out)
