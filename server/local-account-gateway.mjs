/**
 * Local-only prelaunch HTTP transport for testing trusted account handlers.
 * Not a production API. Never accepts a public listen address and never
 * supplies DB credentials, enables a world or activates public registration.
 */
import { createServer } from 'node:http';

const MAX_BYTES = 2048;
const HEADERS = Object.freeze({
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store',
  'content-security-policy': "default-src 'none'",
  'x-content-type-options': 'nosniff',
  'referrer-policy': 'no-referrer'
});
const ROUTES = Object.freeze({
  '/api/v1/airlines': 'airlineHandler',
  '/api/v1/legal/consents': 'legalHandler'
});

function respond(res, status, payload, extra = {}) {
  res.writeHead(status, { ...HEADERS, ...extra });
  res.end(JSON.stringify(payload));
}

function collectSmallBody(req) {
  return new Promise(resolve => {
    let finished = false;
    let length = 0;
    const chunks = [];
    const done = value => {
      if (finished) return;
      finished = true;
      resolve(value);
    };
    req.on('data', chunk => {
      if (finished) return;
      length += chunk.length;
      if (length > MAX_BYTES) {
        // Do not buffer additional bytes. Close the connection after replying.
        req.pause();
        done({ status: 413 });
      } else {
        chunks.push(chunk);
      }
    });
    req.on('end', () => done({ body: Buffer.concat(chunks).toString('utf8') }));
    req.on('aborted', () => done({ status: 400 }));
    req.on('error', () => done({ status: 400 }));
  });
}

export async function startLocalAccountGateway({
  createHandlers, enabled = false, port = 0
} = {}) {
  if (typeof createHandlers !== 'function') {
    throw new Error('Trusted account handler factory required.');
  }
  if (!Number.isInteger(port) || port < 0 || port > 65535) {
    throw new Error('Invalid local port.');
  }
  let handlers;
  let boundPort;
  const server = createServer(async (req, res) => {
    try {
      const host = req.headers.host;
      if (host !== `127.0.0.1:${boundPort}` && host !== `localhost:${boundPort}`) {
        return respond(res, 421, { error: 'Invalid local host.' });
      }
      if (!(req.url in ROUTES)) return respond(res, 404, { error: 'Not found.' });
      if (req.method !== 'POST') return respond(res, 405, { error: 'Method not allowed.' }, { allow: 'POST' });
      if (!enabled) return respond(res, 503, { error: 'Account API is disabled.' });
      // Reject cross-origin requests before reading credentials or request bodies.
      if (req.headers.origin !== `http://${host}`) {
        return respond(res, 403, { error: 'Request origin is not approved.' });
      }
      const rawLength = req.headers['content-length'];
      if (rawLength && Number(rawLength) > MAX_BYTES) {
        return respond(res, 413, { error: 'JSON body exceeds limit.' }, { connection: 'close' });
      }
      const body = await collectSmallBody(req);
      if (body.status) {
        return respond(res, body.status, { error: 'Invalid or oversized request body.' },
          { connection: 'close' });
      }
      const handler = handlers[ROUTES[req.url]];
      const result = await handler({
        path: req.url,
        method: req.method,
        headers: req.headers,
        body: body.body
      });
      if (!result || !Number.isInteger(result.status) || result.status < 200 ||
          result.status > 599 || typeof result.body !== 'string') {
        throw new Error('Untrusted handler result.');
      }
      res.writeHead(result.status, { ...HEADERS, ...(result.headers ?? {}) });
      res.end(result.body);
    } catch {
      if (!res.headersSent) respond(res, 503, { error: 'Account API unavailable.' });
      else res.destroy();
    }
  });
  server.requestTimeout = 5000;
  server.headersTimeout = 6000;
  server.keepAliveTimeout = 1500;
  try {
    await new Promise((resolve, reject) => {
      server.once('error', reject);
      server.listen(port, '127.0.0.1', resolve);
    });
    boundPort = server.address().port;
    const origin = `http://127.0.0.1:${boundPort}`;
    handlers = createHandlers(origin);
    if (typeof handlers?.airlineHandler !== 'function' ||
        typeof handlers?.legalHandler !== 'function') {
      throw new Error('Both private account handlers are required.');
    }
    return Object.freeze({
      origin,
      port: boundPort,
      close: async () => new Promise((resolve, reject) =>
        server.close(err => err ? reject(err) : resolve()))
    });
  } catch (error) {
    server.close();
    throw error;
  }
}
