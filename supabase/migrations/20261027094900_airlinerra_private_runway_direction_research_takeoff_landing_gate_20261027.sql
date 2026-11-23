
ALTER TABLE airlinerra.runway_direction_facts
ADD COLUMN takeoff_status text NOT NULL DEFAULT 'UNVERIFIED'
CHECK (takeoff_status IN ('UNVERIFIED','PROHIBITED','CONDITIONAL','PERMITTED_BY_AIP')),
ADD COLUMN landing_status text NOT NULL DEFAULT 'UNVERIFIED'
CHECK (landing_status IN ('UNVERIFIED','PROHIBITED','CONDITIONAL','PERMITTED_BY_AIP'));
COMMENT ON COLUMN airlinerra.runway_direction_facts.takeoff_status IS 'Research source direction-specific operation gate; does not grant commercial airline permission.';
COMMENT ON COLUMN airlinerra.runway_direction_facts.landing_status IS 'Research source direction-specific operation gate; does not grant commercial airline permission.';
