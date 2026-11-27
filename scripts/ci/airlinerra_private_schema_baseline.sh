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

# GitHub-hosted runners are IPv4-only; Direct Supabase resolves to IPv6.
# The project is eu-central-1. Supabase documents that shared session
# poolers use aws-[INDEX]-[REGION].pooler.supabase.com:5432. The precise
# index is not guaranteed, so test known provider endpoints and accept ONLY
# one that responds with Airlinerra's specific database schema identity.
# Never print candidates, URLs, connection errors or credentials.
if [[ "$normalized_source_url" == *'@db.hwllkabgzaynalahvkpz.supabase.co'* ]]; then
  echo "Direct IPv6 URI detected. Checking Supabase's official IPv4 session-pooler endpoints (private, read-only)."
  resolved=''
  probe_tmp="$(mktemp -d)"
  for pooler_index in 0 1; do
    candidate="$(
      AIRLINERRA_POOLER_INDEX="$pooler_index" python3 - <<'PY'
from urllib.parse import urlsplit, urlunsplit
import os
parts = urlsplit(os.environ["AIRLINERRA_SCHEMA_READONLY_URL"])
assert parts.hostname == "db.hwllkabgzaynalahvkpz.supabase.co"
assert parts.username == "postgres" and parts.password
index = os.environ["AIRLINERRA_POOLER_INDEX"]
assert index in ("0", "1")
host = "aws-" + index + "-eu-central-1.pooler.supabase.com"
netloc = "postgres.hwllkabgzaynalahvkpz:" + parts.password + "@" + host + ":5432"
query = parts.query
if "sslmode=" not in query:
    query += ("&" if query else "") + "sslmode=require"
print(urlunsplit(("postgresql", netloc, "/postgres", query, "")))
PY
    )"
    if PGCONNECT_TIMEOUT=8 PGSSLMODE=require \
       psql "$candidate" -X -v ON_ERROR_STOP=1 -Atqc "
          SELECT (
            current_database()='postgres'
            AND to_regnamespace('airlinerra_game') IS NOT NULL
            AND to_regnamespace('airlinerra') IS NOT NULL
            AND to_regclass('airlinerra.airport_expansion_next_eligibility_phase4') IS NOT NULL
            AND to_regprocedure('airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)') IS NOT NULL
          )::int;" > "$probe_tmp/stdout" 2>"$probe_tmp/stderr"; then
      if [[ "$(cat "$probe_tmp/stdout")" == 1 ]]; then
        resolved="$candidate"
        echo "PASS: official session-pooler candidate $pooler_index returned exact Airlinerra schema identity."
        break
      fi
      echo "POOLER CHECK $pooler_index: connected but wrong schema identity (rejected)." >&2
    else
      # Only output a whitelisted diagnosis, never the source/target host
      # string, username, SQL contents, connection URL or password.
      reason="other_connection_failure"
      if grep -Eiq 'password authentication failed|authentication failed|invalid password' "$probe_tmp/stderr"; then
        reason="authentication_rejected"
      elif grep -Eiq 'tenant or user not found|tenant not found|user not found' "$probe_tmp/stderr"; then
        reason="pooler_tenant_not_found"
      elif grep -Eiq 'could not translate host name|name or service not known|temporary failure in name resolution' "$probe_tmp/stderr"; then
        reason="pooler_dns_unavailable"
      elif grep -Eiq 'network is unreachable|connection refused|connection timed out|timeout expired' "$probe_tmp/stderr"; then
        reason="network_unreachable"
      elif grep -Eiq 'SSL|TLS|certificate' "$probe_tmp/stderr"; then
        reason="tls_negotiation_failed"
      fi
      echo "POOLER CHECK $pooler_index: $reason (URL and error details suppressed)." >&2
    fi
  done
  rm -rf -- "$probe_tmp"
  unset candidate
  if [[ -z "$resolved" ]]; then
    echo "BLOCKED: no verified project-specific IPv4 session-pooler connection. Use exact Session pooler URI from Supabase Connect." >&2
    exit 2
  fi
  normalized_source_url="$resolved"
  export AIRLINERRA_SCHEMA_READONLY_URL="$resolved"
  unset resolved
  echo "PASS: independently verified private Airlinerra schema via official IPv4 session pooler."
fi


