-- Index the final release safety lookups. No changes to booking or balance data.
CREATE INDEX IF NOT EXISTS section9_occurrences_aircraft_departure_idx ON airlinerra_game.section9_dated_flight_occurrences_v1(aircraft_inventory_id,departure_utc) WHERE booking_status IN('open','closed');
CREATE INDEX IF NOT EXISTS section9_occurrences_open_departure_idx ON airlinerra_game.section9_dated_flight_occurrences_v1(world_id,departure_utc) WHERE booking_status='open';
CREATE INDEX IF NOT EXISTS section9_connection_outbound_active_idx ON airlinerra_game.section9_atomic_itinerary_holds_v1((physical_flight_ids[2])) WHERE status='preflight_only' AND cardinality(physical_flight_ids)=2;
