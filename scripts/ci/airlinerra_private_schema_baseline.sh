#!/usr/bin/env bash
# Disposable PRIVATE schema-only Airlinerra verification.
# Source is read-only. No SQL, data or credentials are published or uploaded.
set -Eeuo pipefail
set +x
umask 077

if [[ -z "$(printenv AIRLINERRA_SCHEMA_READONLY_URL 2>/dev/null || true)" ]]; then
  echo "BLOCKED: GitHub secret AIRLINERRA_SCHEMA_READONLY_URL is not configured." >&2
  exit 2
fi

# Capture the normalized URI only inside the shell variable; never print it.
# Some legitimate passwords contain raw square brackets, which urllib.parse
# interprets as IPv6 delimiters before any network operation occurs.
normalized_source_url="$(python3 - <<'PY'
from urllib.parse import urlsplit, parse_qs
import os, re, sys
raw = os.environ["AIRLINERRA_SCHEMA_READONLY_URL"]
# Supabase Connect can copy a shell command like:
#   psql 'postgresql://...'
# Or a DATABASE_URL=postgresql://... assignment.
# Accept these wrappers only if they contain an explicit PostgreSQL URI;
# never try to reconstruct a URL from unknown shell commands or credentials.
match = re.search(r"postgres(?:ql)?://\S+", raw, re.I)
uri = match.group(0).strip(chr(39)+chr(34)) if match else raw.strip()
try:
    if not match and raw != raw.strip():
        raise ValueError("whitespace")
    if re.search(r"\[(?:YOUR|PASSWORD|PASSWD|SECRET|REPLACE)[^\]]*\]", uri, re.I):
        print("BLOCKED: connection URL still contains a bracketed password placeholder.",file=sys.stderr)
        sys.exit(2)
    # Translate valid literal password brackets to their required URI encoding.
    # The target is a DNS hostname, never an IPv6 address.
    url = uri.replace("[", "%5B").replace("]", "%5D")
    parts = urlsplit(url)
    q = parse_qs(parts.query)
    assert parts.scheme in ("postgresql", "postgres")
    assert parts.hostname and parts.path == "/postgres"
    assert parts.username and parts.password
    sslmode = q.get("sslmode", [None])[0]
    assert sslmode in (None, "require", "verify-ca", "verify-full")
    direct = parts.hostname == "db.hwllkabgzaynalahvkpz.supabase.co"
    pooled = (parts.hostname.endswith(".pooler.supabase.com")
              and parts.username == "postgres.hwllkabgzaynalahvkpz"
              and parts.port == 5432)
    assert direct or pooled
except (AssertionError, ValueError, AttributeError):
    # Report only booleans / predefined buckets; never log the supplied URL,
    # the raw hostname, password, username or any unrecognized query value.
    safe = {}
    try:
        pp = urlsplit(raw.replace("[", "%5B").replace("]", "%5D"))
        h = pp.hostname or ""
        safe["scheme_ok"] = pp.scheme in ("postgresql", "postgres")
        safe["host_kind"] = ("direct" if h == "db.hwllkabgzaynalahvkpz.supabase.co"
                            else "pooler" if h.endswith(".pooler.supabase.com")
                            else "unknown")
        safe["db_ok"] = pp.path == "/postgres"
        safe["user_ok"] = pp.username == (
            "postgres.hwllkabgzaynalahvkpz" if safe["host_kind"] == "pooler" else "postgres")
        safe["password_present"] = bool(pp.password)
        safe["port_kind"] = ("5432" if pp.port == 5432 else
                             "6543" if pp.port == 6543 else
                             "omitted" if pp.port is None else "other")
        requested_ssl = parse_qs(pp.query).get("sslmode", [None])[0]
        safe["ssl_mode"] = ("secure" if requested_ssl in ("require", "verify-ca", "verify-full")
                            else "omitted" if requested_ssl is None else "unsupported")
    except (ValueError, AttributeError):
        safe = {"uri_parseable": False}
    safe["embedded_uri_present"] = bool(match)
    safe["looks_like_psql_command"] = bool(re.search(r"\bpsql\b", raw, re.I))
    safe["looks_like_key_value_connection"] = bool(
        re.search(r"\b(host|dbname|user|password)\s*=", raw, re.I))
    safe["looks_like_http_url"] = raw.lstrip().lower().startswith(("http://", "https://"))
    print("BLOCKED: Airlinerra connection URI validation failed: " +
          ", ".join(f"{k}={v}" for k,v in safe.items()),file=sys.stderr)
    sys.exit(2)
