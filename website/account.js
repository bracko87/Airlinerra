import { PUBLIC_AUTH_ENABLED, WORLD_DIRECTORY, safeScreen, isWorldSelectable } from './auth-rules.mjs';
import { createBrowserAuthClient } from './auth-client.mjs';
import { createAuthService, parseAuthCallback } from './auth-service.mjs';
import { createPlayerDataService } from './player-data-service.mjs';

const descriptions = {
  'sign-in': ['Welcome back', 'Preview the steps players will use to access Airlinerra.'],
  register: ['Create your account', 'Account registration will require email verification.'],
  forgot: ['Recover your account', 'A one-time recovery link will be sent to the account owner.'],
  reset: ['Set a new password', 'A recovery link must be verified before setting a new password.'],
  verify: ['Verify your email', 'Every manager confirms their address before entering a world.'],
  worlds: ['Select a game world', 'Three worlds are planned, with World 01 first to launch.']
};
const feedback = document.querySelector('#account-feedback');
let verifiedRecovery = false;
let accountService = null;
let playerDataService = null;
let verifiedProfileReady = false;

function setFeedback(message, isError = false) {
  feedback.hidden = !message;
  feedback.textContent = message || '';
  feedback.dataset.state = isError ? 'error' : 'info';
}

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
  const url = new URL(window.location.href);
  // Never preserve auth code, recovery hash, error_description or unknown
  // query parameters in browser history or shared links.
  url.search = '';
  url.hash = '';
  url.searchParams.set('screen', current);
  window.history.replaceState({}, '', url.pathname + url.search);
  setFeedback('');
}

function setFormsEnabled() {
  for (const panel of document.querySelectorAll('[data-panel]')) {
    const fieldset = panel.querySelector('fieldset');
    if (!fieldset) continue;
    fieldset.disabled = !PUBLIC_AUTH_ENABLED ||
      (panel.dataset.panel === 'reset' && !verifiedRecovery) ||
      (panel.dataset.panel === 'worlds' && !verifiedProfileReady);
  }
}

