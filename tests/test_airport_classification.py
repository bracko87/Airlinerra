"""Tests for evidence-gated six-tier classification (stdlib unittest)."""
from __future__ import annotations
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from build_airport_classification_review import build_rows, provisional_tier

def airport(ident, country="BR", source_type="OURAIRPORTS", category="", code=""):
    return {"source_airport_id": ident, "country_iso": country,
            "airport_name": f"Test {ident}", "assigned_category": category,
            "source_type": source_type, "ident": code, "gps_code": code}

def evidence(ident, rp="0", np="0", rc="0", nc="0"):
    return {"source_airport_id": ident, "year": "2025",
            "regular_passenger_movements": rp, "nonregular_passenger_movements": np,
            "regular_cargo_kg": rc, "nonregular_cargo_kg": nc,
            "source_url": "https://example.org/anac.csv"}

class ClassificationReviewTests(unittest.TestCase):
    def test_b02_passengers_preserve_ecuador_cargo(self):
        additional = {"source_airport_id": "1001", "country_iso": "EC",
            "icao_or_ident": "SEXX", "official_airport_label": "Test", "year": "2025",
            "passenger_estimate": "3813013", "metric": "EC_DGAC_2025_TOTAL_PAX",
            "source_url": "https://example.org/passengers",
            "qualification_note": "Official total"}
        cargo = [{"source_airport_id": "1001", "country_iso": "EC",
            "icao_or_ident": "SEXX", "year": "2025",
            "metric": "EC_DGAC_ANNUAL_CARGO_TONNES",
            "annual_cargo_tonnes": "26991.92",
            "source_url": "https://example.org/cargo"}]
        row = build_rows([airport("1001", country="EC", code="SEXX")], [], [],
            ecuador_cargo=cargo, b02_additional=[additional])[0]
        self.assertEqual(row["provisional_category"], "Large")
        self.assertEqual(row["annual_total_passenger_proxy"], "3813013")
        self.assertEqual(row["annual_cargo_tonnes_proxy"], "26991.92")
        self.assertEqual(row["final_assigned_category"], "")
        with self.assertRaisesRegex(ValueError, "code/source ID mismatch"):
            build_rows([airport("1001", country="EC", code="WRONG")], [], [],
                ecuador_cargo=cargo, b02_additional=[additional])

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

    def test_argentina_annual_total_stays_provisional(self):
        arg = [{"source_airport_id": "5771", "icao_or_ident": "SABE", "year": "2025",
                "reported_2025_thousands": "17.738", "metric": "ANAC_TOTAL_PAX_ROUNDED_1000",
                "passenger_total_estimate": "17738000", "source_url": "https://example.org/annual.pdf"}]
        result = build_rows([airport("5771", country="AR", code="SABE"), airport("99", country="AR")], [], [], arg)
        self.assertEqual(result[0]["provisional_category"], "Major Hub")
        self.assertEqual(result[0]["decision_status"], "PROVISIONAL_OFFICIAL_ANNUAL_TOTAL")
        self.assertEqual(result[0]["final_assigned_category"], "")
        self.assertEqual(result[0]["passenger_measure"], "ANAC_TOTAL_PAX_ROUNDED_1000")
        self.assertEqual(result[1]["decision_status"], "NEEDS_EVIDENCE")
        with self.assertRaises(ValueError):
            build_rows([airport("99", country="AR")], [], [], arg)

    def test_argentina_provenance_rejects_wrong_code_or_scale(self):
        arg = {"source_airport_id": "5771", "icao_or_ident": "SABE", "year": "2025",
               "reported_2025_thousands": "17.738", "metric": "ANAC_TOTAL_PAX_ROUNDED_1000",
               "passenger_total_estimate": "17738000", "source_url": "https://example.org/annual.pdf"}
        with self.assertRaisesRegex(ValueError, "code mismatch"):
            build_rows([airport("5771", country="AR", code="SAEZ")], [], [], [arg])
        with self.assertRaisesRegex(ValueError, "conversion mismatch"):
            build_rows([airport("5771", country="AR", code="SABE")], [], [],
                       [dict(arg, passenger_total_estimate="17738")])
        with self.assertRaisesRegex(ValueError, "unsupported"):
            build_rows([airport("5771", country="AR", code="SABE")], [], [],
                       [dict(arg, metric="UNVERIFIED_METRIC")])

    def test_peru_regular_annual_and_ecuador_cargo_do_not_grant_final_tier(self):
        peru = [{"source_airport_id":"6217","country_iso":"PE","icao_or_ident":"SPIM",
                 "year":"2025","metric":"PERU_DGAC_REGULAR_PAX_ROUNDED_1000",
                 "reported_2025_thousands":"27219","regular_passenger_estimate":"27219000",
                 "source_url":"https://example.org/official-peru.pdf"}]
        cargo = [{"source_airport_id":"308273","country_iso":"EC","icao_or_ident":"SEQM",
                  "year":"2025","metric":"EC_DGAC_ANNUAL_CARGO_TONNES",
                  "annual_cargo_tonnes":"397798.54","source_url":"https://example.org/dgac"}]
        result = build_rows([airport("6217",country="PE",code="SPIM"),
                             airport("308273",country="EC",code="SEQM")],
                            [],[],None,peru,cargo)
        self.assertEqual(result[0]["provisional_category"],"Major Hub")
        self.assertEqual(result[0]["decision_status"],"PROVISIONAL_OFFICIAL_REGULAR_TRAFFIC")
        self.assertEqual(result[0]["final_assigned_category"],"")
        self.assertEqual(result[1]["decision_status"],"CARGO_ONLY_REVIEW")
        self.assertEqual(result[1]["annual_cargo_tonnes_proxy"],"397798.54")
        self.assertEqual(result[1]["provisional_category"],"")

    def test_b02_mismatched_codes_or_units_are_rejected(self):
        peru = [{"source_airport_id":"6217","country_iso":"PE","icao_or_ident":"SPIM",
                 "year":"2025","metric":"PERU_DGAC_REGULAR_PAX_ROUNDED_1000",
                 "reported_2025_thousands":"27219","regular_passenger_estimate":"27219000",
                 "source_url":"https://example.org/official-peru.pdf"}]
        airport_row=airport("6217",country="PE",code="SPIM")
        with self.assertRaisesRegex(ValueError, "conversion mismatch"):
            build_rows([airport_row], [], [], None, [dict(peru[0],regular_passenger_estimate="27219")])
        with self.assertRaisesRegex(ValueError, "code/source ID mismatch"):
            build_rows([airport("6217",country="PE",code="SPZO")], [], [], None, peru)
        with self.assertRaisesRegex(ValueError, "unknown technical"):
            build_rows([airport("99",country="PE",code="SPIM")], [], [], None, peru)

    def test_chile_domestic_floor_is_not_full_airport_total(self):
        chile = [{"source_airport_id":"6018","country_iso":"CL","icao_or_ident":"SCFA",
                  "year":"2025","metric":"CHILE_MOP_2025_DOMESTIC_ONLY_ROUNDED_1000",
                  "quarter1_domestic_thousands":"325","quarter2_domestic_thousands":"330",
                  "quarter3_domestic_thousands":"353","quarter4_domestic_thousands":"359",
                  "annual_domestic_thousands":"1367","annual_domestic_estimate":"1367000",
                  **{f"source_quarter{i}":"https://concesiones.mop.gob.cl/government.pdf" for i in range(1,5)}}]
        a = airport("6018",country="CL",code="SCFA")
        result = build_rows([a],[],[],None,None,None,chile)[0]
        self.assertEqual(result["provisional_category"],"Large")
        self.assertEqual(result["decision_status"],"PROVISIONAL_DOMESTIC_FLOOR")
        self.assertEqual(result["domestic_passenger_floor_proxy"],"1367000")
        self.assertEqual(result["regular_passenger_proxy"],"")
        self.assertEqual(result["final_assigned_category"],"")
        with self.assertRaisesRegex(ValueError, "scale mismatch"):
            build_rows([a],[],[],None,None,None,[dict(chile[0],annual_domestic_estimate="1367")])
        with self.assertRaisesRegex(ValueError, "code/source ID mismatch"):
            build_rows([airport("6018",country="CL",code="SCCC")],[],[],None,None,None,chile)

    def test_unexplained_exclusions_and_duplicates_fail(self):
        with self.assertRaises(ValueError):
            build_rows([airport("12")], [evidence("12"), evidence("999")], [])
        with self.assertRaises(ValueError):
            build_rows([airport("12"), airport("12")], [evidence("12")], [])

if __name__ == "__main__":
    unittest.main()
