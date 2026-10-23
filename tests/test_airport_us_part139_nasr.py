"""Offline integrity tests for Airlinerra US Part 139 FAA NASR certificate crosswalk."""
import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "verify_us_part139_nasr.py"
spec = importlib.util.spec_from_file_location("airlinerra_part139", SCRIPT)
s = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s)


class Part139Tests(unittest.TestCase):
    def test_official_classes_parse_without_guessing(self):
        for original, klass, arff in [
            ("I A", "I", "A"), ("II B", "II", "B"),
            ("III A", "III", "A"), ("IV A", "IV", "A"),
            ("I C", "I", "C"),
        ]:
            self.assertEqual((klass, arff, "PART139_CLASS_INDICATOR_REPORTED_BY_NASR"),
                             s.parse_class(original))
        self.assertEqual(("", "", "NO_PART139_TYPE_REPORTED_IN_NASR"), s.parse_class(""))
        self.assertEqual(("", "", "UNRECOGNIZED_NASR_PART139_CODE_REVIEW"), s.parse_class("PAVED"))
        self.assertEqual(("", "", "UNRECOGNIZED_NASR_PART139_CODE_REVIEW"), s.parse_class("I X"))

    def test_class_permissions_do_not_authorize_game(self):
        self.assertEqual("POTENTIAL_CLASS_SUPPORT_SUBJECT_TO_AUTHORIZATION", s.CLASS_PERMITTED["I"][1])
        self.assertEqual("NO_CLASS_SUPPORT_FOR_SCHEDULED_31_PLUS", s.CLASS_PERMITTED["II"][1])
        self.assertEqual("NO_CLASS_SUPPORT_FOR_UNSCHEDULED_31_PLUS", s.CLASS_PERMITTED["III"][2])
        self.assertEqual("NO_CLASS_SUPPORT_FOR_SCHEDULED_10_TO_30", s.CLASS_PERMITTED["IV"][0])

    def _source_fixture(self):
        # Exercise exact site+identifier joining with source SHA invariant.
        audit = []
        for i in range(2077):
            verified = i != 2076
            audit.append({
                "source_airport_id": str(i + 10000),
                "airport_name": "Test research airport " + str(i),
                "faa_identifier": "T1" if verified else "",
                "faa_site_number": str(i) if verified else "",
                "faa_match_status": "EXACT_FAA_IDENTIFIER_AND_WITHIN_5KM" if verified else "NOT_MATCHED_TO_FAA_BY_IDENTIFIER_AND_LOCATION",
                "overall_review_status": "FAA_PHYSICAL_AND_PUBLIC_USE_VERIFIED_COMMERCIAL_REVIEW" if verified else "HOLD_NO_UNAMBIGUOUS_FAA_MATCH",
                "state": "TX",
            })
        base = []
        for i in range(6000):
            base.append({
                "SITE_NO": str(i), "ARPT_ID": "T1",
                "EFF_DATE": "2026/10/01", "FAR_139_TYPE_CODE": "I A" if i == 0 else "",
                "FAR_139_CARRIER_SER_CODE": "S" if i == 0 else "",
                "ARFF_CERT_TYPE_DATE": "2026/01" if i == 0 else "",
            })
        return audit, base

    def test_record_coverage_and_no_implicit_approval(self):
        audit, base = self._source_fixture()
        rows = s.build(audit, base, "testzip", {"faa_zip_sha256": "testzip"})
        self.assertEqual(2077, len(rows))
        first = rows[0]
        self.assertEqual("I", first["faa_part139_class"])
        self.assertEqual("A", first["faa_arff_index"])
        self.assertEqual("POTENTIAL_CLASS_SUPPORT_SUBJECT_TO_AUTHORIZATION",
                         first["scheduled_31_plus_passenger_seats_cert_indicator"])
        self.assertEqual("NO", first["playable"])
        self.assertEqual("NO", first["final_game_approval"])
        self.assertEqual("UNVERIFIED", first["commercial_operator_permission"])
        self.assertEqual("NO_PART139_TYPE_REPORTED_IN_NASR", rows[1]["part139_nasr_evidence_status"])
        self.assertEqual("NO_INDEPENDENT_FAA_MATCH_CANNOT_INFER_CERTIFICATION",
                         rows[-1]["part139_nasr_evidence_status"])

    def test_duplicate_site_number_with_other_airport_identifier_is_safe(self):
        audit, base = self._source_fixture()
        duplicate = dict(base[0])
        duplicate["ARPT_ID"] = "DIFFERENT"
        duplicate["FAR_139_TYPE_CODE"] = "II B"
        base.append(duplicate)
        rows = s.build(audit, base, "testzip", {"faa_zip_sha256": "testzip"})
        self.assertEqual(2077, len(rows))
        self.assertEqual("I", rows[0]["faa_part139_class"])
        self.assertEqual("A", rows[0]["faa_arff_index"])
        self.assertEqual("NO", rows[0]["playable"])

    def test_duplicate_exact_site_and_airport_identifier_stays_on_hold(self):
        audit, base = self._source_fixture()
        duplicate = dict(base[0])
        duplicate["FAR_139_TYPE_CODE"] = "IV A"
        base.append(duplicate)
        rows = s.build(audit, base, "testzip", {"faa_zip_sha256": "testzip"})
        self.assertEqual("AMBIGUOUS_FAA_SITE_IDENTIFIER_CERTIFICATION_HOLD",
                         rows[0]["part139_nasr_evidence_status"])
        self.assertEqual("", rows[0]["faa_part139_class"])
        self.assertEqual("HOLD_CERT_CLASS_NOT_EVIDENCED",
                         rows[0]["scheduled_31_plus_passenger_seats_cert_indicator"])
        self.assertEqual("NO", rows[0]["playable"])

    def test_hash_mismatch_fails_closed(self):
        audit, base = self._source_fixture()
        with self.assertRaisesRegex(ValueError, "differs"):
            s.build(audit, base, "different", {"faa_zip_sha256": "original"})

    def test_missing_faa_part139_fields_fails_closed(self):
        audit, base = self._source_fixture()
        del base[0]["FAR_139_TYPE_CODE"]
        with self.assertRaisesRegex(ValueError, "mandatory"):
            s.build(audit, base, "testzip", {"faa_zip_sha256": "testzip"})


if __name__ == "__main__":
    unittest.main()
