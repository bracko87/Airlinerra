-- Isolated commercial duty schema for conflict guard tests.
SAVEPOINT storage_crew_guard;
CREATE TABLE airlinerra_game.section9_crew_plan_batches_v1(plan_id uuid PRIMARY KEY,airline_id uuid,status text);
CREATE TABLE airlinerra_game.section9_planned_crew_duties_v1(plan_id uuid,airline_id uuid,pilot_id uuid,employee_id uuid GENERATED ALWAYS AS(pilot_id) STORED,duty_end_utc timestamptz);
