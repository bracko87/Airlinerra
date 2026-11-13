-- SMATSA VFR AIP AD 2 LYBE 1.1-21/22, effective 2026-02-19:
-- 12L/30R normally handles takeoff/landing; 12R/30L is a taxi route
-- except as alternate during documented closure of 12L/30R.
-- Source evidence is not an issued NOTAM, current clearance or real-time status.
-- Inventory verification/operational_status intentionally remain unchanged.
INSERT INTO airlinerra_game.airport_runway_source_status_evidence
(world_id,airport_key,source_runway_id,reported_status,evidence_url,evidence_provenance,observed_on)
SELECT 1::smallint,'OURAIRPORTS:4610',data.source_id,data.status,
 'https://smatsa.rs/upload/vfraip/published/pdf/amdt/VFR_LY_Amdt_A_2026_02_en.pdf',
 'OFFICIAL_AIP_NORMAL_RUNWAY_USE: SMATSA VFR AIP AMDT 2/26, LYBE AD 2.20, effective 2026-02-19. '||data.note||
 ' This is reported procedural NORMAL use, not a live runway operational clearance or NOTAM check.',
 DATE '2026-11-13'
FROM (VALUES
 ('246233'::text,'open_reported_unverified'::text,
   '12L/30R main runway for routine takeoff and landing.'::text),
 ('506930'::text,'restricted_reported_unverified'::text,
   '12R/30L is taxi route during normal main-runway operations; alternate only when 12L/30R temporarily unavailable due to maintenance or incident, with published notice.'::text)
) AS data(source_id,status,note)
JOIN airlinerra_game.airport_runway_inventory r
 ON r.world_id=1 AND r.airport_key='OURAIRPORTS:4610'
 AND r.source_runway_id=data.source_id
WHERE (r.source_runway_id='246233' AND r.runway_designator='12L/30R')
   OR (r.source_runway_id='506930' AND r.runway_designator='12R/30L')
ON CONFLICT(world_id,airport_key,source_runway_id) DO NOTHING;
