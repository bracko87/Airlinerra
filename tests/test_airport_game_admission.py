"""Ensure technical airport research candidates cannot become playable without verified evidence."""
import csv
import json
import unittest
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "data" / "airports" / "local_regional_expansion"


def read_csv(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        result = list(csv.DictReader(stream))
    if any(None in row or any(v is None for v in row.values()) for row in result):
        raise ValueError(f"Malformed CSV: {path}")
    return result


class GameAdmissionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.candidates = read_csv(BASE / "candidates_local_regional.csv")
        cls.status = read_csv(BASE / "game_admission_status_3906.csv")
        cls.evidence = read_csv(BASE / "game_admission_evidence.csv")
        cls.summary = json.loads((BASE / "game_admission_summary.json").read_text(encoding="utf-8"))

    def test_full_unique_coverage_no_implicit_approval(self):
        source = {row["source_airport_id"]: row for row in self.candidates}
        review = {row["source_airport_id"]: row for row in self.status}
        self.assertEqual(3906, len(source))
        self.assertEqual(3906, len(review))
        self.assertEqual(len(source), len(self.candidates))
        self.assertEqual(len(review), len(self.status))
        self.assertEqual(set(source), set(review))
        self.assertEqual(3906, self.summary["all_candidate_count"])
        approved = 0
        for airport_id, row in review.items():
            original = source[airport_id]
            self.assertEqual(original["airport_name"], row["airport_name"])
            self.assertEqual(original["country_iso"], row["country_iso"])
            self.assertEqual(original["proposed_category"], row["original_proposed_category"])
            self.assertEqual("YES", row["source_codes_not_admission_gate"])
            if row["game_admission_status"] == "APPROVED_FOR_GAME":
                approved += 1
                self.assertEqual("YES", row["playable"])
            else:
                self.assertTrue(row["game_admission_status"].startswith("HOLD_"))
                self.assertEqual("NO", row["playable"])
        self.assertEqual(self.summary["gameplay_approved"], approved)
        self.assertEqual(self.summary["gameplay_on_hold"], len(review)-approved)

    def test_positive_admission_requires_independent_authorities_and_owner(self):
        evidence = {row["source_airport_id"]: row for row in self.evidence}
        self.assertEqual(len(evidence), len(self.evidence))
        for row in self.status:
            if row["game_admission_status"] != "APPROVED_FOR_GAME":
                continue
            ev = evidence.get(row["source_airport_id"])
            self.assertIsNotNone(ev, f"Approval lacks evidence: {row['source_airport_id']}")
            self.assertEqual("YES", ev.get("owner_approval"), "Owner must approve each airport")
            self.assertEqual("VERIFIED", ev.get("identity_admission_gate"))
            self.assertEqual("VERIFIED", ev.get("runway_admission_gate"))
            self.assertGreaterEqual(float(ev.get("verified_usable_runway_length_m") or 0), 1200)
            self.assertIn(ev.get("verified_surface"), ("ASPHALT", "CONCRETE", "ASPHALT_CONCRETE"))
            self.assertEqual("VERIFIED", ev.get("civilian_commercial_admission_gate"))
            self.assertTrue(ev.get("source_url"))
            self.assertEqual("YES", row["playable"])

    def test_belterra_not_misidentified_and_specific_cases_still_held(self):
        e = {row["source_airport_id"]: row for row in self.evidence}
        s = {row["source_airport_id"]: row for row in self.status}
        self.assertEqual("HOLD_COMMERCIAL_PERMISSION", s["18593"]["game_admission_status"])
        self.assertEqual("Local", s["18593"]["verified_review_category"])
        self.assertEqual("2IS", e["18593"]["known_code"])
        self.assertEqual("FAA_LOCAL_IDENTIFIER", e["18593"]["known_code_type"])
        self.assertEqual("HOLD_IDENTITY_AND_PAVEMENT_CONFLICT", s["37074"]["game_admission_status"])
        self.assertEqual("UNVERIFIED", e["37074"]["runway_surface"])
        self.assertIn("Different Belterra SWPX", e["37074"]["notes"])
        self.assertEqual("HOLD_PRIVATE_COMMERCIAL_PERMISSION", s["39730"]["game_admission_status"])
        self.assertEqual("CSQ4", e["39730"]["known_code"])
        self.assertEqual("UNVERIFIED_PRIVATE_OWNER_APPROVAL_REQUIRED", e["39730"]["commercial_permission"])

    def test_summary_matches_status_rows_and_six_tier_policy(self):
        statuses = Counter(row["game_admission_status"] for row in self.status)
        self.assertEqual(self.summary["hold_reasons"], dict(statuses))
        self.assertEqual(0, self.summary["gameplay_approved"])
        self.assertTrue(self.summary["original_3140_unchanged"])
        self.assertTrue(self.summary["technical_master_8153_unchanged"])
        self.assertEqual(1200, self.summary["runway_minimum_m"])
        self.assertEqual({"Local", "Regional"}, {row["original_proposed_category"] for row in self.status})
        self.assertTrue(self.summary["manual_owner_final_approval_required"])


if __name__ == "__main__":
    unittest.main()