print(url) # Captured by command substitution, NEVER logged.
PY
)"
export AIRLINERRA_SCHEMA_READONLY_URL="$normalized_source_url"
echo "PASS: Airlinerra source URI validated; raw password brackets normalized; remote TLS enforced."

if [[ "$#" -gt 0 && "$1" == "--validate-only" ]]; then
  exit 0
fi

# GitHub-hosted runners are IPv4-only. Supabase Direct URLs commonly
# resolve to IPv6; the correct session pooler hostname is project-specific
# and MUST be copied from Supabase Connect (never guessed by region).
if [[ "$normalized_source_url" == *'@db.hwllkabgzaynalahvkpz.supabase.co'* ]]; then
  echo "BLOCKED: Direct Supabase connections use IPv6 and cannot be reached from this GitHub runner." >&2
  echo "Update AIRLINERRA_SCHEMA_READONLY_URL using Supabase Connect > Connection string > Session pooler (port 5432), then rerun." >&2
  exit 2
fi

for command_name in pg_dump psql supabase; do
  command -v "$command_name" >/dev/null || { echo "BLOCKED: missing $command_name" >&2; exit 2; }
done
pg_major="$(pg_dump --version | sed -E 's/.* ([0-9]+)\..*/\1/')"
[[ "$pg_major" =~ ^[0-9]+$ ]] && (( pg_major >= 17 )) || {
  echo "BLOCKED: pg_dump 17 or newer is required" >&2; exit 2;
}

tmp="$(mktemp -d)"
cleanup() {
  supabase stop --no-backup >/dev/null 2>&1 || true
  rm -rf -- "$tmp"
}
trap cleanup EXIT
trap 'echo "FAILED: schema-only restore did not complete. Production was not modified." >&2' ERR

export PGCONNECT_TIMEOUT=15 PGSSLMODE=require
export PGOPTIONS='-c default_transaction_read_only=on'
export SUPABASE_ACCESS_TOKEN=''
source_url="$AIRLINERRA_SCHEMA_READONLY_URL"

source_ok="$(psql "$source_url" -X -v ON_ERROR_STOP=1 -Atqc "
SELECT (
  current_database()='postgres'
  AND to_regnamespace('airlinerra_game') IS NOT NULL
  AND to_regnamespace('airlinerra') IS NOT NULL
  AND to_regclass('airlinerra.airport_expansion_next_eligibility_phase4') IS NOT NULL
  AND to_regprocedure('airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)') IS NOT NULL
)::int;")"
[[ "$source_ok" == 1 ]] || { echo "BLOCKED: unexpected database schema identity." >&2; exit 2; }

echo "Hashing remote structural definitions without returning SQL bodies..."
psql "$source_url" -X -v ON_ERROR_STOP=1 -At \
  -f tests/sql/airlinerra_private_schema_fingerprint.sql \
  >"$tmp/source-structure.hashes" 2>"$tmp/source-fingerprint.stderr" || {
  echo "BLOCKED: read-only source schema signature failed." >&2; exit 2;
}
[[ "$(wc -l < "$tmp/source-structure.hashes")" -eq 7 ]] || {
  echo "BLOCKED: source structural signature has missing categories." >&2; exit 2;
}

echo "Read-only pg_dump to private ephemeral CI directory..."
pg_dump --schema-only --no-owner --no-tablespaces \
  --schema=airlinerra --schema=airlinerra_game --schema=public \
  --file="$tmp/schema-only.sql" "$source_url" \
  2>"$tmp/dump.stderr" || {
    echo "BLOCKED: source schema dump failed; private database details withheld." >&2
    exit 2
  }
