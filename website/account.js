import { PUBLIC_AUTH_ENABLED, WORLD_DIRECTORY, safeScreen, isWorldSelectable } from './auth-rules.mjs';

const descriptions = {
  'sign-in': ['Welcome back', 'Preview the steps players will use to access Airlinerra.'],
  register: ['Create your account', 'Account registration will require email verification.'],
  forgot: ['Recover your account', 'A one-time recovery link will be sent to the account owner.'],
  reset: ['Set a new password', 'A recovery link will be verified before password changes are allowed.'],
  verify: ['Verify your email', 'Every manager confirms their address before entering a world.'],
  worlds: ['Select a game world', 'Three worlds are planned, with World 01 first to launch.']
};

function displayScreen(screen) {
  const current = safeScreen(screen);
  for (const panel of document.querySelectorAll('[data-panel]')) {
    panel.hidden = panel.dataset.panel !== current;
  }
  for (const button of document.querySelectorAll('.tab')) {
    if (button.dataset.screen === current) button.setAttribute('aria-current', 'page');
    else button.removeAttribute('aria-current');
  }
  document.querySelector('#account-title').textContent = descriptions[current][0];
  document.querySelector('#account-description').textContent = descriptions[current][1];
  // This preview never handles account tokens, passwords, or verification codes.
  const url = new URL(window.location.href);
  url.search = '';
  url.searchParams.set('screen', current);
  window.history.replaceState({}, '', url.pathname + url.search);
}

if (PUBLIC_AUTH_ENABLED) {
  // Production activation requires a vetted, packaged Supabase SDK, SMTP, legal terms,
  // server-side signup guard, configured redirect allowlist and an owner launch gate.
  throw new Error('Auth enablement requires the separate production integration.');
}

for (const button of document.querySelectorAll('[data-screen]')) {
  button.addEventListener('click', () => displayScreen(button.dataset.screen));
}
for (const form of document.querySelectorAll('.account-panel form')) {
  form.addEventListener('submit', event => event.preventDefault());
}
const worldList = document.querySelector('#world-list');
for (const world of WORLD_DIRECTORY) {
  const article = document.createElement('article');
  article.className = 'world-entry';
  const content = document.createElement('div');
  const title = document.createElement('strong');
  title.textContent = 'World ' + world.id + ' — ' + world.name;
  const time = document.createElement('span');
  time.textContent = world.calendar;
  content.append(title, time);
  const status = document.createElement('span');
  status.textContent = isWorldSelectable(world) ? 'Registration open' : 'Coming later';
  article.append(content, status);
  worldList.append(article);
}
document.querySelector('#copyright-year').textContent = new Date().getFullYear();
displayScreen(new URLSearchParams(window.location.search).get('screen'));
