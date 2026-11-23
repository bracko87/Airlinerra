#!/usr/bin/env bash
# Rejected migration must leave original function intact if the reviewed
# source has drifted, or if the same patch is applied twice.
# This lab test runs only in ephemeral PostgreSQL 17 after positive acceptance.
set -euo pipefail
test "$PGHOST" = '127.0.0.1'
test "$PGPORT" = '5432'
test "$PGUSER" = 'postgres'
test "$PGDATABASE" = 'airlinerra_disposable'
t="$(mktemp -d)"
trap 'rm -rf "$t"' EXIT
fn='airlinerra_game.section9_record_signed_operated_flight_movement_v1(uuid,uuid,integer,date,integer,text,timestamptz,text,text)'
candidate='supabase/migration_candidates/20261123_section9_signed_movement_cancellation_row_lock_review.sql'
original='tests/sql/section9_disposable_original_signed_movement_writer.sql'

sqlhash() {
 psql -X -qAt -v ON_ERROR_STOP=1 -c \
 "SELECT md5(pg_get_functiondef('$fn'::regprocedure));"
}

# The accepted reviewed patch cannot be re-applied after the old anchor is
# gone; it must not change function text on an attempted second application.
patched_hash="$(sqlhash)"
if psql -X -v ON_ERROR_STOP=1 -f "$candidate" >"$t/reapply.log" 2>&1; then
 echo 'FAIL: reviewed migration silently accepted reapplication'
 exit 1
fi
grep -q REVIEW_CANDIDATE_MOVEMENT_ORIGINAL_SOURCE_MISMATCH "$t/reapply.log"
test "$patched_hash" = "$(sqlhash)"

# Restore original source and introduce a harmless, syntactically valid
# unrelated source edit while keeping the target SELECT exactly unchanged.
psql -X -v ON_ERROR_STOP=1 -f "$original" >"$t/restore.log"
psql -X -v ON_ERROR_STOP=1 <<'SQL' >"$t/drift.log"
DO $drift$
DECLARE original_source text; changed_source text;
BEGIN
 SELECT pg_get_functiondef(
  'airlinerra_game.section9_record_signed_operated_flight_movement_v1(uuid,uuid,integer,date,integer,text,timestamptz,text,text)'::regprocedure)
 INTO original_source;
 IF position(' -- Serialize all physical movement updates by aircraft' IN original_source)=0
 THEN RAISE EXCEPTION 'DRIFT_FIXTURE_ANCHOR_MISSING';END IF;
 changed_source:=replace(original_source,
  ' -- Serialize all physical movement updates by aircraft',
  ' -- Safe unrelated drift marker for source fingerprint test'||E'\n'||
  ' -- Serialize all physical movement updates by aircraft');
 EXECUTE changed_source;
END $drift$;
SQL
drift_hash="$(sqlhash)"
if psql -X -v ON_ERROR_STOP=1 -f "$candidate" >"$t/drift_rejection.log" 2>&1; then
 echo 'FAIL: reviewed migration ignored unrelated source drift'
 exit 1
fi
grep -q REVIEW_CANDIDATE_MOVEMENT_ORIGINAL_SOURCE_MISMATCH "$t/drift_rejection.log"
test "$drift_hash" = "$(sqlhash)"

# Restore and apply the candidate once more so later CI state is protected.
psql -X -v ON_ERROR_STOP=1 -f "$original" >"$t/restore_again.log"
psql -X -v ON_ERROR_STOP=1 -f "$candidate" >"$t/reapply_correctly.log"
test "$patched_hash" = "$(sqlhash)"
echo 'PASS original movement review patch rejects duplicate application and unrelated function source drift without mutation.'
