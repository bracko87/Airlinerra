import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createAirlineHttpHandler, parseOnboardingBody
} from '../server/airline-http-handler.mjs';

const PATH = '/api/v1/airlines';
const ORIGIN = 'http://localhost:5187';
const TOKEN = 'test-only-bearer-access-token-123';
const BODY = JSON.stringify({
  worldId: 1,
  airlineName: 'Aurelia Airways',
  homeAirportKey: 'OURAIRPORTS:101'
});

function request(overrides = {}) {
  return {
    path: PATH,
    method: 'POST',
    headers: {
      origin: ORIGIN,
      'content-type': 'application/json; charset=utf-8',
      authorization: 'Bearer ' + TOKEN
    },
    body: BODY,
    ...overrides
  };
}

function fixture(enabled = false, behavior = null) {
  const calls = [];
  const service = {
    async createAirline(payload) {
      calls.push(payload);
      if (behavior) return behavior(payload);
      return {
        airlineId: '22222222-2222-4222-8222-222222222222',
        newlyCreated: true,
        cashUsd: '5000000.00',
        trialEndsAt: '2026-11-02T08:00:00.000Z'
      };
    }
  };
  return {
    calls,
    handle: createAirlineHttpHandler({
      activationService: service,
      allowedOrigins: [ORIGIN],
      enabled
    })
  };
}

test('HTTP onboarding is disabled by default, with no downstream calls', async () => {
  const { handle, calls } = fixture();
  const output = await handle(request());
  assert.equal(output.status, 503);
  assert.equal(calls.length, 0);
  assert.equal(output.headers['cache-control'], 'no-store');
  assert.equal(output.headers['content-security-policy'], "default-src 'none'");
});

test('only the exact POST path is accepted', async () => {
  const { handle, calls } = fixture(true);
  const missing = await handle(request({ path: '/api/v1/admin' }));
  assert.equal(missing.status, 404);
  const forbiddenMethod = await handle(request({ method: 'GET' }));
  assert.equal(forbiddenMethod.status, 405);
  assert.equal(forbiddenMethod.headers.allow, 'POST');
  assert.equal(calls.length, 0);
});

test('cross-site and missing Origin fail without CORS or activation', async () => {
  const { handle, calls } = fixture(true);
  for (const origin of ['https://attacker.invalid', 'null', null]) {
    const r = request();
    if (origin === null) delete r.headers.origin;
    else r.headers.origin = origin;
    const response = await handle(r);
    assert.equal(response.status, 403);
    assert.equal(response.headers['access-control-allow-origin'], undefined);
  }
  assert.equal(calls.length, 0);
});

test('requires JSON and Bearer token, rejects cookie-only authentication', async () => {
  const { handle, calls } = fixture(true);
  const wrongType = request();
  wrongType.headers['content-type'] = 'text/plain';
  assert.equal((await handle(wrongType)).status, 415);
  const cookie = request();
  delete cookie.headers.authorization;
  cookie.headers.cookie = 'session=an-unsafe-cookie';
  assert.equal((await handle(cookie)).status, 401);
  const invalid = request();
  invalid.headers.authorization = 'Basic abcdef';
  assert.equal((await handle(invalid)).status, 401);
  assert.equal(calls.length, 0);
});

test('rejects oversized, invalid, unknown and attacker-supplied owner fields', async () => {
  const { handle, calls } = fixture(true);
  for (const body of [
    '{broken', '[]', 'null', '{}',
    JSON.stringify({ worldId: 1, airlineName: 'Fly', homeAirportKey: 'OURAIRPORTS:101', playerId: 'attacker' }),
    JSON.stringify({ worldId: 1, airlineName: 'Fly' })
  ]) {
    const output = await handle(request({ body }));
    assert.equal(output.status, 400);
  }
  const huge = await handle(request({ body: 'x'.repeat(2049) }));
  assert.equal(huge.status, 413);
  assert.equal(calls.length, 0);
  assert.deepEqual(parseOnboardingBody(BODY),
    { worldId: 1, airlineName: 'Aurelia Airways', homeAirportKey: 'OURAIRPORTS:101' });
  const fiction = parseOnboardingBody(JSON.stringify({
    worldId:1,airlineName:'Aleksandrovo Air',
    homeAirportKey:'FICTIONAL:fictional:RS:LYAL'
  }));
  assert.equal(fiction.homeAirportKey,'FICTIONAL:fictional:RS:LYAL');
});

test('valid request returns exact cash string and never leaks tokens', async () => {
  const { handle, calls } = fixture(true);
  const response = await handle(request());
  const json = JSON.parse(response.body);
  assert.equal(response.status, 201);
  assert.equal(json.newlyCreated, true);
  assert.equal(json.cashUsd, '5000000.00');
  assert.equal(calls.length, 1);
  assert.equal(calls[0].accessToken, TOKEN);
  assert.deepEqual(calls[0].request, JSON.parse(BODY));
  assert.ok(!response.body.includes(TOKEN));
  assert.ok(!response.body.includes('playerId'));
  assert.equal(response.headers['referrer-policy'], 'no-referrer');
});

test('identical retry is a 200 response without new airline', async () => {
  const { handle } = fixture(true, async () => ({
    airlineId: '22222222-2222-4222-8222-222222222222',
    newlyCreated: false,
    cashUsd: '5000000.00',
    trialEndsAt: '2026-11-02T08:00:00.000Z'
  }));
  const response = await handle(request());
  assert.equal(response.status, 200);
  assert.equal(JSON.parse(response.body).newlyCreated, false);
});

test('SQL/provider failures are generic and do not disclose private details', async () => {
  const { handle } = fixture(true, async () => {
    const error = new Error('secret connection string db-host / internal.sql');
    error.code = 'XX000';
    throw error;
  });
  const response = await handle(request());
  assert.equal(response.status, 503);
  assert.ok(!response.body.includes('secret'));
  assert.ok(!response.body.includes('db-host'));
});

test('known unique and expired auth failures map to safe HTTP responses', async () => {
  const conflict = fixture(true, async () => {
    const error = new Error('index airlinerra_airline_name_per_world');
    error.code = '23505';
    throw error;
  });
  assert.equal((await conflict.handle(request())).status, 409);
  const unauthorized = fixture(true, async () => {
    throw new Error('Verified player authentication is required.');
  });
  assert.equal((await unauthorized.handle(request())).status, 401);
});

test('malformed handler configuration fails closed', () => {
  assert.throws(() => createAirlineHttpHandler({}), /Private activation/);
  assert.throws(() => createAirlineHttpHandler({
    activationService: { createAirline: async () => {} },
    allowedOrigins: ['https://airlinerra.invalid/extra-path']
  }), /Explicit HTTP origins/);
});
