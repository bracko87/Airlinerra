/**
 * Airlinerra identity foundation.
 * Public account access stays disabled until domain, SMTP, legal and backend checks pass.
 * These frontend guards are UX-only; public signup MUST ALSO be disabled server-side.
 */
export const PUBLIC_AUTH_ENABLED = false;
export const ALLOWED_AUTH_ORIGINS = Object.freeze(['http://localhost:5187', 'http://localhost:5188', 'https://airlinerra.com']);

export const WORLD_DIRECTORY = Object.freeze([
  Object.freeze({ id: '01', name: 'Founding World', state: 'planned', calendar: '1 real day = 1 game day' }),
  Object.freeze({ id: '02', name: 'Expansion World', state: 'planned', calendar: '1 real day = 1 game day' }),
  Object.freeze({ id: '03', name: 'Future World', state: 'planned', calendar: '1 real day = 1 game day' })
]);

const SCREENS = new Set(['sign-in', 'register', 'forgot', 'reset', 'verify', 'worlds']);

export function safeScreen(value) {
  return SCREENS.has(value) ? value : 'sign-in';
}

export function normalizedEmail(value) {
  if (typeof value !== 'string') throw new Error('Enter a valid email address.');
  const email = value.trim().toLowerCase();
  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new Error('Enter a valid email address.');
  }
  return email;
}

export function validatedPassword(value) {
  if (typeof value !== 'string' || value.length < 8 || value.length > 128) {
    throw new Error('Password must contain 8 to 128 characters.');
  }
  return value;
}

/** UI-only guide; provider applies its own independent password checks. */
export function passwordStrength(value){
 if(typeof value!=='string'||value.length===0)return {score:0,label:'Enter a password'};
 if(value.length<8)return {score:0,label:'At least 8 characters required'};
 const groups=[/[a-z]/.test(value),/[A-Z]/.test(value),/[0-9]/.test(value),/[^A-Za-z0-9]/.test(value)].filter(Boolean).length;
 const score=Math.min(4,1+Number(value.length>=12)+Number(groups>=3)+Number(value.length>=16&&groups>=3));
 return {score,label:['','Weak','Fair','Good','Strong'][score]};
}

export function validatedDisplayName(value) {
  if (typeof value !== 'string') throw new Error('Enter a display name.');
  const name = value.trim().normalize('NFKC');
  if (name.length < 2 || name.length > 40 || /[<>\x00-\x1f\x7f]/.test(name)) {
    throw new Error('Display name must contain 2 to 40 valid characters.');
  }
  return name;
}

/** Fixed callback destinations: no open redirects and no arbitrary "next" URLs. */
export function authRedirect(origin, screen = 'verify') {
  if (!ALLOWED_AUTH_ORIGINS.includes(origin)) {
    throw new Error('This site origin is not authorized for account callbacks.');
  }
  if (!['verify', 'reset'].includes(screen)) {
    throw new Error('Invalid account callback.');
  }
  return origin + '/account.html?screen=' + screen;
}

export function isWorldSelectable(world) {
  return !!world && ['registration_open','active'].includes(world.state);
}
