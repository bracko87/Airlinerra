import { PUBLIC_AUTH_ENABLED, WORLD_DIRECTORY, safeScreen, isWorldSelectable } from './auth-rules.mjs';
import { createBrowserAuthClient } from './auth-client.mjs';
import { createAuthService, parseAuthCallback } from './auth-service.mjs';
import { createPlayerDataService } from './player-data-service.mjs';
import { createOnboardingApiClient } from './onboarding-api-client.mjs';

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
let onboardingApi = null;
let onboardingContext = null;
let verifiedWizardReady = false;

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
    for (const fieldset of panel.querySelectorAll('fieldset')) {
      const wizard = fieldset.closest('#airline-onboarding');
      fieldset.disabled = !PUBLIC_AUTH_ENABLED ||
        (panel.dataset.panel === 'reset' && !verifiedRecovery) ||
        (panel.dataset.panel === 'worlds' && !(wizard ? verifiedWizardReady : verifiedProfileReady));
    }
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


function buildOptions(select,placeholder,items) {
  select.replaceChildren(new Option(placeholder,''));
  for (const item of items) select.append(new Option(item.label,item.value));
}
function updateApprovedAirports() {
  const worldId=Number(document.querySelector('#onboarding-world').value);
  const selected=onboardingContext?.worlds?.find(world=>world.worldId===worldId);
  buildOptions(document.querySelector('#onboarding-airport'),'Choose an approved airport',
    (selected?.airports||[]).map(airport=>({value:airport.key,label:airport.label})));
}
async function prepareAirlineWizard() {
  verifiedWizardReady=false;
  onboardingContext=null;
  document.querySelector('#airline-onboarding').hidden=true;
  setFormsEnabled();
  if(!onboardingApi || !verifiedProfileReady)return;
  try {
    const context=await onboardingApi.loadContext();
    if(!Array.isArray(context.worlds)||!context.worlds.length||
      !context.policy||!Array.isArray(context.worlds[0].airports)){
      return;
    }
    const policy=context.policy;
    const path=/^\/[A-Za-z0-9._/-]{1,160}\.html$/u;
    if(!path.test(policy.termsUrl)||!path.test(policy.privacyUrl)||
      !policy.termsVersion||!policy.privacyVersion)return;
    const worlds=context.worlds.filter(world=>
      Number.isInteger(world.worldId)&&world.worldId>=1&&world.worldId<=3&&
      Array.isArray(world.airports)&&world.airports.length);
    if(!worlds.length)return;
    onboardingContext=Object.freeze({...context,worlds});
    const link=document.querySelector('#onboarding-terms');
    const privacy=document.querySelector('#onboarding-privacy');
    link.href=policy.termsUrl;
    privacy.href=policy.privacyUrl;
    document.querySelector('#onboarding-policy-label').textContent =
      'Published versions: Terms ' + policy.termsVersion +
      ' · Privacy ' + policy.privacyVersion;
    buildOptions(document.querySelector('#onboarding-world'),'Choose a world',
      worlds.map(world=>({value:String(world.worldId),label:'World '+world.worldId+' — '+world.name})));
    updateApprovedAirports();
    verifiedWizardReady=true;
    document.querySelector('#airline-onboarding').hidden=false;
    setFormsEnabled();
  } catch {
    // Missing hosted legal documents, release gate, approved roster, or API:
    // never show synthetic/unverified airports or a clickable wizard.
    onboardingContext=null;
    verifiedWizardReady=false;
    document.querySelector('#airline-onboarding').hidden=true;
    setFormsEnabled();
  }
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
  await prepareAirlineWizard();
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
    } else if (panel === 'worlds' && event.target.id === 'airline-onboarding-form') {
      if (!verifiedWizardReady || !onboardingContext || !onboardingApi) {
        throw new Error('The airline creation service is not ready.');
      }
      const worldId = Number(document.querySelector('#onboarding-world').value);
      const homeAirportKey = document.querySelector('#onboarding-airport').value;
      const available = onboardingContext.worlds.find(world =>
        world.worldId === worldId &&
        world.airports.some(airport => airport.key === homeAirportKey));
      if (!available) throw new Error('Choose an approved world and airport.');
      if (!document.querySelector('#onboarding-accept-terms').checked ||
          !document.querySelector('#onboarding-accept-privacy').checked) {
        throw new Error('Read and accept both published legal documents.');
      }
      const policy = onboardingContext.policy;
      await onboardingApi.acceptLegal({
        termsVersion: policy.termsVersion,
        privacyVersion: policy.privacyVersion,
        acceptTerms: true,
        acceptPrivacy: true
      });
      const result = await onboardingApi.createAirline({
        worldId, homeAirportKey,
        airlineName: document.querySelector('#onboarding-airline-name').value
      });
      document.querySelector('#onboarding-result').textContent =
        (result.newlyCreated ? 'Airline created.' : 'Existing airline confirmed.') +
        ' Starting balance: $' + result.cashUsd +
        '. Seven-day trial ends: ' + (result.trialEndsAt || 'not applicable') + '.';
      document.querySelector('#onboarding-accept-terms').checked = false;
      document.querySelector('#onboarding-accept-privacy').checked = false;
      await prepareAirlineWizard();
      setFeedback(result.newlyCreated ? 'Your airline was created.' : 'Your airline is already registered.');
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
  document.querySelector('#onboarding-world').addEventListener('change',updateApprovedAirports);

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
      publishableKey: devAuth.publishableKey,
      // Local CI preview uses a bundled SDK instead of external CDN access.
      // Public prelaunch never enters this branch or loads an Auth SDK.
      ...(devAuth.localSdk === true && window.location.hostname === 'localhost'
        ? {loadSdk: () => import('./.airlinerra-local-sdk.mjs')} : {})
    });
    accountService = createAuthService({ supabase, origin: window.location.origin, enabled: true });
    playerDataService = createPlayerDataService({supabase,enabled:true});
    onboardingApi = createOnboardingApiClient({supabase,origin:window.location.origin,enabled:true});
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
 + result.cashUsd +
        '. Seven-day trial ends: ' + (result.trialEndsAt || 'not applicable') + '.';
      document.querySelector('#onboarding-accept-terms').checked = false;
      document.querySelector('#onboarding-accept-privacy').checked = false;
      await prepareAirlineWizard();
      setFeedback(result.newlyCreated ? 'Your airline was created.' : 'Your airline is already registered.');
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
      publishableKey: devAuth.publishableKey,
      // Local CI preview uses a bundled SDK instead of external CDN access.
      // Public prelaunch never enters this branch or loads an Auth SDK.
      ...(devAuth.localSdk === true && window.location.hostname === 'localhost'
        ? {loadSdk: () => import('./.airlinerra-local-sdk.mjs')} : {})
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
