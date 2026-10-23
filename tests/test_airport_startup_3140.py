"""Validate the frozen Airlinerra commercial STARTUP data; never certify operations."""
import csv
import json
import unittest
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
D = ROOT / "data" / "airports"
S = D / "startup"

def read(path):
    with path.open(encoding="utf-8-sig", newline="") as fh:
        reader = csv.DictReader(fh)
        if not reader.fieldnames or len(reader.fieldnames) != len(set(reader.fieldnames)):
            raise ValueError("Duplicate or missing header: " + str(path))
        result = list(reader)
    if any(None in row or any(value is None for value in row.values()) for row in result):
        raise ValueError("Malformed CSV: " + str(path))
    return result

class Startup3140Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.master = read(D / "airport_register.csv")
        cls.ports = read(S / "airports_3140.csv")
        cls.runways = read(S / "runways_3140.csv")
        cls.exceptions = read(S / "exceptions_3140.csv")
        cls.audit = json.loads((S / "summary.json").read_text(encoding="utf-8"))
        cls.identity = read(D / "identity" / "airport_identity_worldwide.csv")
        cls.military = read(D / "identity" / "military_use_review_queue.csv")
        cls.evidence = read(D / "identity" / "military_use_civilian_evidence.csv")

    def test_ids_and_source_join(self):
        self.assertEqual(8153, len(self.master))
        self.assertEqual(3140, len(self.ports))
        self.assertEqual(4738, len(self.runways))
        self.assertEqual(227, len(self.exceptions))
        master = {r["source_airport_id"]: r for r in self.master}
        ids = [r["source_airport_id"] for r in self.ports]
        self.assertEqual(len(set(ids)), len(ids))
        active = {r["source_airport_id"]: r for r in self.identity
                  if r["source_type"] == "OURAIRPORTS" and r["scheduled_service_source"] == "yes"}
        self.assertEqual(set(ids), set(active))
        self.assertNotIn("fictional:RS:LYAL", ids)
        for r in self.ports:
            i = r["source_airport_id"]
            self.assertEqual("OURAIRPORTS", master[i]["source_type"])
            self.assertEqual(master[i]["country_iso"], r["country_iso"])
            self.assertEqual(master[i]["airport_name"], r["airport_name"])
            self.assertEqual(master[i]["runway_length_m"], r["source_screen_runway_length_m"])
            self.assertEqual(master[i]["runway_surface"], r["source_screen_runway_surface"])
            self.assertEqual(active[i]["latitude_deg"], r["latitude_deg"])
            self.assertEqual(active[i]["longitude_deg"], r["longitude_deg"])
            self.assertEqual(active[i]["icao_code"], r["icao_code"])
            self.assertEqual(active[i]["iata_code"], r["iata_code"])
            self.assertEqual(active[i]["gps_code"], r["gps_code"])
            self.assertEqual(active[i]["municipality"], r["municipality"])
            self.assertEqual("yes", r["scheduled_service_source"])
            self.assertTrue(r["country_name"])
            self.assertTrue(r["region_name"])
            self.assertEqual("NOT_ACTIVE_RESEARCH_ONLY", r["gameplay_status"])
            self.assertEqual("CANDIDATE_NOT_INDEPENDENTLY_APPROVED", r["commercial_eligibility_status"])

    def test_proposed_categories_and_game_estimated_slots_never_approve_real_airports(self):
        values = {"Local": 6, "Regional": 10, "Medium": 16, "Large": 24,
                  "Major Hub": 36, "Mega Hub": 50}
        self.assertEqual(set(values), {r["proposed_category"] for r in self.ports})
        self.assertTrue(all(r["assigned_category"] == "" for r in self.master
                            if r["source_type"] == "OURAIRPORTS"))
        for r in self.ports:
            self.assertEqual(str(values[r["proposed_category"]]), r["game_slots_per_hour_baseline"])
            self.assertEqual("PROVISIONAL_PHYSICAL_CLASS_MODEL", r["category_status"])
            self.assertEqual("GAME_ESTIMATE_MOVEMENTS_PER_HOUR_NOT_REAL_SLOTS", r["slot_basis"])
        self.assertIs(False, self.audit["category_is_approved"])
        self.assertIs(False, self.audit["commercial_permissions_verified_for_all"])
        self.assertIs(False, self.audit["gameplay_activation_performed"])

    def test_runway_source_join_and_counts(self):
        ports = {r["source_airport_id"]: r for r in self.ports}
        per_airport = defaultdict(list)
        seen = set()
        for runway in self.runways:
            airport_id = runway["source_airport_id"]
            self.assertIn(airport_id, ports)
            self.assertNotIn(runway["source_runway_id"], seen)
            seen.add(runway["source_runway_id"])
            self.assertEqual(ports[airport_id]["country_iso"], runway["country_iso"])
            self.assertIn(runway["is_open"], ("YES", "NO", "UNVERIFIED"))
            self.assertIn(runway["qualifies_paved_1200m"], ("YES", "NO"))
            if runway["qualifies_paved_1200m"] == "YES":
                self.assertEqual("YES", runway["is_open"])
                self.assertGreaterEqual(float(runway["length_m"]), 1200)
            per_airport[airport_id].append(runway)
        self.assertEqual(set(per_airport), set(ports))
        for i, port in ports.items():
            rw = per_airport[i]
            opened = [r for r in rw if r["is_open"] == "YES"]
            eligible = [r for r in rw if r["qualifies_paved_1200m"] == "YES"]
            widths = [r for r in opened if r["width_m"]]
            self.assertEqual(str(len(rw)), port["source_runway_records"])
            self.assertEqual(str(len(opened)), port["source_open_runway_count"])
            self.assertEqual(str(len(eligible)), port["source_open_paved_runway_count"])
            self.assertEqual(str(len(widths)), port["source_open_runways_with_width"])
        self.assertEqual(3053, sum(int(r["source_open_runways_with_width"]) > 0
                                   for r in self.ports))
        self.assertEqual(3132, sum(int(r["source_open_paved_runway_count"]) > 0
                                   for r in self.ports))

    def test_exception_ledger_and_military_intersection(self):
        expected = {"municipality": 52, "gps_code": 7, "icao_code": 15, "iata_code": 29,
                    "runway_width": 87, "raw_runway_qualifying_count": 8,
                    "airport_type_source": 1, "commercial_permission": 28}
        self.assertEqual(expected, dict(Counter(e["field"] for e in self.exceptions)))
        ids = {r["source_airport_id"] for r in self.ports}
        self.assertTrue(all(e["source_airport_id"] in ids for e in self.exceptions))
        flagged = {r["source_airport_id"] for r in self.military}
        evidenced = {r["source_airport_id"] for r in self.evidence}
        self.assertEqual(40, len(ids & flagged))
        self.assertEqual(12, len(ids & evidenced))
        self.assertEqual(28, len((ids & flagged) - evidenced))
        for r in self.ports:
            i = r["source_airport_id"]
            self.assertEqual("YES" if i in flagged else "NO", r["military_name_review"])
            self.assertEqual(bool(r["civilian_evidence_url"]), i in evidenced)
        self.assertEqual(3140, self.audit["commercial_startup_candidates"])
        self.assertEqual(5012, self.audit["other_real_airports_not_reviewed"])
        self.assertEqual(4738, self.audit["runways_total_source_rows"])


    def test_external_research_overlay_preserves_pinned_fields(self):
        # Do not replace OurAirports source blanks with research: join by stable source ID.
        enrichments = read(S / "researched_field_enrichments_3140.csv")
        self.assertEqual(57, len(enrichments))
        self.assertEqual(52, sum(e["field"] == "municipality" for e in enrichments))
        self.assertEqual(5, sum(e["field"] == "runway_width_m" for e in enrichments))
        self.assertEqual(len(enrichments),
                         len({(e["source_airport_id"], e["field"]) for e in enrichments}))
        airports = {r["source_airport_id"]: r for r in self.ports}
        missing_cities = {r["source_airport_id"] for r in self.ports
                          if not r["municipality"]}
        mapped_cities = {e["source_airport_id"] for e in enrichments
                         if e["field"] == "municipality"}
        self.assertEqual(missing_cities, mapped_cities)
        for e in enrichments:
            port = airports[e["source_airport_id"]]
            self.assertEqual(port["country_iso"], e["country_iso"])
            self.assertEqual(port["airport_name"], e["airport_name"])
            self.assertTrue(e["researched_value"])
            self.assertTrue(e["evidence_url"].startswith("https://"))
            self.assertTrue(e["evidence_basis"])
            self.assertIn(e["resolution_status"],
                          {"SOURCE_CROSS_REFERENCED", "NEEDS_SECONDARY_CONFIRMATION",
                           "OFFICIAL_AERONAUTICAL_REFERENCE"})
            if e["field"] == "municipality":
                self.assertEqual("", port["municipality"])
            else:
                self.assertEqual("runway_width_m", e["field"])
                self.assertEqual("0", port["source_open_runways_with_width"])
                self.assertGreater(float(e["researched_value"]), 0)
                self.assertEqual("OFFICIAL_AERONAUTICAL_REFERENCE", e["resolution_status"])
        self.assertEqual(0, sum(e["resolution_status"] == "NEEDS_SECONDARY_CONFIRMATION"
                                for e in enrichments))
        self.assertEqual(3088, self.audit["municipality_present"])
        self.assertEqual(87, self.audit["without_any_open_width"])
        self.assertEqual(52, self.audit["research_enrichment"]["municipality_rows"])
        self.assertEqual(5, self.audit["research_enrichment"]["official_width_rows"])
        self.assertEqual(82, self.audit["research_enrichment"]["width_airports_pending"])


    def test_simulation_width_coverage_and_average_provenance(self):
        # Planning values deliberately do not rewrite physical source observations.
        import math
        detailed = read(S / "game_runway_widths_3140.csv")
        imputed = read(S / "estimated_runway_widths_3140.csv")
        official = read(S / "researched_field_enrichments_3140.csv")
        official_ids = {e["source_airport_id"] for e in official
                        if e["field"] == "runway_width_m"}
        self.assertEqual(5, len(official_ids))
        self.assertEqual(3140, len(detailed))
        self.assertEqual(82, len(imputed))
        self.assertEqual(len(detailed), len({r["source_airport_id"] for r in detailed}))
        self.assertEqual(len(imputed), len({r["source_airport_id"] for r in imputed}))
        self.assertEqual({"OURAIRPORTS_SOURCE_REPORTED": 3053,
                          "OFFICIAL_RESEARCHED": 5,
                          "GAME_ESTIMATE_AVERAGE": 82},
                         dict(Counter(r["width_provenance"] for r in detailed)))
        airport_by_id = {r["source_airport_id"]: r for r in self.ports}
        width_by_id = {r["source_airport_id"]: r for r in detailed}
        self.assertEqual(set(airport_by_id), set(width_by_id))
        imputed_by_id = {r["source_airport_id"]: r for r in imputed}
        original_missing = {r["source_airport_id"] for r in self.ports
                            if r["source_open_runways_with_width"] == "0"}
        self.assertEqual(87, len(original_missing))
        self.assertEqual(original_missing - official_ids, set(imputed_by_id))
        source_runways = {r["source_runway_id"]: r for r in self.runways}
        by_country_bucket = defaultdict(list)
        by_bucket = defaultdict(list)

        def bucket(length):
            if length < 1800:
                return "1200-1799"
            if length < 2400:
                return "1800-2399"
            if length < 3000:
                return "2400-2999"
            return "3000+"

        for rw in self.runways:
            if rw["is_open"] != "YES" or rw["qualifies_paved_1200m"] != "YES":
                continue
            try:
                width = float(rw["width_m"])
            except ValueError:
                continue
            if not 10 <= width <= 100:
                continue
            nation = airport_by_id[rw["source_airport_id"]]["country_iso"]
            length_bucket = bucket(float(rw["length_m"]))
            by_country_bucket[(nation, length_bucket)].append(width)
            by_bucket[length_bucket].append(width)

        for airport_id, row in width_by_id.items():
            airport = airport_by_id[airport_id]
            self.assertEqual(airport["airport_name"], row["airport_name"])
            self.assertEqual(airport["country_iso"], row["country_iso"])
            self.assertEqual("SIMULATION_PLANNING_ONLY_NOT_REAL_WORLD_DISPATCH",
                             row["usage_restriction"])
            self.assertGreater(float(row["game_runway_width_m"]), 0)
            self.assertIn(row["reference_runway_id"], source_runways)
            self.assertEqual(airport_id, source_runways[row["reference_runway_id"]]
                             ["source_airport_id"])
            if airport_id in imputed_by_id:
                self.assertEqual(row, imputed_by_id[airport_id])
                self.assertEqual("GAME_ESTIMATE_AVERAGE", row["width_provenance"])
                ref_length = float(row["reference_runway_length_m"] or
                                   airport["source_screen_runway_length_m"])
                length_bucket = bucket(ref_length)
                peers = by_country_bucket[(airport["country_iso"], length_bucket)]
                if len(peers) >= 3:
                    sample = peers
                    method = "SAME_COUNTRY_AND_LENGTH_BAND_MEAN_ROUNDED_5M"
                else:
                    sample = by_bucket[length_bucket]
                    method = "WORLDWIDE_LENGTH_BAND_MEAN_ROUNDED_5M"
                mean = sum(sample) / len(sample)
                estimate = max(20, min(60, math.floor(mean / 5 + 0.5) * 5))
                self.assertEqual(method, row["estimate_method"])
                self.assertEqual(len(sample), int(row["donor_runway_count"]))
                self.assertAlmostEqual(mean, float(row["donor_raw_mean_width_m"]),
                                       delta=0.011)
                self.assertEqual(float(estimate), float(row["game_runway_width_m"]))
                self.assertFalse(row["evidence_url"])
            elif airport_id in official_ids:
                self.assertEqual("OFFICIAL_RESEARCHED", row["width_provenance"])
                self.assertTrue(row["evidence_url"])
            else:
                self.assertEqual("OURAIRPORTS_SOURCE_REPORTED",
                                 row["width_provenance"])
                self.assertEqual("NONE", row["estimate_method"])
                rw = source_runways[row["reference_runway_id"]]
                self.assertEqual(float(rw["width_m"]), float(row["game_runway_width_m"]))
        summary = self.audit["research_enrichment"]
        self.assertEqual(3140, summary["airports_with_effective_game_width"])
        self.assertEqual(82, summary["width_airports_estimated_for_simulation"])
        self.assertEqual(0, summary["width_airports_pending"])
        self.assertEqual(87, summary["width_source_data_still_missing"])


    def test_missing_official_codes_have_nonfabricated_game_keys(self):
        missing = read(S / "missing_identifier_game_handling_3140.csv")
        self.assertEqual(51, len(missing))
        self.assertEqual({"gps_code": 7, "icao_code": 15, "iata_code": 29},
                         dict(Counter(r["identifier_field"] for r in missing)))
        by_id = {p["source_airport_id"]: p for p in self.ports}
        pairs = set()
        for r in missing:
            key = (r["source_airport_id"], r["identifier_field"])
            self.assertNotIn(key, pairs)
            pairs.add(key)
            port = by_id[r["source_airport_id"]]
            self.assertEqual(port["country_iso"], r["country_iso"])
            self.assertEqual(port["airport_name"], r["airport_name"])
            self.assertEqual("", port[r["identifier_field"]])
            self.assertEqual("", r["official_code_value"])
            self.assertEqual(port[r["identifier_field"] + "_status"],
                             r["source_status"])
            self.assertEqual("NOT_REPORTED", r["source_status"])
            self.assertEqual(r["source_airport_id"], r["game_internal_airport_key"])
            self.assertEqual("OPTIONAL_SOURCE_CODE_USE_INTERNAL_ID", r["game_handling"])
            self.assertEqual("NOT_VERIFIED_NO_OFFICIAL_CODE_INVENTED",
                             r["assignment_verification"])
        self.assertEqual(51,
                         self.audit["research_enrichment"]["game_identifier_optional_source_gaps"])

if __name__ == "__main__":
    unittest.main()
