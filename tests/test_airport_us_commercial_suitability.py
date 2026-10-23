"""Regression tests for the separate 2,077-airport US commercial-use triage.

No airport may be activated from NASR public-use or runway evidence alone.
"""
import csv
import json
import unittest
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "data" / "airports" / "local_regional_expansion" / "us_verification"


def rows(name):
    with (BASE / name).open(newline="", encoding="utf-8-sig") as handle:
        result = list(csv.DictReader(handle))
    if any(None in row or any(v is None for v in row.values()) for row in result):
        raise ValueError(f"Malformed CSV: {name}")
    return result


class USCommercialReviewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.faa = rows("us_faa_review_2026_10_01.csv")
        cls.review = rows("us_commercial_suitability_2077.csv")
        cls.holds = rows("us_commercial_hold_cases_148.csv")
        cls.summary = json.loads((BASE / "us_commercial_suitability_summary.json").read_text(encoding="utf-8"))

    def test_ids_and_source_data_untouched(self):
        faa = {r["source_airport_id"]: r for r in self.faa}
        review = {r["source_airport_id"]: r for r in self.review}
        holds = {r["source_airport_id"]: r for r in self.holds}
        self.assertEqual(2077, len(self.faa))
        self.assertEqual(2077, len(self.review))
        self.assertEqual(2077, len(faa))
        self.assertEqual(2077, len(review))
        self.assertEqual(set(faa), set(review))
        self.assertEqual(148, len(self.holds))
        self.assertEqual(148, len(holds))
        self.assertTrue(set(holds).issubset(review))
        self.assertEqual(2077, self.summary["total_airports"])
        for aid, f in faa.items():
            r = review[aid]
            self.assertEqual(f["airport_name"], r["airport_name"])
            self.assertEqual(f["state"], r["state"])
            self.assertEqual(f["faa_identifier"], r["faa_identifier_verified_local_only"])
            self.assertEqual(f["faa_best_length_m"], r["faa_best_qualifying_length_m"])
            self.assertEqual(f["faa_best_width_m"], r["faa_best_qualifying_width_m"])

    def test_physical_stage_tracks_and_six_tiers(self):
        counts = Counter(r["commercial_review_track"] for r in self.review)
        self.assertEqual(counts, self.summary["review_tracks"])
        self.assertEqual(1929, counts["PUBLIC_USE_PAVED_SMALL_AIRCRAFT_OPS_REVIEW"])
        self.assertEqual(115, counts["HOLD_NONPUBLIC_AIRPORT_ACCESS"])
        self.assertEqual(13, counts["HOLD_NO_QUALIFIED_FAA_PAVEMENT"])
        self.assertEqual(19, counts["HOLD_AMBIGUOUS_OR_MISSING_FAA_MATCH"])
        self.assertEqual(1, counts["HOLD_NOT_OPEN"])
        self.assertEqual({"Local", "Regional"}, {r["original_proposed_category"] for r in self.review})
        self.assertEqual(0, self.summary["output_game_activation_count"])

    def test_no_commercial_approval_or_scheduled_atr_without_certification(self):
        for row in self.review:
            self.assertEqual("NO", row["game_activation"])
            self.assertEqual("NOT_GRANTED", row["final_owner_approval"])
            self.assertEqual("NOT_VERIFIED", row["operator_commercial_permission"])
            self.assertEqual("NOT_YET_CROSSCHECKED", row["part139_certification"])
            self.assertEqual("HOLD_PART139_CLASS_I_AND_OPERATOR",
                             row["scheduled_31_plus_seats_including_ATR42"])
            self.assertEqual("HOLD_PART139_CERT_AND_OPERATOR", row["scheduled_10_to_30_seats"])
            if row["commercial_review_track"] == "PUBLIC_USE_PAVED_SMALL_AIRCRAFT_OPS_REVIEW":
                self.assertEqual("POTENTIAL_NOT_OPERATOR_VERIFIED",
                                 row["small_charter_upto_9_seats"])
            else:
                self.assertEqual("HOLD", row["small_charter_upto_9_seats"])

    def test_original_local_icao_iata_kept_separate(self):
        count_lid = sum(bool(r["faa_identifier_verified_local_only"]) for r in self.review)
        self.assertEqual(2058, count_lid)
        original_all_three_blank_with_lid = sum(
            bool(r["faa_identifier_verified_local_only"])
            and not r["source_gps_code"]
            and not r["source_icao_code"]
            and not r["source_iata_code"]
            for r in self.review
        )
        self.assertEqual(69, original_all_three_blank_with_lid)
        self.assertEqual(2058, self.summary["verified_faa_local_identifiers"])

    def test_all_148_holds_partitioned(self):
        held = {r["source_airport_id"] for r in self.holds}
        expected = {r["source_airport_id"] for r in self.review
                    if r["commercial_review_track"] != "PUBLIC_USE_PAVED_SMALL_AIRCRAFT_OPS_REVIEW"}
        self.assertEqual(expected, held)
        passed = [r for r in self.review
                  if r["commercial_review_track"] == "PUBLIC_USE_PAVED_SMALL_AIRCRAFT_OPS_REVIEW"]
        self.assertEqual(1929, len(passed))
        self.assertEqual(1929, sum(bool(r["faa_best_qualifying_width_m"]) for r in passed))


if __name__ == "__main__":
    unittest.main()
