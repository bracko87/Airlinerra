-- Provisional Airlinerra GAME-ONLY licence balance, based on $5M starter capital.
-- NO actual aviation authority fees are claimed by these amounts.
-- Catalog has an independent CHECK(enabled_in_game=false), which is kept.
-- All release policies remain disabled; this migration charges nothing.
-- 365 game day validity proposed for all three categories.
WITH proposed(permission_code,fee_usd,days) AS (
 VALUES
 ('AIR_OPERATOR_CERTIFICATE'::text,10000::numeric,3::integer),
 ('DOMESTIC_TRAFFIC',500,1),
 ('THIRD_FOURTH_FREEDOM',1500,2)
)
UPDATE airlinerra_game.business_permission_catalog_v1 c
SET game_fee_usd=p.fee_usd,processing_game_days=p.days,
    application_guidance='Provisional AIRLINERRA GAME fee/time balance. Not real aviation charge; issuance currently disabled until independent game authority and finance release. '||
      COALESCE(c.application_guidance,''),
    updated_at=clock_timestamp()
FROM proposed p
WHERE c.permission_code=p.permission_code
 AND c.enabled_in_game=false
 AND c.game_fee_usd IS NULL
 AND c.processing_game_days IS NULL;

INSERT INTO airlinerra_game.section9_game_permission_issuance_policy_v1
(permission_code,release_enabled,validity_game_days,policy_revision,
 reviewed_by,release_reference,released_at)
SELECT c.permission_code,false,365,1,'AIRLINERRA_GAME_BALANCING_DRAFT',
 null,null
FROM airlinerra_game.business_permission_catalog_v1 c
WHERE c.permission_code IN
 ('AIR_OPERATOR_CERTIFICATE','DOMESTIC_TRAFFIC','THIRD_FOURTH_FREEDOM')
 AND c.enabled_in_game=false
 AND c.game_fee_usd IS NOT NULL
 AND c.processing_game_days IS NOT NULL
ON CONFLICT(permission_code) DO NOTHING;
