ALTER TABLE airlinerra.airport_icao_manual_review_20261027
 ADD COLUMN IF NOT EXISTS selected_traffic_type text;
ALTER TABLE airlinerra.airport_icao_manual_review_20261027
 DROP CONSTRAINT IF EXISTS airport_manual_review_traffic_type_six_check;
ALTER TABLE airlinerra.airport_icao_manual_review_20261027
 ADD CONSTRAINT airport_manual_review_traffic_type_three_check
 CHECK (selected_traffic_type IS NULL OR selected_traffic_type IN ('Passenger','Cargo','Both'));

ALTER TABLE airlinerra.airport_candidate_preapproval_pool
 ADD COLUMN IF NOT EXISTS traffic_type text;
ALTER TABLE airlinerra.airport_candidate_preapproval_pool
 DROP CONSTRAINT IF EXISTS airport_preapproval_traffic_type_three_check;
ALTER TABLE airlinerra.airport_candidate_preapproval_pool
 ADD CONSTRAINT airport_preapproval_traffic_type_three_check
 CHECK (traffic_type IN ('Passenger','Cargo','Both'));
COMMENT ON COLUMN airlinerra.airport_icao_manual_review_20261027.selected_traffic_type IS 'Owner-selected intended operation: Passenger, Cargo or Both. Remains blank until owner selects; checked airports also require category.';
COMMENT ON COLUMN airlinerra.airport_candidate_preapproval_pool.traffic_type IS 'Intended game traffic type Passenger, Cargo, Both. Required for PRE_APPROVED rows. Not evidence of actual commercial authorization.';