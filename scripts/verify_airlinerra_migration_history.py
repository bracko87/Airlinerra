#!/usr/bin/env python3
"""Verify Airlinerra migration filenames and immutable production-verified SQL.

This script has no network access. The manifest records 14 files that were
byte-for-byte compared with their original SQL bodies stored in the connected
Airlinerra Supabase migration history on 2026-11-23.
It does not assert that the remaining migration archive is production-ready.
"""
from __future__ import annotations
from pathlib import Path
import hashlib
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / "supabase" / "migrations"

PROVENANCE = [
  {
    "historical": "20261110171000_airlinerra_factory_order_stock_queue_reservation_v1.sql",
    "verified": "20261110150838_airlinerra_factory_order_stock_queue_reservation_v1.sql",
    "blob": "4f9319e2f722b9344f23e8cafaff43ce6f9dbe95"
  },
  {
    "historical": "20261110171000_group2_conditional_restriction_preview.sql",
    "verified": "20261110153827_group2_conditional_restriction_preview.sql",
    "blob": "3e0eed0c699ca755ac3885c139215c3086c28d2c"
  },
  {
    "historical": "20261110172500_airlinerra_factory_base_delivery_estimates_v1.sql",
    "verified": "20261110152703_airlinerra_factory_base_delivery_estimates_v1.sql",
    "blob": "c0364a97e38008ee92a69a16b91cb61f49c33c1a"
  },
  {
    "historical": "20261110172500_group2_aircraft_airport_readiness_preview.sql",
    "verified": "20261110153957_group2_aircraft_airport_readiness_preview.sql",
    "blob": "ddabc2551d1c499328bd24c011719564cb2719a9"
  },
  {
    "historical": "20261110184500_airlinerra_40_real_reference_seats_and_model_geometry_v1.sql",
    "verified": "20261110172004_airlinerra_40_real_reference_seats_and_model_geometry_v1.sql",
    "blob": "fe57f9d483f5ebc682bfe2bb61c2ec1a5f09c1c1"
  },
  {
    "historical": "20261110184500_group2_section4_23_batches_facility_game_closure.sql",
    "verified": "20261110122949_group2_section4_23_batches_facility_game_closure.sql",
    "blob": "b57840cefd9eaf9c75bbad9ae18e16ecbaf202b9"
  },
  {
    "historical": "20261110185000_aircraft_per_tail_private_images.sql",
    "verified": "20261110141358_aircraft_per_tail_private_images.sql",
    "blob": "2aecb15bec0a5732694e30d25268ee257728e305"
  },
  {
    "historical": "20261110185000_group2_combined_54week_route_safety_preview.sql",
    "verified": "20261110155455_group2_combined_54week_route_safety_preview.sql",
    "blob": "1320de2262aba22ab0f80378eccd20bb94707553"
  },
  {
    "historical": "20261110210000_airlinerra_installed_cabin_preferences_v1.sql",
    "verified": "20261110184615_airlinerra_installed_cabin_preferences_v1.sql",
    "blob": "8ccf208120b98fa3fc0d916b8e2eab6991f5eaa8"
  },
  {
    "historical": "20261110210000_group2_section5_initial_real_source_findings.sql",
    "verified": "20261110132252_group2_section5_initial_real_source_findings.sql",
    "blob": "56395d9eed2dbc419b0f885cf92797968011464e"
  },
  {
    "historical": "20261110224000_group2_section5_batch1_airlinesim_source_overrides.sql",
    "verified": "20261110135432_group2_section5_batch1_airlinesim_source_overrides.sql",
    "blob": "4fc6cdfe237fcd328688154de046c5538a127654"
  },
  {
    "historical": "20261110224000_open_horizon_world1.sql",
    "verified": "20261110164021_open_horizon_world1.sql",
    "blob": "8008e6df63d68d44d6fdf0250c663957e08ad928"
  },
  {
    "historical": "20261113230000_airlinerra_used_aircraft_cabin_snapshots_v1.sql",
    "verified": "20261113122857_airlinerra_used_aircraft_cabin_snapshots_v1.sql",
    "blob": "698bfe27ef192e8a831796bae4851d25168e229b"
  },
  {
    "historical": "20261113233000_airlinerra_factory_cabin_row_complete_defaults_v2.sql",
    "verified": "20261113125153_airlinerra_factory_cabin_row_complete_defaults_v2.sql",
    "blob": "2cab205d2be030004c07a38d38cbb80588771362"
  }
]

def git_blob_sha(contents: bytes) -> str:
    header = b"blob " + str(len(contents)).encode("ascii") + b"\\0"
    return hashlib.sha1(header + contents).hexdigest()

def main() -> int:
    errors = []
    paths = sorted(MIGRATIONS.glob("*.sql"))
    version_map = {}
    for path in paths:
        if not re.fullmatch(r"\\d{14}_.+\\.sql", path.name):
            errors.append(f"Invalid migration filename: {path.name}")
        version_map.setdefault(path.name[:14], []).append(path.name)
    for version, names in version_map.items():
        if len(names) != 1:
            errors.append(f"Duplicate migration timestamp {version}: {names}")
    for entry in PROVENANCE:
        old = MIGRATIONS / entry["historical"]
        new = MIGRATIONS / entry["verified"]
        if old.exists():
            errors.append(f"Old duplicate name reappeared: {old.name}")
        if not new.is_file():
            errors.append(f"Verified migration missing: {new.name}")
        elif git_blob_sha(new.read_bytes()) != entry["blob"]:
            errors.append(f"Authoritative SQL modified in place (use a forward-only migration): {new.name}")

    # Check runtime references, not historical docs or this manifest itself.
    for folder in (".github/workflows", "scripts", "server", "tests", "website"):
        root = ROOT / folder
        if not root.is_dir():
            continue
        for file in root.rglob("*"):
            if not file.is_file() or file == Path(__file__) or file.stat().st_size > 3_000_000:
                continue
            if file.suffix not in (".py", ".mjs", ".js", ".ts", ".yml", ".yaml", ".sql", ".json", ".md"):
                continue
            try:
                body = file.read_text(encoding="utf8")
            except UnicodeDecodeError:
                continue
            for entry in PROVENANCE:
                if entry["historical"] in body:
                    errors.append(f"Stale migration filename reference in {file.relative_to(ROOT)}: {entry['historical']}")

    if errors:
        print("\\n".join("BLOCKER: " + s for s in errors))
        return 1
    print(f"PASS: {len(paths)} unique migration versions; 14 byte-verified historical SQL bodies preserved")
    print("NOTE: This is provenance/integrity validation, not proof of full local database replay.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
