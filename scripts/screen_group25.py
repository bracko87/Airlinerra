#!/usr/bin/env python3
"""Reproducible technical runway screening for Airlinerra Group 25.
Does not certify civilian access, aircraft eligibility or six-class ranking.
Requires downloaded OurAirports airports.csv and runways.csv.
"""
import argparse
import collections
import csv
import datetime
import hashlib
import pathlib
import re

COUNTRIES={"VU":"Vanuatu","AS":"American Samoa","CK":"Cook Islands","PF":"French Polynesia","GU":"Guam","NC":"New Caledonia","NU":"Niue","NF":"Norfolk Island","MP":"Northern Mariana Islands","PN":"Pitcairn Islands","TK":"Tokelau","WF":"Wallis and Futuna","UM":"United States Minor Outlying Islands"}
# Group 25 completes the separately coded Oceania jurisdictions, preserving all source ISO areas, including zero matches.

PAVEMENT={"ASP","ASPH","ASPHALT","ASPHALTE","ASPHALTED","ASPHALTCONCRETE","CON","CONC","CONCRETE","BETON","BITUMEN","ASP/CON","CON/ASP","ASPH/CONC","CONC/ASPH","ASPHALT/CONCRETE","CONCRETE/ASPHALT","ASP-CON","CON-ASP"}
UNCERTAIN=("PAVED","ASPH","CON","TARMAC","MACADAM","BITUM","TAR","HARD")

def surface_type(value):
    val=re.sub(r"\s+","",(value or "").strip().strip(chr(39)+chr(34)).upper())
    if val in PAVEMENT: return "ELIGIBLE_LABEL"
    if re.search(r"[/+;&-]",val):
        bits=re.split(r"[/+;&-]",val)
        if all(v in PAVEMENT for v in bits): return "ELIGIBLE_LABEL"
    if any(v in val for v in UNCERTAIN): return "CHECK_SURFACE"
    return "NOT_PAVED"

def load(path):
    with open(path,encoding="utf-8-sig",newline="") as handle:
        return list(csv.DictReader(handle))

def write(path, columns, records):
    path.parent.mkdir(parents=True,exist_ok=True)
    with open(path,"w",encoding="utf-8",newline="") as handle:
        writer=csv.DictWriter(handle,fieldnames=columns,extrasaction="ignore")
        writer.writeheader()
        writer.writerows(records)

