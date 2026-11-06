-- Secondary game-reference audit. Not an aviation-authority source.
-- Never auto-activate a curfew or noise ban from an unrelated simulator.
CREATE TABLE IF NOT EXISTS airlinerra_game.section5_airlinesim_secondary_airport_audit_v1(
 world_id smallint NOT NULL,
 airport_key text NOT NULL,
 iata text NOT NULL,
 icao text,
 secondary_source_url text NOT NULL,
 reported_night_ban text NOT NULL,
 reported_noise_policy text NOT NULL,
 primary_evidence_comparison text NOT NULL,
 evidence_checked_on date NOT NULL,
 game_auto_enforcement boolean NOT NULL DEFAULT false
  CONSTRAINT section5_airlinesim_secondary_never_autoblock CHECK(game_auto_enforcement=false),
 PRIMARY KEY(world_id,airport_key),
 CONSTRAINT section5_airlinesim_url_check CHECK(secondary_source_url LIKE 'https://free1.airlinesim.aero/%')
);
ALTER TABLE airlinerra_game.section5_airlinesim_secondary_airport_audit_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section5_airlinesim_secondary_airport_audit_v1 FROM PUBLIC,anon,authenticated;
INSERT INTO airlinerra_game.section5_airlinesim_secondary_airport_audit_v1
(world_id,airport_key,iata,icao,secondary_source_url,reported_night_ban,
 reported_noise_policy,primary_evidence_comparison,evidence_checked_on)
SELECT a.world_id,a.airport_key,p.iata_reported,p.icao_reported,src.url,src.night_ban,
 src.noise,src.comparison,DATE '2026-11-06'
FROM (VALUES
 ('AES','https://free1.airlinesim.aero/app/info/airports/2272',
 '00:01–05:59 simulator ban','No simulator noise restriction',
 'Simulated uniform overnight ban differs from existing primary-based research indicating no confirmed general recurring closure; do not apply without resolving the conflict.'),
 ('AAL','https://free1.airlinesim.aero/app/info/airports/664',
 'No simulator nighttime ban','Restricted to simulator Chapters III and IV',
 'Primary Aalborg operator publishes local operating hours and PPR conditions. AirlineSim no-night-ban label is not sufficient to override documented operating hours or to impose a Chapter without matched aircraft evidence.'),
 ('TRF','https://free1.airlinesim.aero/app/info/airports/2305',
 '00:01–05:59 simulator ban','No simulator noise restriction',
 'Primary Avinor operating/ATS hours vary by day and season, with permission exceptions. A single simulation blanket ban would be inaccurate.'),
 ('PED','https://free1.airlinesim.aero/app/info/airports/3966',
 '00:01–05:59 simulator ban','Restricted to simulator Chapters III and IV',
 'Primary Czech VFR/AIP provides operating windows and a documented Chapter 2 prohibition; simulator Chapter III/IV-only summary must not be applied to unverified variants.'),
 ('JSI','https://free1.airlinesim.aero/app/info/airports/1007',
 '00:01–05:59 simulator ban','Restricted to simulator Chapters III and IV',
 'Primary operator publishes varying seasonal/weekday service hours, not the same as the simplified simulator ban; aircraft-specific noise restrictions require primary evidence.')
) AS src(iata,url,night_ban,noise,comparison)
JOIN airlinerra_game.airport_reference_profiles p ON p.world_id=1 AND p.iata_reported=src.iata
JOIN airlinerra_game.approved_game_airports a ON a.world_id=p.world_id AND a.airport_key=p.airport_key
ON CONFLICT(world_id,airport_key) DO UPDATE SET
 secondary_source_url=excluded.secondary_source_url,
 reported_night_ban=excluded.reported_night_ban,
 reported_noise_policy=excluded.reported_noise_policy,
 primary_evidence_comparison=excluded.primary_evidence_comparison,
 evidence_checked_on=excluded.evidence_checked_on;

COMMENT ON TABLE airlinerra_game.section5_airlinesim_secondary_airport_audit_v1 IS
'Curfew/noise facts transcribed in short form for comparison with official sources; not authoritative or automatic game bans. Only five manually reviewed illustrative airports.';
