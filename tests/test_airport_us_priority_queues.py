"""Research-only conservation checks across US physical, discrepancy and operator queues."""
import csv
import json
import unittest
from pathlib import Path

BASE = Path(__file__).resolve().parents[1] / "data/airports/local_regional_expansion/us_verification"


def load(name):
    with (BASE/name).open(newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
    if any(None in r or any(v is None for v in r.values()) for r in rows):
        raise ValueError("Invalid CSV: " + name)
    return rows


class USPriorityQueuesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.full = load("us_commercial_suitability_2077.csv")
        cls.issues = load("us_targeted_followup_queue.csv")
        cls.operator = load("us_operator_permission_review_1889.csv")
        cls.summary = json.loads((BASE/"us_next_stage_summary.json").read_text(encoding="utf-8"))

    def test_partition_exact_and_unique(self):
        allids = {r["source_airport_id"] for r in self.full}
        issueids = {r["source_airport_id"] for r in self.issues}
        cleanids = {r["source_airport_id"] for r in self.operator}
        self.assertEqual((2077, 188, 1889), (len(self.full), len(self.issues), len(self.operator)))
        self.assertEqual((2077, 188, 1889), (len(allids), len(issueids), len(cleanids)))
        self.assertFalse(issueids & cleanids)
        self.assertEqual(allids, issueids | cleanids)
        self.assertEqual((2077, 188, 1889),
                         (self.summary["us_candidates_total"],
                          self.summary["issues_total_unique_airports"],
                          self.summary["faapass_without_flagged_runway_tier_or_state_conflicts_pending_operator_review"]))

    def test_clean_operator_list_has_no_access_or_runway_holds(self):
        lookup = {r["source_airport_id"]: r for r in self.full}
        for row in self.operator:
            src = lookup[row["source_airport_id"]]
            self.assertEqual("PUBLIC_USE_PAVED_SMALL_AIRCRAFT_OPS_REVIEW", src["commercial_review_track"])
            self.assertEqual("NO", row["game_approval"])
            self.assertEqual("UNVERIFIED", row["FAA_airport_manager_permission_pending"])
            self.assertEqual("UNVERIFIED_PENDING_NASR_CROSSWALK", row["FAA_part139_class_pending"])

    def test_issues_are_exclusively_holds_or_conflicts(self):
        lookup = {r["source_airport_id"]: r for r in self.full}
        physical_pass_issues = 0
        hold_issues = 0
        for row in self.issues:
            src = lookup[row["source_airport_id"]]
            self.assertEqual("NO", row["game_activation"])
            self.assertNotEqual("", row["followup_issue"])
            if src["commercial_review_track"] == "PUBLIC_USE_PAVED_SMALL_AIRCRAFT_OPS_REVIEW":
                physical_pass_issues += 1
            else:
                hold_issues += 1
        self.assertEqual(40, physical_pass_issues)
        self.assertEqual(148, hold_issues)
        self.assertEqual(1929, len(self.operator)+physical_pass_issues)


if __name__ == "__main__":
    unittest.main()