[[ -s "$tmp/schema-only.sql" ]] || { echo "BLOCKED: empty schema dump." >&2; exit 2; }
echo "Private schema captured (bytes only): $(wc -c < "$tmp/schema-only.sql")"
echo "Schema SHA-256: $(sha256sum "$tmp/schema-only.sql" | cut -d' ' -f1)"

unset PGOPTIONS
mv supabase/migrations "$tmp/original-repository-migrations"
mkdir -p supabase/migrations
echo "Starting isolated local Supabase without historical migration replay..."
supabase start -x studio,imgproxy,realtime,storage-api,postgres-meta,edge-runtime,logflare,vector,supavisor \
  >"$tmp/start.log" 2>&1 || {
    echo "BLOCKED: disposable Supabase startup failed; details withheld." >&2
    exit 2
  }

local_psql() {
  env PGPASSWORD=postgres PGSSLMODE=disable psql \
    -h 127.0.0.1 -p 54322 -U postgres -d postgres -X -v ON_ERROR_STOP=1 "$@"
}

echo "Restoring schema-only definitions into local Supabase..."
local_psql -q -f "$tmp/schema-only.sql" >"$tmp/restore.log" 2>&1 || {
  echo "BLOCKED: local restore rejected a schema dependency (private SQL withheld)." >&2
  exit 2
}

check="$(local_psql -Atqc "
SELECT (
  to_regclass('airlinerra.airport_expansion_next_eligibility_phase4') IS NOT NULL
  AND to_regclass('airlinerra_game.airlines') IS NOT NULL
  AND to_regprocedure('airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)') IS NOT NULL
  AND to_regprocedure('airlinerra_game.section9_record_signed_operated_flight_movement_v1(uuid,uuid,integer,date,integer,text,timestamptz,text,text)') IS NOT NULL
)::int;")"
[[ "$check" == 1 ]] || { echo "BLOCKED: local schema is missing required objects." >&2; exit 2; }

echo "Comparing live and disposable local schema fingerprints..."
local_psql -At -f tests/sql/airlinerra_private_schema_fingerprint.sql \
  >"$tmp/clone-structure.hashes" 2>"$tmp/clone-fingerprint.stderr" || {
  echo "BLOCKED: local structural signature failed." >&2; exit 2;
}
if ! cmp -s "$tmp/source-structure.hashes" "$tmp/clone-structure.hashes"; then
  echo "BLOCKED: schema-only clone differs structurally from source in one or more categories." >&2
  echo "Structural signatures not published; no source writes performed." >&2
  exit 2
fi
echo "PASS: seven structural categories match between remote and isolated local database."

echo "Applying repository forward-only corrections to local clone ONLY..."
local_psql -q -f "$tmp/original-repository-migrations/20261123200000_section9_signed_movement_cancellation_guard.sql" \
  >"$tmp/patch.log" 2>&1 || {
    echo "BLOCKED: signed-movement correction failed against cloned schema." >&2
    exit 2
  }
local_psql -q -f "$tmp/original-repository-migrations/20261123210000_section9_dispatch_traffic_permission_binding_fix.sql" \
  >>"$tmp/patch.log" 2>&1 || {
    echo "BLOCKED: dispatcher correction failed against cloned schema." >&2
    exit 2
  }

guards="$(local_psql -Atqc "
SELECT (
  position('SECTION9_SIGNED_DEPARTURE_OCCURRENCE_NOT_OPEN' in
    pg_get_functiondef('airlinerra_game.section9_record_signed_operated_flight_movement_v1(uuid,uuid,integer,date,integer,text,timestamptz,text,text)'::regprocedure)) > 0
  AND position('required_permission_code' in
    pg_get_functiondef('airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)'::regprocedure)) > 0
  AND NOT has_function_privilege('anon','airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)','EXECUTE')
  AND NOT has_function_privilege('authenticated','airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)','EXECUTE')
  AND NOT has_function_privilege('service_role','airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)','EXECUTE')
)::int;")"
[[ "$guards" == 1 ]] || { echo "BLOCKED: cloned forward corrections or grants fail." >&2; exit 2; }
echo "PASS: real schema-only baseline restored locally; two corrected functions verified."
echo "The dump is never uploaded, committed, archived or displayed."
