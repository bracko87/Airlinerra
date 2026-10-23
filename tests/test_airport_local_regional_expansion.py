"""Validate reversible second-pass Local/Regional candidates; never certify operations."""
import csv
import json
import re
import unittest
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AIRPORTS = ROOT / "data" / "airports"
EXP = AIRPORTS / "local_regional_expansion"
START = AIRPORTS / "startup"

MILITARY = re.compile(
    r"\b(?:air\s*force(?:\s*base)?|airbase|air\s*base|naval|army|military|"
    r"afb|raf|air\s*station|marine corps|milit[aä]r|flight test|missile|"
    r"bombing range|training base)\b", re.I
)
SPECIAL = re.compile(
    r"\b(?:skydive|skydiving|drop\s*zone|private|ranch|farm|farmstrip|"
    r"industrial|oilfield|oil\s*field|heliport|helipad|helistop|"
    r"helicopter|mine|mining|gliding|glider|aeroclub|aero\s*club|"
    r"flying club|test\s*range|test\s*track|plant|strip|closed|"
    r"abandon|research\s*station|sky\s*park)\b", re.I
)

def rows(path):
    with path.open(encoding="utf-8-sig", newline="") as handle:
        result = list(csv.DictReader(handle))
    if any(None in r or any(v is None for v in r.values()) for r in result):
        raise ValueError("Malformed CSV: " + str(path))
    return result

class LocalRegionalExpansionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.master = rows(AIRPORTS / "airport_register.csv")
        cls.identity = rows(AIRPORTS / "identity" / "airport_identity_worldwide.csv")
        cls.startup = rows(START / "airports_3140.csv")
        cls.military = rows(AIRPORTS / "identity" / "military_use_review_queue.csv")
        cls.civilian = rows(AIRPORTS / "identity" / "military_use_civilian_evidence.csv")
        cls.screen = rows(EXP / "screened_5012.csv")
        cls.candidates = rows(EXP / "candidates_local_regional.csv")
        cls.holds = rows(EXP / "review_holds.csv")
        cls.countries = rows(EXP / "country_summary.csv")
        cls.summary = json.loads((EXP / "summary.json").read_text(encoding="utf-8"))
        cls.mil_ids = {p["source_airport_id"] for p in cls.military}
        cls.evid = {p["source_airport_id"]: p for p in cls.civilian}

    def test_all_real_airports_partition_without_master_mutation(self):
        self.assertEqual(8153, len(self.master))
        self.assertEqual(8153, len(self.identity))
        self.assertEqual(3140, len(self.startup))
        self.assertEqual(5012, len(self.screen))
        master_by_id = {x["source_airport_id"]: x for x in self.master}
        identity_by_id = {x["source_airport_id"]: x for x in self.identity}
        startup_ids = {x["source_airport_id"] for x in self.startup}
        second_ids = {x["source_airport_id"] for x in self.screen}
        self.assertEqual(len(self.master), len(master_by_id))
        self.assertEqual(len(self.identity), len(identity_by_id))
        self.assertEqual(3140, len(startup_ids))
        self.assertEqual(5012, len(second_ids))
        self.assertFalse(startup_ids & second_ids)
        self.assertNotIn("fictional:RS:LYAL", startup_ids | second_ids)
        real_ids = {m["source_airport_id"] for m in self.master
                    if m["source_type"] == "OURAIRPORTS"}
        self.assertEqual(real_ids, startup_ids | second_ids)
        for r in self.screen:
            m = master_by_id[r["source_airport_id"]]
            identity = identity_by_id[r["source_airport_id"]]
            self.assertEqual("OURAIRPORTS", m["source_type"])
            self.assertEqual("no", identity["scheduled_service_source"])
            self.assertEqual("no", r["scheduled_service_source"])
            self.assertEqual("RUNWAY_QUALIFIED", m["runway_status"])
            self.assertEqual("1", m["minimum_eligible_level"])
            self.assertEqual("", m["assigned_category"])
            self.assertEqual(m["runway_length_m"], r["runway_length_m"])
            self.assertEqual(m["runway_surface"], r["runway_surface"])
            self.assertEqual(identity["airport_type_source"], r["source_type"])
            self.assertEqual(identity["latitude_deg"], r["latitude_deg"])
            self.assertEqual(identity["longitude_deg"], r["longitude_deg"])
            self.assertEqual(identity["icao_code"], r["icao_code"])
            self.assertEqual(identity["iata_code"], r["iata_code"])
            self.assertEqual("UNVERIFIED", r["commercial_approval"])
            self.assertEqual("NOT_ACTIVE", r["gameplay_status"])

    def test_exact_review_decisions_and_reversible_tiers(self):
        selected = {}
        status = Counter()
        tiers = Counter()
        held = {}
        for r in self.screen:
            length = float(r["runway_length_m"])
            small = r["source_type"] == "small_airport"
            medium = r["source_type"] == "medium_airport"
            proposed = ("Local" if small and length < 1800 else
                        "Regional" if (small and length < 3000) or
                        (medium and length < 2400) else "")
            self.assertEqual(proposed, r["proposed_category"])
            name = r["airport_name"]
            military = r["source_airport_id"] in self.mil_ids or bool(MILITARY.search(name))
            specialized = bool(SPECIAL.search(name))
            civilian = r["source_airport_id"] in self.evid
            expected = (
                "OUTSIDE_TECHNICAL_SCOPE" if not proposed else
                "HOLD_MILITARY_ACCESS" if military and not civilian else
                "HOLD_SPECIALIZED_USE" if specialized and not civilian else
                "CIVILIAN_EVIDENCE_REVIEW" if civilian else
                "CIVILIAN_PERMISSION_REVIEW"
            )
            self.assertEqual(expected, r["review_status"])
            status[expected] += 1
            if expected.startswith("HOLD_"):
                held[r["source_airport_id"]] = r
            if expected in ("CIVILIAN_EVIDENCE_REVIEW", "CIVILIAN_PERMISSION_REVIEW"):
                selected[r["source_airport_id"]] = r
                tiers[proposed] += 1
        self.assertEqual(
            {"OUTSIDE_TECHNICAL_SCOPE": 693, "HOLD_MILITARY_ACCESS": 266,
             "HOLD_SPECIALIZED_USE": 147, "CIVILIAN_PERMISSION_REVIEW": 3904,
             "CIVILIAN_EVIDENCE_REVIEW": 2},
            dict(status))
        self.assertEqual({"Local": 2447, "Regional": 1459}, dict(tiers))
        self.assertEqual(3906, len(self.candidates))
        self.assertEqual(413, len(self.holds))
        self.assertEqual(set(selected),
                         {r["source_airport_id"] for r in self.candidates})
        self.assertEqual(set(held),
                         {r["source_airport_id"] for r in self.holds})
        for r in self.candidates:
            p = selected[r["source_airport_id"]]
            for field in ("airport_name", "country_iso", "proposed_category",
                          "review_status", "runway_length_m", "runway_surface",
                          "civilian_evidence_url"):
                self.assertEqual(p[field], r[field])
            self.assertEqual("UNVERIFIED", r["commercial_approval"])
            self.assertEqual("NOT_ACTIVE", r["gameplay_status"])
        for r in self.holds:
            self.assertIn(r["review_status"],
                          ("HOLD_MILITARY_ACCESS", "HOLD_SPECIALIZED_USE"))

    def test_country_summary_and_higher_category_preservation(self):
        by_country = defaultdict(Counter)
        for r in self.screen:
            c = by_country[r["country_iso"]]
            c["screened_unscheduled"] += 1
            status = r["review_status"]
            if status in ("CIVILIAN_PERMISSION_REVIEW", "CIVILIAN_EVIDENCE_REVIEW"):
                c["local_candidates" if r["proposed_category"] == "Local"
                  else "regional_candidates"] += 1
            elif status == "HOLD_MILITARY_ACCESS":
                c["military_holds"] += 1
            elif status == "HOLD_SPECIALIZED_USE":
                c["specialized_holds"] += 1
            else:
                c["outside_scope"] += 1
        self.assertEqual(len(by_country), len(self.countries))
        for r in self.countries:
            c = by_country[r["country_iso"]]
            for field in ("screened_unscheduled", "local_candidates",
                          "regional_candidates", "military_holds",
                          "specialized_holds", "outside_scope"):
                self.assertEqual(c[field], int(r[field]), (r["country_iso"], field))
        counts = Counter(r["proposed_category"] for r in self.startup)
        self.assertEqual(
            {"Local": 104, "Regional": 103, "Medium": 1752, "Large": 906,
             "Major Hub": 205, "Mega Hub": 70},
            dict(counts))
        self.assertEqual(2551, self.summary["combined_local_provisional"])
        self.assertEqual(1562, self.summary["combined_regional_provisional"])
        self.assertEqual(4113, self.summary["combined_local_regional_provisional"])
        self.assertTrue(self.summary["original_3140_shortlist_unchanged"])
        self.assertTrue(self.summary["initial_medium_large_major_mega_unchanged"])
        self.assertFalse(self.summary["commercial_operation_approved"])
        self.assertFalse(self.summary["production_or_supabase_activation"])
        self.assertFalse(self.summary["owner_approval_of_game_categories"])

if __name__ == "__main__":
    unittest.main()
