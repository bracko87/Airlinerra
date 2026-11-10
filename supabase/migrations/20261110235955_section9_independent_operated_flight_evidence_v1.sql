-- Private append-only-compatible evidence contract for future trusted flight
-- execution engine. All business/clock/worker release gates remain OFF.
-- NO rows are created; NO signer is deployed; NO flight becomes active.
-- Only the independent engine may eventually produce an HMAC attestation
-- after actual game-day and physical flight-phase execution.
create table if not exists airlinerra_game.section9_independent_operated_flight_evidence_v1(
 world_id smallint not null default 1 check(world_id=1),
 airline_id uuid not null,
 aircraft_inventory_id uuid not null,
 schedule_id uuid not null,
 schedule_version integer not null check(schedule_version>0),
 flight_occurrence_id text not null,
 flight_local_date date not null,
 weekly_entry smallint not null check(weekly_entry between 1 and 7),
 phase text not null check(phase in ('departed','arrived')),
 event_id text primary key,
 scheduled_event_utc timestamptz not null,
 actual_event_utc timestamptz not null,
 operation_reference text not null,
 certified_clock_receipt_id text not null,
 evidence_source text not null default 'independent_trusted_flight_engine'
  check(evidence_source='independent_trusted_flight_engine'),
 signature text not null check(signature ~ '^[0-9a-f]{64}$'),
 recorded_at timestamptz not null default clock_timestamp(),
 constraint section9_independent_flight_event_id_exact
 check(event_id='operate-v1.'||replace(schedule_id::text,'-','')||'.'||
  to_char(flight_local_date,'YYYYMMDD')||'.'||weekly_entry::text||'.'||phase),
 constraint section9_independent_flight_occurrence_exact
 check(flight_occurrence_id=schedule_id::text||':'||
  to_char(flight_local_date,'YYYY-MM-DD')||':'||weekly_entry::text),
 constraint section9_independent_flight_operation_ref_format
 check(operation_reference ~ '^[A-Za-z0-9._:-]{12,128}$'),
 constraint section9_independent_flight_clock_ref_format
 check(certified_clock_receipt_id ~ '^[A-Za-z0-9._:-]{12,128}$'),
 constraint section9_independent_flight_evidence_timestamp
 check(actual_event_utc>=scheduled_event_utc and
  actual_event_utc<=scheduled_event_utc+interval '3 hours' and
  (actual_event_utc at time zone 'UTC')::date =
   (scheduled_event_utc at time zone 'UTC')::date),
 unique(airline_id,flight_occurrence_id,phase)
);

create index if not exists section9_independent_operation_aircraft_day_idx
on airlinerra_game.section9_independent_operated_flight_evidence_v1
(airline_id,aircraft_inventory_id,flight_local_date,phase);

alter table airlinerra_game.section9_independent_operated_flight_evidence_v1
enable row level security;
revoke all on airlinerra_game.section9_independent_operated_flight_evidence_v1
from public,anon,authenticated;
revoke insert,update,delete,truncate,references,trigger
on airlinerra_game.section9_independent_operated_flight_evidence_v1
from service_role;
grant select on airlinerra_game.section9_independent_operated_flight_evidence_v1
to service_role;

comment on table airlinerra_game.section9_independent_operated_flight_evidence_v1 is
'PRIVATE read-only-for-service-role signed event evidence reservoir, initially empty. Signed independent proof and certified game clock required; no producer, no automatic dispatch or refuelling/finance activation.';