function drawWorlds(worlds = WORLD_DIRECTORY) {
  const worldList = document.querySelector('#world-list');
  worldList.replaceChildren();
  for (const world of worlds) {
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
}

function formValue(panel, selector) {
  const input = document.querySelector('[data-panel="' + panel + '"] ' + selector);
  return input?.value ?? '';
}

function resetInputs() {
  for (const input of document.querySelectorAll('input[type="password"]')) input.value = '';
}

async function showSignedInProfile() {
  // Backend RLS still verifies profile ownership independently; this is UX.
  // The editor stays disabled if the actual profile table is not accessible.
  verifiedProfileReady = false;
  displayScreen('worlds');
  setFormsEnabled();
  let profile = null;
  let profileUnavailable = false;
  let worldsUnavailable = false;
  try {
    profile = await playerDataService.getMyProfile();
    verifiedProfileReady = true;
  } catch {
    profileUnavailable = true;
  }
  try {
    const worlds = await playerDataService.listWorlds();
    drawWorlds(worlds);
  } catch {
    // Do not treat a failed directory request as authorization to join.
    drawWorlds();
    worldsUnavailable = true;
  }
  document.querySelector('#profile-display-name').value =
    profile?.display_name || '';
  document.querySelector('#profile-locale').value = profile?.locale || '';
  setFormsEnabled();
  setFeedback(profileUnavailable ?
    'Signed in. Player profile storage is not available in this environment yet.' :
    worldsUnavailable ?
      'Verified account. Profile editing is available; game worlds are still unavailable.' :
      'Verified account. You can update your player profile; airline creation remains closed.');
}

async function handleSubmit(event) {
  event.preventDefault();
  if (!PUBLIC_AUTH_ENABLED || !accountService) return;
  const panel = event.target.closest('[data-panel]')?.dataset.panel;
  const button = event.target.querySelector('button[type=submit]');
  if (button) button.disabled = true;
  try {
    if (panel === 'sign-in') {
      await accountService.signIn({
        email: formValue(panel, '#login-email'),
        password: formValue(panel, '#login-password')
      });
      resetInputs();
      const user = await accountService.getUser();
      if (!user?.email_confirmed_at || user.is_anonymous === true || user.deleted_at) {
        throw new Error('Verified account required.');
      }
      await showSignedInProfile();
    } else if (panel === 'worlds') {
      if (!verifiedProfileReady || !playerDataService) {
        throw new Error('Sign in with a verified account first.');
      }
      await playerDataService.saveMyProfile({
        displayName: formValue(panel, '#profile-display-name'),
        locale: formValue(panel, '#profile-locale') || null
      });
      setFeedback('Manager profile saved.');
    } else if (panel === 'register') {
      const result = await accountService.register({
        displayName: formValue(panel, '#register-name'),
        email: formValue(panel, '#register-email'),
        password: formValue(panel, '#register-password'),
        termsAccepted: document.querySelector('[data-panel=register] input[type=checkbox]')?.checked === true
      });
      resetInputs();
      displayScreen('verify');
      setFeedback(result.message);
    } else if (panel === 'forgot') {
      const result = await accountService.requestPasswordReset(formValue(panel, '#forgot-email'));
      setFeedback(result.message);
    } else if (panel === 'reset') {
      if (!verifiedRecovery) throw new Error('Request a new recovery link first.');
      const newPassword = formValue(panel, '#reset-password');
      if (newPassword !== formValue(panel, '#reset-confirm')) {
        throw new Error('The two passwords do not match.');
      }
      const result = await accountService.updatePassword(newPassword);
      verifiedRecovery = false;
      resetInputs();
      setFormsEnabled();
      displayScreen('sign-in');
      setFeedback(result.message);
    }
  } catch (error) {
    // Generic errors for production-facing login/signup prevent accidental
    // enumeration. Validation errors from local input are safe to display.
    const safeMessage = panel === 'sign-in'
      ? 'Unable to sign in. Check your credentials or verify your email.'
      : (panel === 'register'
        ? 'Registration could not be completed. Please review the form.'
        : error?.message || 'Unable to complete this request.');
    setFeedback(safeMessage, true);
    resetInputs();
  } finally {
    if (button) button.disabled = false;
  }
}

async function initialize() {
  const originalUrl = new URL(window.location.href);
  const screen = safeScreen(originalUrl.searchParams.get('screen'));
  const rawQuery = originalUrl.search;
  displayScreen(screen); // scrubs auth material immediately, before any await
  setFormsEnabled();
  drawWorlds();
  document.querySelector('#copyright-year').textContent = new Date().getFullYear();

  for (const button of document.querySelectorAll('[data-screen]')) {
    button.addEventListener('click', () => {
      verifiedRecovery = false;
      setFormsEnabled();
      displayScreen(button.dataset.screen);
    });
  }
  for (const form of document.querySelectorAll('.account-panel form')) {
    form.addEventListener('submit', handleSubmit);
  }

  // No network, SDK download, credential storage, or account operations
  // happen in the released preview until this flag changes in a separate gate.
  if (!PUBLIC_AUTH_ENABLED) return;

  try {
    // No default project credentials are embedded in the static website.
    // An explicitly configured local/dev Auth instance is required.
    const devAuth = window.__AIRLINERRA_DEV_AUTH__ || {};
    const supabase = await createBrowserAuthClient({
      origin: window.location.origin,
      supabaseUrl: devAuth.supabaseUrl,
      publishableKey: devAuth.publishableKey
    });
    accountService = createAuthService({ supabase, origin: window.location.origin, enabled: true });
    playerDataService = createPlayerDataService({supabase,enabled:true});
    setFormsEnabled();

    const callback = parseAuthCallback(rawQuery, screen);
    if (callback) {
      const completion = await accountService.completeCallback(callback);
      if (completion.purpose === 'reset') {
        verifiedRecovery = true;
        setFormsEnabled();
        displayScreen('reset');
        setFeedback('Recovery link verified. Choose a new password.');
      } else {
        displayScreen('sign-in');
        setFeedback('Email confirmed. You can now sign in.');
      }
    } else if (screen === 'reset') {
      displayScreen('forgot');
      setFeedback('Request a new password recovery email to continue.', true);
    } else if (screen === 'worlds') {
      // A page refresh must re-verify account state, never infer it from URL.
      try {
        const user = await accountService.getUser();
        if (user?.email_confirmed_at && user.is_anonymous !== true && !user.deleted_at) {
          await showSignedInProfile();
        }
      } catch {
        setFormsEnabled();
        setFeedback('Sign in to manage your profile.', true);
      }
    }
  } catch {
    verifiedRecovery = false;
    setFormsEnabled();
    setFeedback('This link could not be verified. Request a new email or try again.', true);
  }
}

initialize();
