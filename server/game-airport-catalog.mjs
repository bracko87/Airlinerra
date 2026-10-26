/**
 * Airlinerra World 1 home-airport directory — PRIVATE backend adapter.
 *
 * This is an airport lookup, not an airline/game activation authority.
 * The view contains exactly the owner's original 3,140 airport release.
 * No public REST endpoint or service-role/browser secret is created here.
 * The airline-creation transaction must separately recheck its own
 * airlinerra_game.approved_game_airports roster after the account schema
 * and one-time airport sync are installed by the registration workstream.
 */
const CATEGORIES = new Set([
  'Local', 'Regional', 'Medium', 'Large', 'Major Hub', 'Mega Hub'
]);
const MAX_BIGINT = 9223372036854775807n;

export const COUNTRY_DIRECTORY_SQL =
  'select country_iso, count(*)::integer as airport_count ' +
  'from airlinerra.airport_game_world1_registration_source ' +
  'where world_id = $1::smallint group by country_iso order by country_iso';

export const HOME_AIRPORT_PAGE_SQL =
  'select world_id,home_airport_source_id,airport_key,airport_code,' +
  'airport_name,country_iso,municipality,provisional_game_category ' +
  'from airlinerra.airport_game_world1_registration_source ' +
  'where world_id=$1::smallint and country_iso=$2::text ' +
  'and home_airport_source_id>$3::bigint ' +
  'order by home_airport_source_id asc limit $4::integer';

export const HOME_AIRPORT_LOOKUP_SQL =
  'select world_id,home_airport_source_id,airport_key,airport_code,' +
  'airport_name,country_iso,municipality,provisional_game_category ' +
  'from airlinerra.airport_game_world1_registration_source ' +
  'where world_id=$1::smallint and home_airport_source_id=$2::bigint limit 2';

function worldOne(worldId) {
  if (worldId !== 1) throw new Error('Only World 1 has an authorized airport catalog.');
  return 1;
}

function bigintId(value, allowZero = false) {
  if ((typeof value !== 'string' && typeof value !== 'number' && typeof value !== 'bigint') ||
      (typeof value === 'number' && !Number.isSafeInteger(value))) {
    throw new Error('Invalid numeric airport ID.');
  }
  const raw = String(value);
  if (!/^(0|[1-9][0-9]{0,18})$/.test(raw)) throw new Error('Invalid numeric airport ID.');
  const n = BigInt(raw);
  if (n > MAX_BIGINT || (!allowZero && n===0n)) {
    throw new Error('Invalid numeric airport ID.');
  }
  return n.toString();
}

export function validatedCountryRequest({ worldId = 1, countryIso, afterSourceId = '0', limit = 100 } = {}) {
  worldOne(worldId);
  if (typeof countryIso !== 'string' || !/^[A-Z]{2}$/.test(countryIso)) {
    throw new Error('Invalid airport country code.');
  }
  if (!Number.isInteger(limit) || limit < 1 || limit > 100) {
    throw new Error('Airport page limit must be 1-100.');
  }
  return Object.freeze({worldId:1,countryIso,afterSourceId:bigintId(afterSourceId,true),limit});
}

export function validatedGameAirportRow(row) {
  if (!row || typeof row !== 'object' || Number(row.world_id)!==1) {
    throw new Error('Invalid game airport world.');
  }
  const id = bigintId(row.home_airport_source_id);
  if (row.airport_key !== 'OURAIRPORTS:' + id ||
      typeof row.airport_name !== 'string' || row.airport_name.trim().length===0 ||
      typeof row.airport_code !== 'string' || row.airport_code.trim().length===0 ||
      typeof row.country_iso !== 'string' || !/^[A-Z]{2}$/.test(row.country_iso) ||
      !CATEGORIES.has(row.provisional_game_category)) {
    throw new Error('Invalid game airport identity or category.');
  }
  return Object.freeze({
    worldId:1,
    homeAirportSourceId:id,
    airportKey:row.airport_key,
    code:row.airport_code,
    name:row.airport_name,
    countryIso:row.country_iso,
    municipality:typeof row.municipality==='string' ? row.municipality : null,
    provisionalCategory:row.provisional_game_category
  });
}

export function createGameAirportCatalogService({ database, enabled = false } = {}) {
  if (!database || typeof database.connect !== 'function') {
    throw new Error('An authorized server-side PostgreSQL connection pool is required.');
  }
  async function run(sql,params) {
    if (!enabled) throw new Error('Airlinerra airport catalog backend is disabled.');
    const client = await database.connect();
    try {
      const result = await client.query(sql,params);
      if (!result || !Array.isArray(result.rows)) throw new Error('Invalid airport catalog response.');
      return result.rows;
    } finally {
      client.release();
    }
  }
  return Object.freeze({
    async listCountries({ worldId = 1 } = {}) {
      worldOne(worldId);
      const rows=await run(COUNTRY_DIRECTORY_SQL,[1]);
      const seen=new Set();
      return Object.freeze(rows.map(row=>{
        const iso=row?.country_iso;
        const count=Number(row?.airport_count);
        if (typeof iso!=='string' || !/^[A-Z]{2}$/.test(iso) ||
            seen.has(iso) || !Number.isSafeInteger(count) || count<1) {
          throw new Error('Invalid game airport country directory.');
        }
        seen.add(iso);
        return Object.freeze({countryIso:iso,airportCount:count});
      }));
    },
    async listAirports(input) {
      const req=validatedCountryRequest(input);
      const rows=await run(HOME_AIRPORT_PAGE_SQL,[
        req.worldId,req.countryIso,req.afterSourceId,req.limit
      ]);
      if (rows.length>req.limit) throw new Error('Unexpected airport page size.');
      const checked=rows.map(validatedGameAirportRow);
      let last=BigInt(req.afterSourceId);
      for(const a of checked) {
        const n=BigInt(a.homeAirportSourceId);
        if (a.countryIso!==req.countryIso || n<=last) {
          throw new Error('Airport catalog page violates country or cursor scope.');
        }
        last=n;
      }
      return Object.freeze(checked);
    },
    async lookupAirport({ worldId = 1, homeAirportSourceId } = {}) {
      worldOne(worldId);
      const id=bigintId(homeAirportSourceId);
      const rows=await run(HOME_AIRPORT_LOOKUP_SQL,[1,id]);
      if (rows.length>1) throw new Error('Duplicate game airport identity.');
      if (!rows.length) return null;
      const airport=validatedGameAirportRow(rows[0]);
      if (airport.homeAirportSourceId!==id) throw new Error('Airport source identifier mismatch.');
      return airport;
    }
  });
}
