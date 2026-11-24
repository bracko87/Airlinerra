"""Race the deployed private certificate issuer using SIX local PG17 connections.

Disposable fixture only: fail before connecting if run outside the CI test DB.
No production credentials or private HMAC keys are provided to this script.
"""
import concurrent.futures
import os
import subprocess
from collections import Counter

if os.environ.get("PGDATABASE") != "airlinerra_disposable":
    raise SystemExit("Refusing non-disposable database")
if os.environ.get("PGHOST") != "127.0.0.1":
    raise SystemExit("Refusing non-local database")

query = (
    "SELECT airlinerra_game.section9_issue_queued_game_clearance_v1("
    "'11111111-1111-4111-8111-111111111111',"
    "'44444444-4444-4444-8444-444444444444',"
    "1,DATE '2026-11-24','operator_licence')->>'status';"
)

def call_issuer(_):
    run = subprocess.run(
        ["psql", "-X", "-qAt", "-v", "ON_ERROR_STOP=1", "-c", query],
        capture_output=True, text=True, timeout=40, check=False,
    )
    if run.returncode != 0:
        raise RuntimeError("Concurrent disposable issuer failed: " + run.stderr[-500:])
    return run.stdout.strip()

with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
    results = list(pool.map(call_issuer, range(6)))

observed = Counter(results)
expected = Counter({
    "certification_event_recorded": 1,
    "certification_event_replayed": 5,
})
print("Six concurrent issuer results:", dict(observed))
if observed != expected:
    raise SystemExit("Expected one recorded certificate and five idempotent replays")
