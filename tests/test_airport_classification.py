"""Tests for evidence-gated six-tier classification (stdlib unittest)."""
from __future__ import annotations
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from build_airport_classification_review import build_rows, provisional_tier

def airport(ident, country="BR", source_type="OURAIRPORTS", category=""):
    return {"source_airport_id": ident, "country_iso": country,
            "airport_name": f"Test {ident}", "assigned_category": category,
            "source_type": source_type}

def evidence(ident, rp="0", np="0", rc="0", nc="0"):
    return {"source_airport_id": ident, "year": "2025",
            "regular_passenger_movements": rp, "nonregular_passenger_movements": np,
            "regular_cargo_kg": rc, "nonregular_cargo_kg": nc,
            "source_url": "https://example.org/anac.csv"}

class ClassificationReviewTests(unittest.TestCase):
    def test_six_tiers_and_boundaries(self):
        edges = [(1, "Local"), (9_999, "Local"), (10_000, "Regional"),
                 (99_999, "Regional"), (100_000, "Medium"), (999_999, "Medium"),
                 (1_000_000, "Large"), (9_999_999, "Large"),
                 (10_000_000, "Major Hub"), (49_999_999, "Major Hub"),
                 (50_000_000, "Mega Hub")]
        for count, tier in edges:
            with self.subTest(count=count):
                self.assertEqual(provisional_tier(count), tier)
        with self.assertRaises(ValueError):
            provisional_tier(0)

    def test_proposal_does_not_grant_final_category(self):
        row = build_rows([airport("12")], [evidence("12", rp="10000000")], [])[0]
        self.assertEqual(row["provisional_category"], "Major Hub")
        self.assertEqual(row["final_assigned_category"], "")
        self.assertEqual(row["decision_status"], "PROVISIONAL_REGULAR_TRAFFIC")

    def test_unknown_charter_and_cargo_are_not_automatically_tiered(self):
        rows = build_rows([airport("12"), airport("13"), airport("14")],
                          [evidence("12"), evidence("13", np="22000"),
                           evidence("14", rc="5000")], [])
        self.assertEqual([r["decision_status"] for r in rows],
                         ["NEEDS_EVIDENCE", "NONREGULAR_ONLY_REVIEW", "CARGO_ONLY_REVIEW"])
        self.assertTrue(all(not r["provisional_category"] for r in rows))

    def test_historical_exclusion_and_fictional_preserved(self):
        rows = build_rows([airport("23"), airport("67", country="US"),
                           airport("fictional:RS:LYAL", country="RS", source_type="FICTIONAL", category="Local")],
                          [evidence("23"), evidence("335361")], [{"source_airport_id": "335361"}])
        self.assertEqual(rows[1]["passenger_activity_signal"], "NOT_RESEARCHED")
        self.assertEqual(rows[2]["decision_status"], "OWNER_ASSIGNED")
        self.assertNotIn("335361", [r["source_airport_id"] for r in rows])

    def test_unexplained_exclusions_and_duplicates_fail(self):
        with self.assertRaises(ValueError):
            build_rows([airport("12")], [evidence("12"), evidence("999")], [])
        with self.assertRaises(ValueError):
            build_rows([airport("12"), airport("12")], [evidence("12")], [])

if __name__ == "__main__":
    unittest.main()
