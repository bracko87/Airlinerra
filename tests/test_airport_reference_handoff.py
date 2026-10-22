"""Fixture-only tests: no Supabase connection and no original airport research edits."""
import csv
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from prepare_airport_reference_handoff import build_snapshot, TRAFFIC_FIELDS

def put(root, name, items):
    path = root / name
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as output:
        writer = csv.DictWriter(output, fieldnames=items[0].keys())
        writer.writeheader()
        writer.writerows(items)

def decode(content):
    return list(csv.DictReader(io.StringIO(content.decode("utf-8"))))

class ReferenceHandoffTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.master = "data/airports/airport_register.csv"
        self.review = "data/airports/classification/airport_classification_review.csv"
        self.group = "data/airports/generated/group1/group1_technical_candidates.csv"
        self.commercial = "data/airports/commercial/group1/group1_commercial_review.csv"
        base = dict(runway_length_m="2200.0", runway_surface="ASP",
                    minimum_eligible_level="1", runway_status="RUNWAY_QUALIFIED")
        put(self.root, self.master, [
            dict(source_airport_id="123", country_iso="PE", airport_name="Test Peru",
                 ident="SPXX", gps_code="SPXX", **base, source_type="OURAIRPORTS",
                 assigned_category=""),
            dict(source_airport_id="fictional:RS:LYAL", country_iso="RS",
                 airport_name="Aleksandrovo Airport", ident="LYAL", gps_code="LYAL",
                 **base, source_type="FICTIONAL", assigned_category="Local"),
        ])
        empty = dict.fromkeys([x for x in TRAFFIC_FIELDS
                               if x not in {"airport_key", "source_airport_id", "country_iso", "airport_name"}], "")
        put(self.root, self.review, [
            dict(source_airport_id="123", country_iso="PE", airport_name="Test Peru",
                 **{**empty, "provisional_category": "Medium",
                    "decision_status": "PROVISIONAL_OFFICIAL_REGULAR_TRAFFIC",
                    "regular_passenger_proxy": "200000", "evidence_year": "2025",
                    "passenger_measure": "PERU_DGAC_REGULAR_PAX_ROUNDED_1000"}),
            dict(source_airport_id="fictional:RS:LYAL", country_iso="RS",
                 airport_name="Aleksandrovo Airport",
                 **{**empty, "final_assigned_category": "Local",
                    "decision_status": "OWNER_ASSIGNED"}),
        ])
        put(self.root, self.group, [
            dict(ourairports_id="123", iso_country="PE", airport_name="Test Peru",
                 ident="SPXX", gps_code="SPXX",
                 longest_reported_eligible_runway_m="2200.0", surface="ASP",
                 eligible_runway_count="2", runway_ids="800;801"),
        ])
        put(self.root, self.commercial, [
            dict(source_airport_id="123", country_iso="PE", airport_name="Test Peru",
                 source_ident="SPXX", passenger_commercial_permission="YES",
                 cargo_commercial_permission="UNKNOWN",
                 review_classification="PASSENGER_EVIDENCED_CARGO_UNKNOWN",
                 passenger_evidence_url="https://example.org", cargo_evidence_url="",
                 access_evidence_url="", verification_as_of="2026-10-21",
                 review_notes="Provisional only"),
        ])

    def tearDown(self):
        self.tmp.cleanup()

    def test_deterministic_with_all_airports_preserved_and_disabled(self):
        payloads, manifest = build_snapshot(self.root)
        self.assertEqual(payloads, build_snapshot(self.root)[0])
        self.assertEqual(manifest["airport_count"], 2)
        self.assertEqual(manifest["technical_runway_reference_count"], 2)
        self.assertEqual(manifest["b02_provisional_passenger_tiers"], 1)
        self.assertFalse(manifest["supabase_applied"])
        self.assertFalse(manifest["gameplay_activation_authorized"])
        self.assertEqual(set(payloads), {"airport_reference.csv", "airport_traffic_review.csv",
                                         "airport_access_review.csv",
                                         "airport_runway_source_links.csv", "snapshot_manifest.json"})
        airports = decode(payloads["airport_reference.csv"])
        self.assertTrue(all(r["game_active"] == "false" for r in airports))
        self.assertEqual(next(r for r in airports if r["source_type"] == "FICTIONAL")["final_assigned_category"], "Local")
        self.assertEqual(next(r for r in airports if r["source_type"] == "OURAIRPORTS")["final_assigned_category"], "")
        traffic = decode(payloads["airport_traffic_review.csv"])
        self.assertEqual(next(r for r in traffic if r["source_airport_id"] == "123")["regular_passenger_proxy"], "200000")
        access = decode(payloads["airport_access_review.csv"])
        self.assertTrue(all(r["operational_access_status"] == "UNVERIFIED" for r in access))
        self.assertEqual({r["source_runway_id"] for r in decode(payloads["airport_runway_source_links.csv"])},
                         {"800", "801"})
        self.assertEqual(json.loads(payloads["snapshot_manifest.json"])["output_sha256"],
                         manifest["output_sha256"])

    def test_duplicate_runway_id_rejected(self):
        path = self.root / self.group
        path.write_text(path.read_text().replace("800;801", "800;800"))
        with self.assertRaisesRegex(ValueError, "Duplicate source runway"):
            build_snapshot(self.root)

    def test_unapproved_real_final_tier_rejected(self):
        path = self.root / self.master
        path.write_text(path.read_text().replace("OURAIRPORTS,\n", "OURAIRPORTS,Large\n", 1))
        with self.assertRaisesRegex(ValueError, "Final category drift|unapproved final"):
            build_snapshot(self.root)

    def test_orphan_technical_record_rejected(self):
        path = self.root / self.group
        path.write_text(path.read_text().replace("123,PE", "999,PE"))
        with self.assertRaisesRegex(ValueError, "orphan group candidate"):
            build_snapshot(self.root)

if __name__ == "__main__":
    unittest.main()