# Some Supabase regions have several IPv4 pooler nodes. If the user's
# project-qualified URI targets one official pooler node, verify the alternate
# node privately; accept it ONLY after a successful Airlinerra schema query.
if [[ "$normalized_source_url" == *'@aws-0-eu-central-1.pooler.supabase.com:5432/'* ||
      "$normalized_source_url" == *'@aws-1-eu-central-1.pooler.supabase.com:5432/'* ]]; then
  alt_candidate="$(
    python3 - <<'PY'
from urllib.parse import urlsplit, urlunsplit
import os
url = os.environ["AIRLINERRA_SCHEMA_READONLY_URL"]
parts = urlsplit(url)
assert parts.username == "postgres.hwllkabgzaynalahvkpz"
assert parts.port == 5432
assert parts.hostname in (
    "aws-0-eu-central-1.pooler.supabase.com",
    "aws-1-eu-central-1.pooler.supabase.com"
)
replacement = ("aws-1-eu-central-1.pooler.supabase.com"
               if parts.hostname.startswith("aws-0-")
               else "aws-0-eu-central-1.pooler.supabase.com")
print(urlunsplit((parts.scheme,
   parts.netloc.replace(parts.hostname, replacement),
   parts.path, parts.query, parts.fragment)))
PY
  )"
  probe_tmp="$(mktemp -d)"
  if PGCONNECT_TIMEOUT=8 PGSSLMODE=require \
     psql "$alt_candidate" -X -v ON_ERROR_STOP=1 -Atqc "
       SELECT (
          current_database()='postgres'
          AND to_regnamespace('airlinerra_game') IS NOT NULL
          AND to_regnamespace('airlinerra') IS NOT NULL
          AND to_regclass('airlinerra.airport_expansion_next_eligibility_phase4') IS NOT NULL
          AND to_regprocedure('airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)') IS NOT NULL
       )::int;" >"$probe_tmp/answer" 2>"$probe_tmp/error"; then
    if [[ "$(cat "$probe_tmp/answer")" == 1 ]]; then
      normalized_source_url="$alt_candidate"
      export AIRLINERRA_SCHEMA_READONLY_URL="$alt_candidate"
      echo "PASS: alternate official IPv4 session pooler verified against Airlinerra schema identity."
    fi
  else
    reason="other"
    if grep -Eiq 'password authentication failed|authentication failed|invalid password' "$probe_tmp/error"; then
      reason="authentication_rejected"
    elif grep -Eiq 'tenant or user not found|tenant not found|user not found' "$probe_tmp/error"; then
      reason="tenant_not_found"
    elif grep -Eiq 'network is unreachable|connection refused|connection timed out|timeout expired' "$probe_tmp/error"; then
      reason="network_unreachable"
    fi
    echo "Alternate official session pooler: $reason (credentials suppressed)." >&2
  fi
  rm -rf -- "$probe_tmp"
  unset alt_candidate
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

source_roles_ok="$(psql "$source_url" -X -v ON_ERROR_STOP=1 -Atqc "
SELECT (
  NOT has_function_privilege('anon','airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)','EXECUTE')
  AND NOT has_function_privilege('authenticated','airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)','EXECUTE')
  AND NOT has_function_privilege('service_role','airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)','EXECUTE')
  AND NOT has_function_privilege('anon','airlinerra_game.section9_record_signed_operated_flight_movement_v1(uuid,uuid,integer,date,integer,text,timestamptz,text,text)','EXECUTE')
  AND NOT has_function_privilege('authenticated','airlinerra_game.section9_record_signed_operated_flight_movement_v1(uuid,uuid,integer,date,integer,text,timestamptz,text,text)','EXECUTE')
)::int;")"
[[ "$source_roles_ok" == 1 ]] || {
  echo "BLOCKED: live trusted flight writer/dispatcher grant safety does not pass." >&2; exit 2;
}
echo "PASS: live trusted-flight core function grants independently restricted."

