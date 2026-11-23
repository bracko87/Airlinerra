-- Licence 6 MRO is a single future game licence; existing EU and non-EU
-- maintenance entries remain only regional compliance references, not two
-- player-purchasable licences. Do not activate issuance or infrastructure.
UPDATE airlinerra_game.business_permission_catalog_v1
SET game_fee_usd=NULL,processing_game_days=NULL,
 purpose=CASE permission_code
   WHEN 'PART145_MAINTENANCE' THEN
    'EU Part-145 regulatory context for the future single Airlinerra Licence 6 Maintenance Organization Approval (MRO); not a separate in-game purchase.'
   ELSE
    'National non-EU maintenance regulatory context for the future single Airlinerra Licence 6 Maintenance Organization Approval (MRO); not a separate in-game purchase.'
 END,
 requirements='Future unified Licence 6: registered maintenance_mro subsidiary, suitable approved player facility, specialist certifying personnel, aircraft/check rating, tools and manuals, company funds plus audited operating reserve. Regional authority requirements are additional compliance checks, not second licence fees.',
 application_guidance='DESIGN ONLY, not available for application or issue. One future Licence 6 for MRO companies: free application; proposed $200,000 once on approval after 10 verified game days, subject to actual facilities and staff being implemented. Never treat this reference row as a separate paid player licence.',
 updated_at=clock_timestamp()
WHERE permission_code IN ('PART145_MAINTENANCE','NON_EU_MAINTENANCE')
  AND enabled_in_game=false;
