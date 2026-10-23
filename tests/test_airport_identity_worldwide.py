"""Tests for one-pass worldwide airport identity refresh; no network/Supabase access."""
import csv
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from refresh_airport_identity_worldwide import build

def write_csv(path, rows, fields=None):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields or tuple(rows[0]))
        w.writeheader()
        w.writerows(rows)

def decode(data):
    return list(csv.DictReader(io.StringIO(data.decode("utf-8"))))

class WorldwideAirportIdentityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.sha = "a" * 40
        self.src = self.root / "airports.csv"
        self.master = self.root / "data/airports/airport_register.csv"
        self.military = self.root / "data/airports/identity/verified_military_only.csv"
        self.loc = self.root / "data/airports/identity/fictional_location_references.csv"
        write_csv(self.master, [
            dict(source_airport_id="100", country_iso="RS", airport_name="Example Air Base",
                 ident="LYXX", gps_code="LYXX", runway_length_m="1500",
                 runway_surface="ASP", source_type="OURAIRPORTS", assigned_category=""),
            dict(source_airport_id="101", country_iso="RS", airport_name="Small Civil Airport",
                 ident="RS-0010", gps_code="", runway_length_m="1600",
                 runway_surface="CON", source_type="OURAIRPORTS", assigned_category=""),
            dict(source_airport_id="fictional:RS:LYAL", country_iso="RS",
                 airport_name="Aleksandrovo Airport", ident="LYAL", gps_code="LYAL",
                 runway_length_m="2200", runway_surface="ASP",
                 source_type="FICTIONAL", assigned_category="Local"),
        ])
        write_csv(self.src, [
            dict(id="100", iso_country="RS", ident="LYXX", gps_code="LYXX", icao_code="LYXX",
                 iata_code="", latitude_deg="45.0", longitude_deg="20.0",
                 type="medium_airport", scheduled_service="no", municipality="Town",
                 iso_region="RS-00", local_code="", elevation_ft="250"),
            dict(id="101", iso_country="RS", ident="RS-0010", gps_code="",
                 icao_code="", iata_code="", latitude_deg="46.0", longitude_deg="21.0",
                 type="small_airport", scheduled_service="no", municipality="Town",
                 iso_region="RS-00", local_code="", elevation_ft="120"),
        ])
        write_csv(self.loc, [dict(source_airport_id="fictional:RS:LYAL", country_iso="RS",
                                  place_name="Aleksandrovo", municipality="Nova Crnja",
                                  region="Banat", district="Central Banat", province="Vojvodina",
                                  reference_latitude_deg="45.63778", reference_longitude_deg="20.59159",
                                  coordinate_kind="SETTLEMENT_CENTER_NOT_AIRPORT_SITE",
                                  source_url="https://mapcarta.com/13914886",
                                  note="Owner confirmed Aleksandrovo Banat, not specific runway")])
        write_csv(self.military, [], fields=["source_airport_id", "country_iso",
                                             "verified_status", "evidence_url",
                                             "evidence_date", "review_note"])

    def tearDown(self):
        self.temp.cleanup()

    def test_complete_inventory_without_invented_codes_or_airport_coordinates(self):
        payloads, stats = build(self.src, self.sha, self.root)
        self.assertEqual(stats["airports"], 3)
        self.assertEqual(stats["coordinates_source_reported"], 2)
        self.assertEqual(payloads, build(self.src, self.sha, self.root)[0])
        data = {r["source_airport_id"]: r for r in decode(payloads["airport_identity_worldwide.csv"])}
        self.assertEqual(data["100"]["icao_code"], "LYXX")
        self.assertEqual(data["101"]["iata_code"], "")
        self.assertEqual(data["101"]["iata_code_status"], "NOT_REPORTED")
        self.assertEqual(data["101"]["coordinate_status"], "SOURCE_COORDINATES_REPORTED")
        self.assertEqual(data["101"]["gameplay_status"], "RESEARCH_ONLY_NOT_ACTIVE")
        self.assertEqual(data["100"]["military_review_hint"], "NAME_SUGGESTS_MILITARY_REVIEW")
        self.assertEqual(data["100"]["military_only_status"], "UNVERIFIED")
        self.assertEqual(data["fictional:RS:LYAL"]["municipality"], "Nova Crnja")
        self.assertEqual(data["fictional:RS:LYAL"]["latitude_deg"], "")
        self.assertEqual(data["fictional:RS:LYAL"]["coordinate_status"], "FICTIONAL_AIRPORT_SITE_UNSPECIFIED")
        self.assertEqual(data["fictional:RS:LYAL"]["gameplay_status"], "DESIGN_ONLY_NOT_ACTIVE")
        self.assertFalse(json.loads(payloads["identity_summary.json"])["gameplay_activation_performed"])

    def test_military_only_requires_positive_external_evidence(self):
        write_csv(self.military, [dict(source_airport_id="100", country_iso="RS",
                                      verified_status="MILITARY_ONLY_CONFIRMED",
                                      evidence_url="https://example.org/authority",
                                      evidence_date="2026-10-23", review_note="No civil service")])
        payloads, stats = build(self.src, self.sha, self.root)
        data = {r["source_airport_id"]: r for r in decode(payloads["airport_identity_worldwide.csv"])}
        self.assertEqual(stats["confirmed_military_only_excluded"], 1)
        self.assertEqual(data["100"]["gameplay_status"], "EXCLUDED_MILITARY_ONLY")
        self.assertEqual(data["101"]["gameplay_status"], "RESEARCH_ONLY_NOT_ACTIVE")

    def test_missing_source_airport_is_exception_not_fake_coordinates(self):
        self.src.write_text(self.src.read_text().replace("101,RS,RS-0010", "222,RS,RS-0010"))
        payloads, _ = build(self.src, self.sha, self.root)
        data = {r["source_airport_id"]: r for r in decode(payloads["airport_identity_worldwide.csv"])}
        self.assertEqual(data["101"]["coordinate_status"], "MISSING_OR_INVALID")
        issues = decode(payloads["identity_exceptions.csv"])
        self.assertTrue(any(r["source_airport_id"] == "101" and r["issue"] == "SOURCE_ID_NOT_FOUND" for r in issues))

    def test_unsupported_country_swap_is_not_silently_joined(self):
        self.src.write_text(self.src.read_text().replace("100,RS,LYXX", "100,DE,LYXX"))
        payloads, _ = build(self.src, self.sha, self.root)
        issues = decode(payloads["identity_exceptions.csv"])
        self.assertTrue(any(r["source_airport_id"] == "100" and r["issue"] == "COUNTRY_MISMATCH" for r in issues))

    def test_prohibited_military_without_source(self):
        write_csv(self.military, [dict(source_airport_id="100", country_iso="RS",
                                      verified_status="MILITARY_ONLY_CONFIRMED",
                                      evidence_url="", evidence_date="",
                                      review_note="Assumed from airport name")])
        with self.assertRaisesRegex(ValueError, "Military-only evidence invalid"):
            build(self.src, self.sha, self.root)

if __name__ == "__main__":
    unittest.main()
