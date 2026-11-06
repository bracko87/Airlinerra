-- Toulouse-Blagnac 2027 decree: do not backdate the ban to 2026.
-- Source: https://www.legifrance.gouv.fr/loda/id/JORFTEXT000054341715/
-- Article 3 II/III and transitional Art 3 IV; effective Jan 1 2027.
WITH rules(code,kind,operation,starts,ends,is_block,active_from,active_until,description) AS (
VALUES
('TLS_2027_COMMERCIAL_DEPARTURES_23_06','SCHEDULED_DEPARTURES','departures','23:00'::time,'06:00'::time,true,'2027-01-01'::date,NULL::date,
'French decree Art 3 II: commercial departures cannot be scheduled 23:00–06:00 local starting January 2027.'),
('TLS_2027_COMMERCIAL_ARRIVALS_2330_2400','SCHEDULED_ARRIVALS','arrivals','23:30','00:00',true,'2027-01-01',NULL,
'French decree Art 3 III: commercial arrivals cannot be scheduled 23:30–00:00 local starting January 2027.'),
('TLS_2027_2028_EARLY_ARRIVALS_OPERATOR_QUOTA','NIGHT_QUOTA_OR_RESTRICTION','arrivals','00:00','06:00',false,'2027-01-01','2028-12-31',
'French decree Art 3 IV: until Dec 31 2028, maximum one qualifying scheduled arrival per airline and night subject to historic 2024 operation volume and 12-hour turnaround. Requires airline quota ledger and verification.'),
('TLS_2029_COMMERCIAL_ARRIVALS_00_06','SCHEDULED_ARRIVALS','arrivals','00:00','06:00',true,'2029-01-01',NULL,
'French decree Art 3 III: commercial arrivals 00:00–06:00 prohibited after the temporary 2027–2028 Art 3 IV exception ends.')
)
INSERT INTO airlinerra_game.section5_airport_time_restrictions_v1
(world_id,airport_key,airport_code,rule_code,rule_kind,affected_operations,local_start,local_end,
 weekday_iso,prohibit_normal_scheduled,game_auto_enforcement,exceptions_expected,
 source_url,evidence_authority,evidence_note,evidence_checked_on,active_from,active_until)
SELECT b.world_id,b.airport_key,b.airport_code,r.code,r.kind,r.operation,r.starts,r.ends,
 NULL::smallint[],r.is_block,r.is_block,true,b.curfew_source_url,
 'FRENCH_LEGIFRANCE_DECREE_29_JUNE_2026_ART_3_EFFECTIVE_2027',r.description,
 DATE '2026-11-06',r.active_from,r.active_until
FROM rules r
JOIN airlinerra_game.section5_airport_batch50_screen_v1 b ON b.world_id=1
 AND b.airport_code='TLS' AND b.curfew_source_url LIKE 'https://www.legifrance.gouv.fr/%'
ON CONFLICT(world_id,airport_key,rule_code) DO NOTHING;