# Source permission expectations are verified before the ACL-free dump.
# Never infer live ACLs from a schema-only restore.
release_source_acl="$(psql "$source_url" -X -v ON_ERROR_STOP=1 -Atqc "
SELECT (NOT EXISTS (
 SELECT 1 FROM unnest(ARRAY['anon','authenticated','service_role']) AS r(role_name)
 CROSS JOIN (VALUES
 ('airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)'),
 ('airlinerra_game.section9_record_signed_operated_flight_movement_v1(uuid,uuid,integer,date,integer,text,timestamptz,text,text)'),
 ('airlinerra_game.section9_issue_queued_game_clearance_v1(uuid,uuid,integer,date,text)'),
 ('airlinerra_game.section9_owned_candidate_slot_rights_preflight_v1(uuid,uuid,uuid,text,text,timestamptz,timestamptz,jsonb,text,text)'),
 ('airlinerra_game.section9_game_route_restrictions_valid_v1(text,text,jsonb)')
 ) AS f(sig) WHERE has_function_privilege(r.role_name,f.sig,'EXECUTE')
) AND NOT EXISTS (
 SELECT 1 FROM unnest(ARRAY['anon','authenticated','service_role']) AS r(role_name)
 WHERE has_table_privilege(r.role_name,'airlinerra_game.airport_unified_operations_v1','SELECT')
))::int;")"
[[ "$release_source_acl" == 1 ]] || { echo "BLOCKED: live release-target ACL differs." >&2; exit 2; }
echo "PASS: five live target function permissions and private unified airport view verified."

echo "Hashing remote structural definitions without returning SQL bodies..."
psql "$source_url" -X -v ON_ERROR_STOP=1 -At \
  -f tests/sql/airlinerra_private_schema_fingerprint.sql \
  >"$tmp/source-structure.hashes" 2>"$tmp/source-fingerprint.stderr" || {
  echo "BLOCKED: read-only source schema signature failed." >&2; exit 2;
}
[[ "$(wc -l < "$tmp/source-structure.hashes")" -eq 7 ]] || {
  echo "BLOCKED: source structural signature has missing categories." >&2; exit 2;
}

echo "Read-only pg_dump by dependency-safe sections (no table data or ACL restore)..."
# Four sections are required, rather than appending a whole private dump
# between two whole public dumps:
# 1. public app pre-data tables
# 2. private schemas, tables and trigger FUNCTIONS
# 3. public app post-data PRIMARY KEYS and TRIGGERS
# 4. private post-data foreign keys (including world1 FK references)
# This avoids both missing private trigger functions and missing public PKs.
for dump_section in pre-data post-data; do
  pg_dump --no-owner --no-tablespaces --no-privileges \
    --section="$dump_section" \
    --schema=airlinerra --schema=airlinerra_game \
    --file="$tmp/private-$dump_section.sql" "$source_url" \
    2>"$tmp/private-$dump_section.stderr" || {
      echo "BLOCKED: source private $dump_section dump failed (details suppressed)." >&2
      exit 2
    }
  pg_dump --no-owner --no-tablespaces --no-privileges \
    --section="$dump_section" \
    --table=public.airlinerra_game_worlds \
    --table=public.airlinerra_player_profiles \
    --table=public.airlinerra_site_status \
    --file="$tmp/public-$dump_section.sql" "$source_url" \
    2>"$tmp/public-$dump_section.stderr" || {
      echo "BLOCKED: source public-app $dump_section dump failed (details suppressed)." >&2
      exit 2
    }
  [[ -s "$tmp/private-$dump_section.sql" && -s "$tmp/public-$dump_section.sql" ]] || {
    echo "BLOCKED: schema section unexpectedly empty." >&2; exit 2;
  }
done
cat "$tmp/public-pre-data.sql" "$tmp/private-pre-data.sql" \
  "$tmp/public-post-data.sql" "$tmp/private-post-data.sql" \
  >"$tmp/schema-only.sql"
[[ -s "$tmp/schema-only.sql" ]] || { echo "BLOCKED: empty ordered schema." >&2; exit 2; }
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
# Collect ALL PostgreSQL error SQLSTATE codes from a disposable local restore
# in one pass, not one error per CI attempt. The complete SQL and diagnostics
# stay in temporary private runner storage and are destroyed on exit.
local_psql -q -v ON_ERROR_STOP=0 -v VERBOSITY=verbose \
  -f "$tmp/schema-only.sql" >"$tmp/restore.log" 2>&1 || true
if grep -Eq '(ERROR|FATAL): ' "$tmp/restore.log"; then
  python3 - "$tmp/restore.log" <<'PY'
from collections import Counter
from pathlib import Path
import re,sys
log=Path(sys.argv[1]).read_text(errors="replace")
codes=re.findall(r'(?:ERROR|FATAL):\s+([A-Z0-9]{5}):',log)
counts=Counter(codes)
print("BLOCKED: source schema-only SQL has local restore errors; classified SQLSTATEs (no SQL text):",file=sys.stderr)
for code,count in sorted(counts.items(),key=lambda x:(-x[1],x[0]))[:15]:
    print(f"  SQLSTATE {code}: {count} occurrences",file=sys.stderr)
