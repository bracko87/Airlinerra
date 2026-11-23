create table if not exists airlinerra.airport_expansion_final_decision_queue (
 airport_key text primary key references airlinerra.airport_registry(airport_key),
 assessment_group text not null,
 decision_status text not null check(decision_status in ('PENDING_EVIDENCE','REVIEW_HOLD','EXCLUSION_REVIEW','ELIGIBLE_FOR_FINAL_VERIFICATION','ACCEPT','REJECT')),
 blocker text not null,
 has_paved_runway_observation boolean not null,
 existing_phase3_status text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
insert into airlinerra.airport_expansion_final_decision_queue(airport_key,assessment_group,decision_status,blocker,has_paved_runway_observation,existing_phase3_status)
select r.airport_key,
case when not exists(select 1 from airlinerra.airport_runway_observations o where o.airport_key=r.airport_key and o.length_m>=1200 and upper(o.surface) ~ '(ASP|CON|BIT|PAVED)') then 'MISSING_QUALIFYING_RUNWAY_OBSERVATION'
when s.selection_status='PROVISIONAL_EXCLUSION_REVIEW' then 'PROVISIONAL_EXCLUSION'
when s.airport_key is null then 'UNREVIEWED_WITH_RUNWAY_OBSERVATION'
else 'PREVIOUSLY_REVIEWED_UNRESOLVED' end,
case when s.selection_status='PROVISIONAL_EXCLUSION_REVIEW' then 'EXCLUSION_REVIEW'
when s.airport_key is not null then 'REVIEW_HOLD'
else 'PENDING_EVIDENCE' end,
case when not exists(select 1 from airlinerra.airport_runway_observations o where o.airport_key=r.airport_key and o.length_m>=1200 and upper(o.surface) ~ '(ASP|CON|BIT|PAVED)') then 'Independent qualifying paved-runway evidence missing'
when s.selection_status='PROVISIONAL_EXCLUSION_REVIEW' then 'Existing potential exclusion must be adjudicated'
when s.airport_key is not null then 'Resolve recorded review hold and confirm current runway operation'
else 'Confirm current operational status and independent source before admission' end,
exists(select 1 from airlinerra.airport_runway_observations o where o.airport_key=r.airport_key and o.length_m>=1200 and upper(o.surface) ~ '(ASP|CON|BIT|PAVED)'),
s.selection_status
from airlinerra.airport_registry r left join airlinerra.airport_expansion_selection_phase3 s on s.airport_key=r.airport_key
where not exists(select 1 from airlinerra.airport_world_activation a where a.airport_key=r.airport_key and a.world_number=1 and a.active)
on conflict (airport_key) do nothing;