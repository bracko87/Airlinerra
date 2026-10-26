// Private prelaunch legal acceptance HTTP adapter. Never mounted by default.
const path = '/api/v1/legal/consents';
const headers = Object.freeze({
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store',
  'x-content-type-options': 'nosniff',
  'referrer-policy': 'no-referrer'
});
const reply = (status, data) => Object.freeze({
  status, headers, body: JSON.stringify(data)
});
function readHeader(h, key) {
  for (const [name, value] of Object.entries(h || {})) {
    if (name.toLowerCase() === key) return typeof value === 'string' ? value : null;
  }
  return null;
}

export function parseConsentRequest(body) {
  if (typeof body !== 'string') throw new Error('Invalid JSON body.');
  if (Buffer.byteLength(body, 'utf8') > 2048) {
    throw new RangeError('JSON body exceeds limit.');
  }
  let data;
  try { data = JSON.parse(body); } catch { throw new Error('Invalid JSON body.'); }
  if (!data || Array.isArray(data) || typeof data !== 'object') {
    throw new Error('Expected a JSON object.');
  }
  const keys = Object.keys(data);
  const expected = ['termsVersion','privacyVersion','acceptTerms','acceptPrivacy'];
  if (keys.length !== expected.length || keys.some(k => !expected.includes(k))) {
    throw new Error('Unexpected legal acceptance fields.');
  }
  if (data.acceptTerms !== true || data.acceptPrivacy !== true) {
    throw new Error('Both documents require explicit acceptance.');
  }
  const valid = v => typeof v === 'string' &&
    /^[A-Za-z0-9][A-Za-z0-9._-]{0,49}$/.test(v);
  if (!valid(data.termsVersion) || !valid(data.privacyVersion)) {
    throw new Error('Invalid legal versions.');
  }
  return Object.freeze(data);
}

export function createLegalConsentHttpHandler({
  consentService, allowedOrigins = [], enabled = false
} = {}) {
  if (typeof consentService?.acceptPublishedPolicy !== 'function') {
    throw new Error('Trusted legal consent service required.');
  }
  if (!Array.isArray(allowedOrigins) ||
      allowedOrigins.some(o => typeof o !== 'string' ||
        !/^https?:\/\/[^/]+$/.test(o))) {
    throw new Error('Invalid origin allowlist.');
  }
  const origins = new Set(allowedOrigins);
  return async function handle(request = {}) {
    if (request.path !== path) return reply(404, {error:'Not found.'});
    if (request.method !== 'POST') return reply(405, {error:'Method not allowed.'});
    if (!enabled) return reply(503, {error:'Legal acceptance is unavailable.'});
    if (!origins.has(readHeader(request.headers,'origin'))) {
      return reply(403, {error:'Origin not approved.'});
    }
    if (!/^application\/json(?:;\s*charset=utf-8)?$/i.test(
        readHeader(request.headers,'content-type') || '')) {
      return reply(415, {error:'JSON required.'});
    }
    const authorization = readHeader(request.headers, 'authorization');
    const token = /^Bearer ([A-Za-z0-9._~-]{16,8192})$/.exec(authorization || '');
    if (!token) return reply(401, {error:'Sign in first.'});
    let acceptance;
    try { acceptance = parseConsentRequest(request.body); }
    catch (error) {
      return reply(error instanceof RangeError ? 413 : 400, {error:error.message});
    }
    try {
      const result = await consentService.acceptPublishedPolicy({
        accessToken: token[1], acceptance
      });
      return reply(200, {
        termsVersion:result.termsVersion,
        privacyVersion:result.privacyVersion,
        acceptedAt:result.acceptedAt
      });
    } catch (error) {
      if (/Verified player authentication/i.test(error?.message || '')) {
        return reply(401,{error:'Sign in again.'});
      }
      if (/terms or privacy policy changed/i.test(error?.message || '')) {
        return reply(409,{error:'Review the updated legal documents.'});
      }
      return reply(503,{error:'Legal acceptance could not be completed.'});
    }
  };
}