print(f"  total_classified={len(codes)}; unclassified_error_lines={len(re.findall(r'(?:ERROR|FATAL): ',log))-len(codes)}",file=sys.stderr)
PY
  exit 2
fi

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

# The source ACL check above established that these three roles cannot execute
# these functions or select the existing private view. The dump drops ACLs,
# so reproduce this specific verified denial locally BEFORE applying migrations.
# This is not an assertion of full source role or grant parity.
local_psql -q >/dev/null <<'SQL'
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer) FROM PUBLIC,anon,authenticated,service_role;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_record_signed_operated_flight_movement_v1(uuid,uuid,integer,date,integer,text,timestamptz,text,text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_issue_queued_game_clearance_v1(uuid,uuid,integer,date,text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_owned_candidate_slot_rights_preflight_v1(uuid,uuid,uuid,text,text,timestamptz,timestamptz,jsonb,text,text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_game_route_restrictions_valid_v1(text,text,jsonb) FROM PUBLIC,anon,authenticated,service_role;
REVOKE SELECT ON airlinerra_game.airport_unified_operations_v1 FROM PUBLIC,anon,authenticated,service_role;
SQL

# Explicit manual storage schema rehearsal, never executed against the source.
if [[ "${AIRLINERRA_STORAGE_SCHEMA_REHEARSAL:-0}" == 1 ]]; then
  node scripts/ci/assemble_storage_schema_rehearsal.mjs "$tmp/storage-schema-rehearsal.sql"
  if ! local_psql -q -v VERBOSITY=verbose -f "$tmp/storage-schema-rehearsal.sql" >"$tmp/storage-rehearsal.log" 2>&1; then
    # Only public repository file markers and SQLSTATE are emitted.
    awk '/^STORAGE_SCHEMA_REHEARSAL aircraft_storage_[a-z_]+\.sql$/ { component=$2 } END { print "Blocked component: " component }' "$tmp/storage-rehearsal.log"
    grep -Eo 'ERROR: +[0-9A-Z]{5}:' "$tmp/storage-rehearsal.log" | sort -u || true
    echo "BLOCKED: storage schema composition failed; private SQL diagnostics withheld." >&2
    exit 2
  fi
  local_psql -Atqc "SELECT (to_regclass('airlinerra_game.aircraft_storage_facilities_v1') IS NULL)::int" | grep -qx 1
  echo "PASS: integrated storage schema-only transaction rolled back; no storage schema persisted on clone."
  exit 0
fi

# Preserve existing column order/types and the modern dispatcher definition.
# The dump intentionally excludes ACLs. Check live access separately and
# compare restored-clone behavior before and after; do not claim ACL parity.
local_psql -Atqc "
 SELECT md5(pg_get_functiondef('airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)'::regprocedure));
" >"$tmp/dispatcher-before"
local_psql -Atqc "
 SELECT attnum,attname,format_type(atttypid,atttypmod)
 FROM pg_attribute
 WHERE attrelid='airlinerra_game.airport_unified_operations_v1'::regclass
 AND attnum>0 AND NOT attisdropped ORDER BY attnum;
" >"$tmp/airport-columns-before"

echo "Applying exactly five forward-only release migrations to local clone ONLY..."
release_migrations=(
  20261123200000_section9_signed_movement_cancellation_guard.sql
  20261123210000_section9_dispatch_traffic_permission_binding_fix.sql
  20261124123000_section9_conservative_game_airport_restriction_alignment.sql
  20261124134500_section9_candidate_game_gate_vs_research_review.sql
  20261124135500_section9_game_clearance_issuer_prelock_schedule.sql
)
for pass in 1 2; do
  for migration in "${release_migrations[@]}"; do
    local_psql -q -f "$tmp/original-repository-migrations/$migration" >"$tmp/patch.log" 2>&1 || {
      echo "BLOCKED: local migration $migration failed on pass $pass (details suppressed)." >&2
      exit 2
    }
    echo "PASS: local migration $migration, pass $pass."
  done
  local_psql -At -f tests/sql/airlinerra_private_schema_fingerprint.sql >"$tmp/release-pass-$pass.hashes" 2>"$tmp/release-fingerprint.stderr"
done
cmp -s "$tmp/release-pass-1.hashes" "$tmp/release-pass-2.hashes" || { echo "BLOCKED: second pass changed structure." >&2; exit 2; }

local_psql -Atqc "
 SELECT md5(pg_get_functiondef('airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)'::regprocedure));
" >"$tmp/dispatcher-after"
cmp -s "$tmp/dispatcher-before" "$tmp/dispatcher-after" || { echo "BLOCKED: dispatcher changed despite no-op migration." >&2; exit 2; }
local_psql -Atqc "
 SELECT attnum,attname,format_type(atttypid,atttypmod)
 FROM pg_attribute
 WHERE attrelid='airlinerra_game.airport_unified_operations_v1'::regclass
 AND attnum>0 AND NOT attisdropped ORDER BY attnum;
" >"$tmp/airport-columns-after"
cmp -s "$tmp/airport-columns-before" "$tmp/airport-columns-after" || { echo "BLOCKED: airport view column signature changed." >&2; exit 2; }

guards="$(local_psql -Atqc "
WITH checks AS (
 SELECT
 pg_get_functiondef('airlinerra_game.section9_record_signed_operated_flight_movement_v1(uuid,uuid,integer,date,integer,text,timestamptz,text,text)'::regprocedure) AS movement,
 pg_get_functiondef('airlinerra_game.section9_owned_candidate_slot_rights_preflight_v1(uuid,uuid,uuid,text,text,timestamptz,timestamptz,jsonb,text,text)'::regprocedure) AS candidate,
 pg_get_functiondef('airlinerra_game.section9_issue_queued_game_clearance_v1(uuid,uuid,integer,date,text)'::regprocedure) AS issuer
)
SELECT (
 position('SECTION9_SIGNED_DEPARTURE_OCCURRENCE_NOT_ELIGIBLE' in movement)>0
 AND position('section9_effective_dispatch_window_v1' in movement)>0
 AND position('gameRestrictionGuardPassed' in candidate)>0
 AND position('researchDocumentationReviewPending' in candidate)>0
 AND position('section9_game_route_restrictions_valid_v1' in candidate)>0
 AND position('Serialize competing issuer requests' in issuer)>0
 AND position('FOR UPDATE OF sch' in issuer)>0
 AND position('extensions.hmac' in issuer)>0
 AND (SELECT reloptions @> ARRAY['security_invoker=true'] FROM pg_class WHERE oid='airlinerra_game.airport_unified_operations_v1'::regclass)
 AND (SELECT reloptions @> ARRAY['security_invoker=true'] FROM pg_class WHERE oid='airlinerra_game.section9_airport_game_restriction_alignment_v1'::regclass)
 AND NOT EXISTS (
 SELECT 1 FROM unnest(ARRAY['anon','authenticated','service_role']) AS r(role_name)
 CROSS JOIN (VALUES
 ('airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)'),
 ('airlinerra_game.section9_record_signed_operated_flight_movement_v1(uuid,uuid,integer,date,integer,text,timestamptz,text,text)'),
 ('airlinerra_game.section9_issue_queued_game_clearance_v1(uuid,uuid,integer,date,text)'),
 ('airlinerra_game.section9_owned_candidate_slot_rights_preflight_v1(uuid,uuid,uuid,text,text,timestamptz,timestamptz,jsonb,text,text)')
 ) AS fn(sig)
 WHERE has_function_privilege(r.role_name,fn.sig,'EXECUTE')
 )
 AND NOT EXISTS (
 SELECT 1 FROM unnest(ARRAY['anon','authenticated','service_role']) AS r(role_name)
 WHERE has_table_privilege(r.role_name,'airlinerra_game.section9_airport_game_restriction_alignment_v1','SELECT')
 OR has_table_privilege(r.role_name,'airlinerra_game.airport_unified_operations_v1','SELECT')
 )
)::int FROM checks;")"
[[ "$guards" == 1 ]] || { echo "BLOCKED: cloned forward corrections or grants fail." >&2; exit 2; }
echo "PASS: all five migrations applied twice on isolated schema; structural idempotence, unchanged modern dispatcher, stable airport columns and private grants verified."
echo "Schema-only rehearsal is not data restore, full ACL parity, or commercial flight acceptance."
echo "The dump is never uploaded, committed, archived or displayed."
