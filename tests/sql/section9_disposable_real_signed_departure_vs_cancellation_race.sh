#!/usr/bin/env bash
# Disposable-only actual original signed movement writer (patched in lab)
# racing actual original unflown cancellation in BOTH occurrence-lock orders.
# HMAC secret and operational prerequisites are synthetic lab records.
set -euo pipefail
test "$PGHOST" = 127.0.0.1
test "$PGPORT" = 5432
test "$PGUSER" = postgres
test "$PGDATABASE" = airlinerra_disposable
t="$(mktemp -d)";trap 'rm -rf "$t"' EXIT
owner='11111111-1111-4111-8111-111111111111'
s1='bcbcbcbc-1111-4111-8111-bcbcbcbcbcbc'
s2='cdcdcdcd-1111-4111-8111-cdcdcdcdcdcd'
o1='bcbcbcbc-2222-4222-8222-bcbcbcbcbcbc'
o2='cdcdcdcd-2222-4222-8222-cdcdcdcdcdcd'
f1="$s1:2026-11-21:1"
f2="$s2:2026-11-21:1"
event='2026-11-21T16:00:00Z'

signed_departure() {
 local schedule="$1" id="$2"
 cat <<SQL
SELECT airlinerra_game.section9_record_signed_operated_flight_movement_v1(
 '$owner'::uuid,'$schedule'::uuid,1,'2026-11-21'::date,1,'departed',
 '$event'::timestamptz,'$id',
 encode(extensions.hmac(
 convert_to(concat_ws(E'\\n',
 'airlinerra-operated-game-event-v1','1',
 '$owner','$schedule','1','2026-11-21','1','departed',
 '2026-11-21T16:00:00Z','$id'),'UTF8'),
 convert_to(repeat('t',80),'UTF8'),'sha256'),'hex'))->>'status';
SQL
}
# PostgreSQL E'\n' SQL literal must be a newline escape (one backslash).
# Quoted heredoc above uses double escaped backslash because it expands
# through Bash heredoc; verify generated SQL calls before running.
first_id='signed-movement-race-first-20261123'
second_id='signed-movement-race-second-20261123'

# CASE A — movement holds the exact occurrence's shared row lock first.
# The cancellation attempt is forced to wait and must see a signed
# departure committed before it decides whether cancellation is allowed.
cat >"$t/movement_first.sql" <<SQL
\\set ON_ERROR_STOP on
BEGIN;
SELECT id FROM airlinerra_game.section9_dated_flight_occurrences_v1
 WHERE id='$o1'::uuid FOR SHARE;
\\echo SIGNED-MOVEMENT-HAS-OCCURRENCE-LOCK
SELECT pg_sleep(2);
$(signed_departure "$s1" "$first_id")
COMMIT;
SQL
psql -X -qAt -v ON_ERROR_STOP=1 -f "$t/movement_first.sql" >"$t/movement_first.log" 2>&1 &
a=$!
for i in $(seq 1 80);do
 grep -qx SIGNED-MOVEMENT-HAS-OCCURRENCE-LOCK "$t/movement_first.log" 2>/dev/null && break
 sleep .1
done
grep -qx SIGNED-MOVEMENT-HAS-OCCURRENCE-LOCK "$t/movement_first.log"
psql -X -qAt -v ON_ERROR_STOP=1 -c \
 "SELECT airlinerra_game.section9_cancel_unflown_occurrence_v1('$o1'::uuid,'maximum_delay_exceeded')->>'status';" \
 >"$t/cancel_late.log" 2>&1 &
b=$!
wait "$a";wait "$b"
grep -qx operated_flight_departure_recorded "$t/movement_first.log" || {
 cat "$t/movement_first.log";exit 1;
}
grep -qx flight_already_operated_or_settled "$t/cancel_late.log" || {
 cat "$t/cancel_late.log";exit 1;
}

# CASE B — cancellation locks the occurrence first and commits the
# cancellation receipt. The actual signed movement function must wait
# for FOR SHARE, observe cancelled, and raise its original forbidden
# movement exception without writing an immutable event.
cat >"$t/cancel_first.sql" <<SQL
\\set ON_ERROR_STOP on
BEGIN;
SELECT id FROM airlinerra_game.section9_dated_flight_occurrences_v1
 WHERE id='$o2'::uuid FOR UPDATE;
\\echo CANCELLATION-HAS-OCCURRENCE-LOCK
SELECT pg_sleep(2);
SELECT airlinerra_game.section9_cancel_unflown_occurrence_v1(
 '$o2'::uuid,'maximum_delay_exceeded')->>'status';
COMMIT;
SQL
psql -X -qAt -v ON_ERROR_STOP=1 -f "$t/cancel_first.sql" >"$t/cancel_first.log" 2>&1 &
a=$!
for i in $(seq 1 80);do
 grep -qx CANCELLATION-HAS-OCCURRENCE-LOCK "$t/cancel_first.log" 2>/dev/null && break
 sleep .1
done
grep -qx CANCELLATION-HAS-OCCURRENCE-LOCK "$t/cancel_first.log"
signed_departure "$s2" "$second_id" >"$t/signed_cancelled.sql"
if psql -X -qAt -v ON_ERROR_STOP=1 -f "$t/signed_cancelled.sql" >"$t/move_late.log" 2>&1;then
 echo 'ERROR: cancelled flight accepted signed departure'
 cat "$t/move_late.log";exit 1
fi
wait "$a"
grep -qx flight_cancelled "$t/cancel_first.log"
grep -q SECTION9_CANCELLED_OCCURRENCE_MOVEMENT_FORBIDDEN "$t/move_late.log"

psql -X -qAt -v ON_ERROR_STOP=1 -c "
SELECT CASE WHEN
 (SELECT booking_status FROM airlinerra_game.section9_dated_flight_occurrences_v1
   WHERE id='$o1'::uuid)='open'
 AND (SELECT booking_status FROM airlinerra_game.section9_dated_flight_occurrences_v1
   WHERE id='$o2'::uuid)='cancelled'
 AND (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1
   WHERE flight_occurrence_id='$f1' AND phase='departed')=1
 AND (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1
   WHERE flight_occurrence_id='$f2')=0
 AND (SELECT count(*) FROM airlinerra_game.section9_flight_cancellation_receipts_v1
   WHERE occurrence_id='$o1'::uuid)=0
 AND (SELECT count(*) FROM airlinerra_game.section9_flight_cancellation_receipts_v1
   WHERE occurrence_id='$o2'::uuid)=1
 THEN 'PASS-ACTUAL-SIGNED-MOVEMENT-VS-CANCELLATION'
 ELSE 'FAIL-ACTUAL-SIGNED-MOVEMENT-VS-CANCELLATION' END;
" |grep -qx PASS-ACTUAL-SIGNED-MOVEMENT-VS-CANCELLATION

echo 'PASS original patched signed departure versus original cancellation in both lock orders; no cancelled+departed flight.'
