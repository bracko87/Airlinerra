#!/usr/bin/env python3
"""Validate a commercial group review against its immutable runway-only source group."""
import argparse
import csv
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
COLS=("source_airport_id","country_iso","airport_name","source_ident","passenger_commercial_permission","cargo_commercial_permission","review_classification","passenger_evidence_url","cargo_evidence_url","access_evidence_url","verification_as_of","review_notes")
ACCEPT={"YES","NO","UNKNOWN"}
KINDS={"PASSENGER_AND_CARGO_EVIDENCED","PASSENGER_EVIDENCED_CARGO_UNKNOWN","CARGO_EVIDENCED_PASSENGER_UNKNOWN","PASSENGER_AND_FREIGHT_ELIGIBLE","PUBLIC_AIRPORT_SERVICE_UNVERIFIED","MILITARY_ACCESS_REVIEW","MILITARY_PRIOR_PERMISSION_REQUIRED","AIRPORT_CODE_AND_ACCESS_REVIEW","NEEDS_REVIEW"}
COUNT_COLS=("country_iso","country_name","runway_qualified_candidates","passenger_evidenced","cargo_eligible_evidenced","military_review","other_unknown_both","public_airport_service_unverified")
def read(path):
    with open(path,newline="",encoding="utf-8-sig") as f:
        reader=csv.DictReader(f)
        if not reader.fieldnames or len(set(reader.fieldnames))!=len(reader.fieldnames): raise ValueError("Bad CSV headers: "+str(path))
        data=list(reader)
        if any(None in x for x in data): raise ValueError("Malformed CSV: "+str(path))
        return reader.fieldnames,data
def validate(group):
    original=ROOT/f"data/airports/generated/group{group}/group{group}_technical_candidates.csv"
    base=ROOT/f"data/airports/commercial/group{group}"
    _,source=read(original)
    cols,rows=read(base/f"group{group}_commercial_review.csv")
    if tuple(cols)!=COLS: raise ValueError("Invalid review columns")
    by_id={r["ourairports_id"]:r for r in source}
    if not rows or len(by_id)!=len(source) or len(rows)!=len(source): raise ValueError("Missing or duplicate review/source records")
    ids=set()
    totals={}
    for item in rows:
        ident=item["source_airport_id"]
        if ident in ids or ident not in by_id: raise ValueError("Unexpected/repeated source ID "+ident)
        ids.add(ident)
        original=by_id[ident]
        if (item["country_iso"],item["airport_name"],item["source_ident"])!=(original["iso_country"],original["airport_name"],original["ident"]): raise ValueError("Source identity mismatch: "+ident)
        p,c=item["passenger_commercial_permission"],item["cargo_commercial_permission"]
        if p not in ACCEPT or c not in ACCEPT or item["review_classification"] not in KINDS: raise ValueError("Invalid status at "+ident)
        if p=="YES" and not item["passenger_evidence_url"].startswith("https://"): raise ValueError("Uncited passenger YES: "+ident)
        if c=="YES" and not item["cargo_evidence_url"].startswith("https://"): raise ValueError("Uncited cargo YES: "+ident)
        if not item["review_notes"].strip() or not item["verification_as_of"].strip(): raise ValueError("Missing review date/notes "+ident)
        if p=="NO" or c=="NO": raise ValueError("Group reviews cannot infer negative permission without bespoke negative-evidence field: "+ident)
        status=item["review_classification"]
        if status.startswith("MILITARY") and (p=="YES" or c=="YES"): raise ValueError("Contradictory military review: "+ident)
        arr=totals.setdefault(item["country_iso"],[0,0,0,0,0,0])
        arr[0]+=1
        arr[1]+=int(p=="YES")
        arr[2]+=int(c=="YES")
        arr[3]+=int("MILITARY" in status)
        arr[4]+=int(p=="UNKNOWN" and c=="UNKNOWN")
        arr[5]+=int(status=="PUBLIC_AIRPORT_SERVICE_UNVERIFIED")
    cols,rollups=read(base/f"group{group}_country_counts.csv")
    if tuple(cols)!=COUNT_COLS or len(rollups)!=len(totals)+1: raise ValueError("Incorrect country rollup")
    for row in rollups:
        code=row["country_iso"]
        expected=[sum(values[i] for values in totals.values()) for i in range(6)] if code=="TOTAL" else totals.get(code)
        if expected is None or [int(row[x]) for x in COUNT_COLS[2:]]!=expected: raise ValueError("Incorrect country totals for "+code)
    if {r["country_iso"] for r in rollups}!={*totals,"TOTAL"}: raise ValueError("Missing country codes")
    print(f"PASS: group {group}, {len(rows)} airport source IDs verified; {sum(x[1] for x in totals.values())} passenger; {sum(x[2] for x in totals.values())} cargo evidence; {sum(x[4] for x in totals.values())} both unknown")
if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--group",required=True,type=int)
    validate(p.parse_args().group)
