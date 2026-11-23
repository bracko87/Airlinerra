create or replace view airlinerra.airport_research_backlog
with (security_invoker=true) as
select
o.*,
case
 when o.access_review_not_started then 10
 when o.classification_review_not_started then 20
 when o.municipality_not_reported then 30
 when o.military_name_review_flag and o.civilian_evidence_class is null then 40
 when o.gps_code_not_reported then 50
 else 90 end as research_priority,
case
 when o.access_review_not_started then 'ACCESS_REVIEW_NOT_STARTED'
 when o.classification_review_not_started then 'CLASSIFICATION_REVIEW_NOT_STARTED'
 when o.municipality_not_reported then 'MUNICIPALITY_SOURCE_REVIEW'
 when o.military_name_review_flag and o.civilian_evidence_class is null then 'VERIFY_MILITARY_OR_DUAL_USE'
 when o.gps_code_not_reported then 'CHECK_UNREPORTED_GPS_IDENTIFIER'
 else 'FINAL_SIX_TIER_REVIEW_NOT_APPROVED' end as next_research_action
from airlinerra.airport_research_overview o;
revoke all on airlinerra.airport_research_backlog from public,anon,authenticated;
comment on view airlinerra.airport_research_backlog is 'Private deterministic nonplayable triage order; missing source codes and military names are review hints, not exclusion criteria.';