def sha256(path):
    h=hashlib.sha256()
    with open(path,"rb") as handle:
        for chunk in iter(lambda: handle.read(1024*1024),b""): h.update(chunk)
    return h.hexdigest()

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--airports",required=True,type=pathlib.Path)
    p.add_argument("--runways",required=True,type=pathlib.Path)
    p.add_argument("--out",required=True,type=pathlib.Path)
    args=p.parse_args()
    airports={r["id"]:r for r in load(args.airports) if r.get("iso_country") in COUNTRIES and r.get("type")!="closed"}
    eligible=collections.defaultdict(list)
    uncertain=collections.defaultdict(list)
    for runway in load(args.runways):
        airport=airports.get(runway.get("airport_ref",""))
        if airport is None or runway.get("closed","").strip().lower() in ("1","true","yes"):
            continue
        try: length=float(runway.get("length_ft") or 0)*0.3048
        except ValueError: continue
        if length < 1200: continue
        kind=surface_type(runway.get("surface"))
        if kind=="ELIGIBLE_LABEL": eligible[airport["id"]].append((length,runway))
        elif kind=="CHECK_SURFACE": uncertain[airport["id"]].append((length,runway))
    approved_columns=["ourairports_id","iso_country","airport_name","ident","gps_code","longest_reported_eligible_runway_m","surface","eligible_runway_count","runway_ids"]
    candidates=[]
    for ident,matches in eligible.items():
        a=airports[ident]
        length,r=max(matches,key=lambda p:p[0])
        candidates.append({"ourairports_id":ident,"iso_country":a["iso_country"],"airport_name":a.get("name",""),"ident":a.get("ident",""),"gps_code":a.get("gps_code",""),"longest_reported_eligible_runway_m":round(length,1),"surface":r.get("surface",""),"eligible_runway_count":len(matches),"runway_ids":";".join(sorted((x.get("id","") for _,x in matches)))})
    candidates.sort(key=lambda a:(a["iso_country"],a["airport_name"],a["ourairports_id"]))
    args.out.mkdir(parents=True,exist_ok=True)
    write(args.out/"group25_technical_candidates.csv",approved_columns,candidates)
    surface_queue=[]
    for ident,matches in uncertain.items():
        if ident in eligible:continue
        a=airports[ident];length,r=max(matches,key=lambda p:p[0])
        surface_queue.append({"ourairports_id":ident,"iso_country":a["iso_country"],"airport_name":a.get("name",""),"ident":a.get("ident",""),"longest_runway_m":round(length,1),"reported_surface":r.get("surface",""),"decision":"SURFACE_VERIFICATION_REQUIRED"})
    surface_queue.sort(key=lambda a:(a["iso_country"],a["airport_name"]))
    write(args.out/"group25_surface_review.csv",["ourairports_id","iso_country","airport_name","ident","longest_runway_m","reported_surface","decision"],surface_queue)
    counts=collections.Counter(x["iso_country"] for x in candidates)
    countrows=[{"country_iso":code,"country":name,"technical_candidates":counts[code],"minimum_eligible_level":"1"} for code,name in COUNTRIES.items()]
    countrows.append({"country_iso":"TOTAL","country":"TOTAL","technical_candidates":len(candidates),"minimum_eligible_level":"1"})
    write(args.out/"group25_country_counts.csv",["country_iso","country","technical_candidates","minimum_eligible_level"],countrows)
    duplicates=[]
    for key in ("ident","gps_code"):
        seen=collections.defaultdict(list)
        for row in candidates:
            if row[key]:seen[(row["iso_country"],row[key])].append(row)
        for (_,code),values in seen.items():
            if len(values)>1:
                duplicates.append({"field":key,"value":code,"airport_ids":";".join(x["ourairports_id"] for x in values),"count":len(values)})
    write(args.out/"group25_duplicate_identifiers.csv",["field","value","airport_ids","count"],duplicates)
    (args.out/"SOURCE.txt").write_text(
        "Airlinerra Group 25 TECHNICAL SCREEN; never auto-import to gameplay.\n"
        "UTC generated: "+datetime.datetime.now(datetime.timezone.utc).isoformat()+"\n"
        "Original source: https://github.com/davidmegginson/ourairports-data\n"
        "airports.csv SHA256: "+sha256(args.airports)+"\n"
        "runways.csv SHA256: "+sha256(args.runways)+"\n"
        "Only operational and explicitly asphalt/concrete runway labels >=1200 m.\n"
        "Excluded airport.type=closed and runway.closed=1.\n"
        "Group 25 screens Vanuatu and twelve remaining Pacific island jurisdictions, including separately coded territories, by OurAirports geographic code; no cross-group duplicates.\n"
        "Explicit asphalt concrete is qualifying surfacing; unverified plain paved/hard is still excluded.\n"
        "Current phase ends at runway qualification for minimum Level 1 (Local). Other airport information and final six-category ranking are DEFERRED.\n"
        "Records are qualified by runway only; not an operating-airport or game-activation authorization.\n"
        f"Screened count: {len(candidates)}; ambiguous surface queue: {len(surface_queue)}; duplicate identifiers: {len(duplicates)}.\n",encoding="utf-8")
    print("TECHNICAL SCREEN: "+str(len(candidates))+" airports; per-country "+str(dict(counts))+"; uncertain surface "+str(len(surface_queue)))

if __name__=="__main__":
    main()
