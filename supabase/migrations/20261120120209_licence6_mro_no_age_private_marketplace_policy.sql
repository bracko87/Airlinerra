-- Licence 6 MRO design alignment only: no live issuance and no infrastructure creation.
-- Single company licence covers internal plus third-party maintenance; marketplace
-- listing is optional and privately hidden unless player opts in.
UPDATE airlinerra_game.business_permission_catalog_v1
 SET requirements='Single future Licence 6 for a registered maintenance_mro subsidiary, with no minimum company age after registration. It covers own-group and third-party maintenance within approved scope. Specific infrastructure, staff roles, service capabilities and reserve amounts will be defined in a later design phase.',
 application_guidance='DESIGN ONLY. Free application available in the future as soon as the registered MRO meets readiness criteria; proposed $200,000 approval fee and 10 verified game days. The same licence covers internal and other-player aircraft. A future optional public service listing will default to private and allow the player to publish selected approved services and set a separate price per service. Not released.',
 updated_at=clock_timestamp()
 WHERE permission_code IN ('PART145_MAINTENANCE','NON_EU_MAINTENANCE')
 AND enabled_in_game=false;
