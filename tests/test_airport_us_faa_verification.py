"""Offline unit tests for the FAA airport verification pipeline."""
import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "verify_us_airports_faa.py"
spec = importlib.util.spec_from_file_location("faa_review", SCRIPT)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


def airport(**kwargs):
    result = {"ARPT_ID": "2IS", "SITE_NO": "TEST.", "SITE_TYPE_CODE": "A",
              "LAT_DECIMAL": "26.735195", "LONG_DECIMAL": "-81.051078",
              "ARPT_STATUS": "O", "FACILITY_USE_CODE": "PU"}
    result.update(kwargs)
    return result


def runway(surface="ASPH", length="6000", width="75"):
    return {"SITE_NO": "TEST.", "RWY_LEN": length, "RWY_WIDTH": width,
            "SURFACE_TYPE_CODE": surface, "RWY_ID": "13/31"}


class FAAVerificationTests(unittest.TestCase):
    def test_surface_conservative(self):
        for name in ("ASPH", "CONC", "ASPH-CONC", "CONC/ASPH"):
            self.assertTrue(m.confirmed_surface(name), name)
        for name in ("ASPH-G", "ASPH-GRVL", "GRVL", "TURF", "PAVED",
                     "BITUM", "", "ASPH/DIRT", "CONC-G"):
            self.assertFalse(m.confirmed_surface(name), name)

    def test_airport_join_requires_code_and_coordinate(self):
        source = {"faa_identifier_candidates_NOT_VERIFIED": "K2IS|2IS",
                  "latitude_deg": "26.735195", "longitude_deg": "-81.051078"}
        status, found = m.select_faa_match(source, {"2IS": [airport()]})
        self.assertEqual("EXACT_FAA_IDENTIFIER_AND_WITHIN_5KM", status)
        self.assertEqual("2IS", found[1]["ARPT_ID"])
        status, found = m.select_faa_match(source, {"2IS": [airport(LAT_DECIMAL="30.0")]})
        self.assertEqual("NOT_MATCHED_TO_FAA_BY_IDENTIFIER_AND_LOCATION", status)
        self.assertIsNone(found)

    def test_physical_public_nonapproval(self):
        status, use, qualifying, best, decision = m.classify(
            airport(), [runway(length="5902", width="75")])
        self.assertEqual("O", status)
        self.assertEqual("PU", use)
        self.assertEqual(1, len(qualifying))
        self.assertEqual("FAA_PHYSICAL_AND_PUBLIC_USE_VERIFIED_COMMERCIAL_REVIEW", decision)
        self.assertAlmostEqual(1798.9296, best[0]*.3048)

    def test_no_pavement_and_private_remain_held(self):
        _, _, qualified, _, decision = m.classify(airport(), [runway(surface="ASPH-GRVL")])
        self.assertEqual(0, len(qualified))
        self.assertEqual("FAA_NO_CONFIRMED_1200M_ASPHALT_CONCRETE_RUNWAY_HOLD", decision)
        _, _, qualified, _, decision = m.classify(
            airport(FACILITY_USE_CODE="PR"), [runway()])
        self.assertEqual(1, len(qualified))
        self.assertEqual("FAA_NON_PUBLIC_USE_ACCESS_HOLD", decision)
        _, _, _, _, decision = m.classify(
            airport(ARPT_STATUS="C"), [runway()])
        self.assertEqual("FAA_AIRPORT_NOT_OPEN_HOLD", decision)

    def test_exact_threshold(self):
        self.assertEqual(0, len(m.classify(airport(), [runway(length="3937")])[2]))
        self.assertEqual(1, len(m.classify(airport(), [runway(length="3938")])[2]))


if __name__ == "__main__":
    unittest.main()
