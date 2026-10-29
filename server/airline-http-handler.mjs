/**
 * Prelaunch Node/server adapter for airline onboarding.
 * No listener, route registration or production deployment is created here.
 * Gate defaults off independently from website and database launch switches.
 * A real hosting integration must also enforce TLS, rate limiting and logging.
 */
const MAX_JSON_BYTES = 2048;
const API_PATH = '/api/v1/airlines';
const BASE_HEADERS = Object.freeze({
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store',
  'content-security-policy': "default-src 'none'",
  'x-content-type-options': 'nosniff',
  'referrer-policy': 'no-referrer'
});

function json(status, value, extraHeaders = {}) {
  return Object.freeze({
    status,
    headers: Object.freeze({ ...BASE_HEADERS, ...extraHeaders }),
    body: JSON.stringify(value)
  });
}

function header(headers, key) {
  if (!headers || typeof headers !== 'object') return null;
  for (const [name, value] of Object.entries(headers)) {
    if (name.toLowerCase() === key) return typeof value === 'string' ? value : null;
  }
  return null;
}

export function parseOnboardingBody(body) {
  if (typeof body !== 'string' || Buffer.byteLength(body, 'utf8') > MAX_JSON_BYTES) {
    throw new Error('Invalid or oversized JSON body.');
  }
  let object;
  try { object = JSON.parse(body); } catch { throw new Error('Invalid JSON body.'); }
  if (!object || Array.isArray(object) || typeof object !== 'object') {
    throw new Error('A JSON object is required.');
  }
  const expected = new Set(['worldId', 'airlineName', 'homeAirportKey', 'icaoCode', 'iataCode']);
  const keys = Object.keys(object);
  if (keys.length !== 5 || keys.some(key => !expected.has(key))) {
    throw new Error('Unexpected airline creation fields.');
  }
  return Object.freeze({
    worldId: object.worldId,
    airlineName: object.airlineName,
    homeAirportKey: object.homeAirportKey,
    icaoCode:object.icaoCode,
    iataCode:object.iataCode
  });
}

export function createAirlineHttpHandler({
  activationService,
  allowedOrigins = [],
  enabled = false
} = {}) {
  if (!activationService || typeof activationService.createAirline !== 'function') {
    throw new Error('Private activation service is required.');
  }
  if (!Array.isArray(allowedOrigins) ||
      allowedOrigins.some(origin => typeof origin !== 'string' || !/^https?:\/\/[^/]+$/.test(origin))) {
    throw new Error('Explicit HTTP origins are required.');
  }
  const allowed = new Set(allowedOrigins);

  return async function handle(request = {}) {
    if (request.path !== API_PATH) {
      return json(404, { error: 'Not found.' });
    }
    if (request.method !== 'POST') {
      return json(405, { error: 'Method not allowed.' }, { allow: 'POST' });
    }
    if (!enabled) {
      return json(503, { error: 'Airline onboarding is not available.' });
    }

    // No CORS support. Only an approved same-origin frontend may submit.
    // Authorization always uses a bearer token, never a browser cookie.
    const origin = header(request.headers, 'origin');
    if (!origin || !allowed.has(origin)) {
      return json(403, { error: 'Request origin is not approved.' });
    }
    const type = header(request.headers, 'content-type');
    if (!type || !/^application\/json(?:\s*;\s*charset=utf-8)?$/i.test(type)) {
      return json(415, { error: 'JSON content type is required.' });
    }
    const authorization = header(request.headers, 'authorization');
    const bearer = authorization && /^Bearer ([A-Za-z0-9._~-]{16,8192})$/.exec(authorization);
    if (!bearer) {
      return json(401, { error: 'Sign in to create an airline.' });
    }

    let data;
    try {
      data = parseOnboardingBody(request.body);
    } catch (error) {
      return json(error.message.includes('oversized') ? 413 : 400, { error: error.message });
    }

    try {
      const result = await activationService.createAirline({
        accessToken: bearer[1],
        request: data
      });
      return json(result.newlyCreated ? 201 : 200, {
        airlineId: result.airlineId,
        newlyCreated: result.newlyCreated,
        cashUsd: result.cashUsd,
        trialEndsAt: result.trialEndsAt
      });
    } catch (error) {
      // The body never includes raw SQL failures, access tokens, DB credentials
      // or table details. Distinguish only known user-actionable cases.
      if (error?.code === '23505') {
        return json(409, { error: 'The airline name or ICAO/IATA code is already taken in this world.' });
      }
      if (typeof error?.message === 'string' &&
          /verified player authentication|verified player/i.test(error.message)) {
        return json(401, { error: 'Please sign in again.' });
      }
      return json(503, { error: 'Airline creation could not be completed.' });
    }
  };
}
