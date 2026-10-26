/**
 * Backend-only airline activation adapter. NOT imported by the static website.
 * No production endpoint is registered by this module.
 * Never expose a DB connection string, elevated key or this RPC to browsers.
 */
import { STARTING_CAPITAL_USD, STARTING_AIRCRAFT_COUNT } from './account-trial-policy.mjs';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MAX_BIGINT = 9223372036854775807n;
export const AIRLINE_ACTIVATION_SQL =
  'select airline_id, newly_created, starting_balance_usd, trial_ends_at ' +
  'from airlinerra_game.create_airline_once($1::uuid,$2::smallint,$3::text,$4::bigint)';

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
  const rawId = request.homeAirportSourceId;
  if ((typeof rawId !== 'number' && typeof rawId !== 'string') ||
      (typeof rawId === 'number' && !Number.isSafeInteger(rawId)) ||
      !/^[1-9]\d{0,18}$/u.test(String(rawId))) {
    throw new Error('Invalid home airport identifier.');
  }
  const airport = BigInt(rawId);
  if (airport > MAX_BIGINT) throw new Error('Invalid home airport identifier.');
  return Object.freeze({
    worldId,
    airlineName:name,
    homeAirportSourceId:airport.toString()
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
        playerId, valid.worldId, valid.airlineName, valid.homeAirportSourceId
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
