"""Guard the worldwide military-name review against mistaken exclusions or dropped rows."""
import csv
import json
import unittest
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "data" / "airports"
REVIEW = BASE / "identity" / "military_use_review_queue.csv"
EVIDENCE = BASE / "identity" / "military_use_civilian_evidence.csv"
SUMMARY = BASE / "identity" / "military_use_screening_summary.json"

def load_csv(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        assert reader.fieldnames and len(reader.fieldnames) == len(set(reader.fieldnames))
        rows = list(reader)
    assert all(None not in row and all(value is not None for value in row.values()) for row in rows)
    return rows

class MilitaryWorldwideScreeningTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.master = load_csv(BASE / "airport_register.csv")
        cls.queue = load_csv(REVIEW)
        cls.evidence = load_csv(EVIDENCE)
        cls.verified = load_csv(BASE / "identity" / "verified_military_only.csv")
        cls.summary = json.loads(SUMMARY.read_text(encoding="utf-8"))

    def test_master_and_review_queue_are_distinct(self):
        self.assertEqual(8153, len(self.master))
        self.assertEqual(1, sum(m["source_type"] == "FICTIONAL" for m in self.master))
        all_ids = {m["source_airport_id"]: m for m in self.master}
        self.assertEqual(8153, len(all_ids))
        self.assertEqual(635, len(self.queue))
        queue_ids = [r["source_airport_id"] for r in self.queue]
        self.assertEqual(len(queue_ids), len(set(queue_ids)))
        self.assertNotIn("fictional:RS:LYAL", queue_ids)
        self.assertTrue(set(queue_ids).issubset(all_ids))
        for row in self.queue:
            source = all_ids[row["source_airport_id"]]
            self.assertEqual(source["country_iso"], row["country_iso"])
            self.assertEqual(source["ident"], row["source_ident"])
            self.assertEqual(source["airport_name"], row["airport_name"])
            self.assertEqual(source["gps_code"], row["gps_code"])

    def test_expanded_name_patterns_were_not_skipped(self):
        priorities = Counter(row["review_priority"] for row in self.queue)
        self.assertEqual({
            "P1_POSSIBLE_MIXED_USE": 11,
            "P2_SPECIALIZED_BASE": 32,
            "P3_BASE_NAME_ONLY": 486,
            "P4_EXPANDED_NAME_REVIEW": 106,
        }, dict(priorities))
        ids = {row["source_airport_id"] for row in self.queue}
        for identifier in ("2493", "2472", "2408", "26539", "27101", "26934", "2512"):
            self.assertIn(identifier, ids)

    def test_14_evidenced_civilian_cases_remain_non_operational(self):
        queue = {r["source_airport_id"]: r for r in self.queue}
        self.assertEqual(14, len(self.evidence))
        self.assertEqual(14, len({r["source_airport_id"] for r in self.evidence}))
        for row in self.evidence:
            identifier = row["source_airport_id"]
            self.assertIn(identifier, queue)
            self.assertEqual("NO", row["gameplay_activation_allowed"])
            self.assertEqual("2026-10-23", row["checked_date"])
            self.assertTrue(row["evidence_url"].startswith("https://"))
            self.assertTrue(row["source_organization"])
            self.assertTrue(row["research_note"])
            site = queue[identifier]
            self.assertEqual("NOT_ACTIVE_CIVILIAN_USE_EVIDENCED", site["gameplay_decision"])
            self.assertEqual(row["civilian_evidence_class"], site["civilian_commercial_status"])
            self.assertEqual(row["evidence_url"], site["evidence_url"])
        for row in self.queue:
            self.assertTrue(row["gameplay_decision"].startswith("NOT_ACTIVE_"))
            self.assertNotEqual("MILITARY_ONLY_CONFIRMED", row["military_only_verified"])

    def test_verified_military_only_needs_separate_primary_evidence(self):
        queue = {r["source_airport_id"]: r for r in self.queue}
        evidence_ids = {r["source_airport_id"] for r in self.evidence}
        for row in self.verified:
            identifier = row["source_airport_id"]
            self.assertNotIn(identifier, evidence_ids)
            self.assertEqual("MILITARY_ONLY_CONFIRMED", row["verified_status"])
            self.assertTrue(row["evidence_url"].startswith("https://"))
            self.assertTrue(row["evidence_date"])
            self.assertIn(identifier, {r["source_airport_id"] for r in self.master})
            self.assertNotEqual("NOT_ACTIVE_CIVILIAN_USE_EVIDENCED", queue.get(identifier, {}).get("gameplay_decision"))

    def test_reconciled_summary(self):
        self.assertEqual(635, self.summary["total_name_screen_candidates"])
        self.assertEqual(len(self.evidence), self.summary["civilian_evidence_confirmed"])
        self.assertEqual(len(self.verified), self.summary["confirmed_military_only_exclusions"])
        self.assertEqual(635 - len(self.evidence), self.summary["still_need_individual_official_evidence"])
        self.assertEqual(99, len({r["country_iso"] for r in self.queue}))
        self.assertIs(False, self.summary["gameplay_activation_performed"])
        self.assertIs(True, self.summary["not_yet_a_complete_verified_worldwide_military_only_inventory"])

if __name__ == "__main__":
    unittest.main()
