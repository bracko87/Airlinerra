import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import {
  PUBLIC_AUTH_ENABLED, ALLOWED_AUTH_ORIGINS, WORLD_DIRECTORY,
  safeScreen, normalizedEmail, validatedPassword, validatedDisplayName,
  authRedirect, isWorldSelectable
} from '../website/auth-rules.mjs';
import { createAuthService } from '../website/auth-service.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

test('auth and playable worlds are disabled during prelaunch', () => {
  assert.equal(PUBLIC_AUTH_ENABLED, false);
  assert.equal(WORLD_DIRECTORY.length, 3);
  assert.deepEqual(WORLD_DIRECTORY.map(w => w.id), ['01', '02', '03']);
  for (const world of WORLD_DIRECTORY) {
    assert.equal(world.state, 'planned');
    assert.equal(world.calendar, '1 real day = 1 game day');
    assert.equal(isWorldSelectable(world), false);
  }
  assert.equal(isWorldSelectable({ state: 'registration_open' }), true);
});

test('account screen dispatch never trusts arbitrary query input', () => {
  assert.equal(safeScreen('register'), 'register');
  assert.equal(safeScreen('reset'), 'reset');
  assert.equal(safeScreen('worlds'), 'worlds');
  assert.equal(safeScreen('//external-site'), 'sign-in');
  assert.equal(safeScreen('unknown'), 'sign-in');
});

test('email, password and display-name validation', () => {
  assert.equal(normalizedEmail('  A@Example.Com  '), 'a@example.com');
  assert.throws(() => normalizedEmail('invalid'), /valid email/);
  assert.throws(() => normalizedEmail('x'.repeat(250) + '@example.com'), /valid email/);
  assert.equal(validatedPassword('a'.repeat(12)), 'a'.repeat(12));
  assert.throws(() => validatedPassword('short'), /12 to 128/);
  assert.throws(() => validatedPassword('a'.repeat(129)), /12 to 128/);
  assert.equal(validatedDisplayName('  Sky Pilot  '), 'Sky Pilot');
  assert.throws(() => validatedDisplayName('<admin>'), /display name/i);
  assert.throws(() => validatedDisplayName('a'), /display name/i);
});

test('callback redirects accept only one configured local origin and two screens', () => {
  assert.deepEqual(ALLOWED_AUTH_ORIGINS, ['http://localhost:5187']);
  assert.equal(authRedirect('http://localhost:5187', 'verify'), 'http://localhost:5187/account.html?screen=verify');
  assert.equal(authRedirect('http://localhost:5187', 'reset'), 'http://localhost:5187/account.html?screen=reset');
  assert.throws(() => authRedirect('https://evil.example', 'verify'), /not authorized/);
  assert.throws(() => authRedirect('http://localhost:5187', 'https://evil.example'), /Invalid account callback/);
});

test('service never sends credentials or triggers Supabase while prelaunch is closed', async () => {
  let backendCalls = 0;
  const auth = {
    signUp: async () => { backendCalls++; return { data: {}, error: null }; },
    signInWithPassword: async () => { backendCalls++; return { data: {}, error: null }; },
    resetPasswordForEmail: async () => { backendCalls++; return { data: {}, error: null }; },
    exchangeCodeForSession: async () => { backendCalls++; return { data: {}, error: null }; },
    updateUser: async () => { backendCalls++; return { data: {}, error: null }; },
    getUser: async () => { backendCalls++; return { data: { user: {} }, error: null }; },
    signOut: async () => { backendCalls++; return { error: null }; }
  };
  const api = createAuthService({ supabase: { auth }, origin: 'http://localhost:5187', enabled: true });
  const deny = /not yet open/;
  await assert.rejects(api.register({email:'a@example.com',password:'long-enough123',displayName:'Captain',termsAccepted:true}), deny);
  await assert.rejects(api.signIn({email:'a@example.com',password:'password'}), deny);
  await assert.rejects(api.requestPasswordReset('a@example.com'), deny);
  await assert.rejects(api.completeCallback('some-code'), deny);
  await assert.rejects(api.updatePassword('long-enough123'), deny);
  await assert.rejects(api.getUser(), deny);
  await assert.rejects(api.signOut(), deny);
  assert.equal(backendCalls, 0);
});

test('prelaunch forms are visibly disabled and have no real submission target', async () => {
  const html = await readFile(path.join(root, 'website/account.html'), 'utf8');
  const js = await readFile(path.join(root, 'website/account.js'), 'utf8');
  const build = await readFile(path.join(root, 'website/dev-scripts/build.mjs'), 'utf8');
  assert.match(html, /name="robots" content="noindex,nofollow"/);
  assert.match(html, /No information entered here is submitted or stored/);
  assert.equal((html.match(/<fieldset disabled>/g) || []).length, 4);
  assert.equal((html.match(/<form /g) || []).length, 4);
  assert.ok(!/<form[^>]+action=/i.test(html));
  for (const screen of ['sign-in', 'register', 'forgot', 'reset', 'verify', 'worlds']) {
    assert.ok(html.includes('data-panel="' + screen + '"'));
  }
  assert.ok(!js.includes('signUp('));
  assert.ok(!js.includes('signInWithPassword('));
  for (const file of ['account.html', 'account.css', 'account.js', 'auth-rules.mjs', 'auth-service.mjs']) {
    assert.ok(build.includes("'" + file + "'"), 'build must copy ' + file);
  }
});
