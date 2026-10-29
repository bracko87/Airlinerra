/**
 * Backend-only airline activation adapter. NOT imported by the static website.
 * No production endpoint is registered by this module.
 * Never expose a DB connection string, elevated key or this RPC to browsers.
 */
import { STARTING_CAPITAL_USD, STARTING_AIRCRAFT_COUNT } from './account-trial-policy.mjs';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const AIRPORT_KEY = /^(?:OURAIRPORTS:[1-9]\d{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/u;
export const AIRLINE_ACTIVATION_SQL =
  'select airline_id, newly_created, starting_balance_usd, trial_ends_at ' +
  'from airlinerra_game.create_airline_with_codes($1::uuid,$2::smallint,$3::text,$4::text,$5::text,$6::text)';

export function validatedActivationRequest(request) {
  if (request === null || typeof request !== 'object' || Array.isArray(request)) {
    throw new Error('Invalid airline creation request.');
  }
  const worldId = request.worldId;
  if (!Number.isInteger(worldId) || worldId < 1 || worldId > 3) {
    throw new Error('Invalid world ID.');
  }
  if (typeof request.airlineName !== 'string') {
    throw new Error('Invalid airline name.');
  }
  const name = request.airlineName.trim().replace(/\s+/gu,' ');
  if (name.length < 3 || name.length > 80 || /[\x00-\x1f\x7f<>]/u.test(name)) {
    throw new Error('Invalid airline name.');
  }
  const icaoCode=String(request.icaoCode||'').trim().toUpperCase();
  const iataCode=String(request.iataCode||'').trim().toUpperCase();
  if(!/^[A-Z]{3}$/.test(icaoCode))throw new Error('ICAO code must contain 3 letters.');
  if(!/^[A-Z0-9]{2}$/.test(iataCode)||!/\p{L}/u.test(iataCode))throw new Error('IATA code must contain 2 letters or a letter and number.');
  const airportKey = request.homeAirportKey;
  if (typeof airportKey !== 'string' || !AIRPORT_KEY.test(airportKey)) {
    throw new Error('Invalid home airport key.');
  }
  return Object.freeze({
    worldId,
    airlineName:name,
    homeAirportKey:airportKey,
    icaoCode,iataCode
  });
}

export function verifiedPlayerId(data) {
  const user = data?.user;
  // getUser performs an Auth server check, not a locally decoded JWT.
  if (data?.error || !user || !UUID.test(user.id) ||
      user.is_anonymous === true || !user.email_confirmed_at) {
    throw new Error('Verified player authentication is required.');
  }
  return user.id.toLowerCase();
}

/**
 * This service is private. The actual deployment must provide a trusted
 * server-side Supabase Auth verifier (auth.getUser(accessToken)) and a DB pool
 * with privilege to run the private SECURITY INVOKER function.
 */
export function createAirlineActivationService({
  verifyUserToken, database, enabled = false
} = {}) {
  if (typeof verifyUserToken !== 'function' ||
      !database || typeof database.connect !== 'function') {
    throw new Error('Trusted authentication verifier and PostgreSQL pool are required.');
  }

  async function createAirline({ accessToken, request } = {}) {
    if (!enabled) throw new Error('Airlinerra airline activation is disabled.');
    if (typeof accessToken !== 'string' || accessToken.length < 16) {
      throw new Error('Verified player authentication is required.');
    }
    // Do not accept playerId from the request. Auth server verifies the token.
    const playerId = verifiedPlayerId(await verifyUserToken(accessToken));
    const valid = validatedActivationRequest(request);
    const client = await database.connect();
    let started = false;
    try {
      await client.query('BEGIN');
      started = true;
      // This is ONE private PostgreSQL function call. All membership, airline,
      // ledger and trial writes occur inside that same transaction.
      const result = await client.query(AIRLINE_ACTIVATION_SQL, [
        playerId, valid.worldId, valid.airlineName, valid.homeAirportKey,valid.icaoCode,valid.iataCode
      ]);
      if (!Array.isArray(result.rows) || result.rows.length !== 1) {
        throw new Error('Airline activation returned an invalid result.');
      }
      const row = result.rows[0];
      if (!UUID.test(row.airline_id) ||
          typeof row.newly_created !== 'boolean' ||
          !/^\d+(\.\d+)?$/u.test(String(row.starting_balance_usd))) {
        throw new Error('Airline activation returned invalid data.');
      }
      await client.query('COMMIT');
      started = false;
      return Object.freeze({
        airlineId:row.airline_id,
        newlyCreated:row.newly_created,
        cashUsd:String(row.starting_balance_usd), // exact decimal, never JS floating-point
        trialEndsAt:row.trial_ends_at
      });
    } catch (error) {
      if (started) {
        try { await client.query('ROLLBACK'); } catch { /* report original failure */ }
      }
      throw error;
    } finally {
      client.release();
    }
  }

  return Object.freeze({
    createAirline,
    rules:Object.freeze({
      startingCapitalUsd:STARTING_CAPITAL_USD,
      startingAircraftCount:STARTING_AIRCRAFT_COUNT
    })
  });
}
