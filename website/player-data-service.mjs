/**
 * Account profile and public world-directory repository.
 * This is the prepared browser data layer, not authorization for world entry.
 * The Supabase game schema has NOT been applied as of this commit.
 * Never expose private airlinerra_game tables or use user metadata for access.
 */
import {
  PUBLIC_AUTH_ENABLED, validatedDisplayName
} from './auth-rules.mjs';

const PROFILE_FIELDS = 'user_id,display_name,locale,created_at,updated_at';
const DIRECTORY_FIELDS = 'id,name,state,opens_at';

export function validatedLocale(value) {
  if (value == null || value === '') return null;
  if (typeof value !== 'string' ||
    !/^[a-z]{2,3}(?:-[A-Z][a-z]{3})?(?:-[A-Z]{2}|-[0-9]{3})?$/.test(value)) {
    throw new Error('Unsupported language or locale.');
  }
  return value;
}

export function safeWorldDirectory(rows) {
  if (!Array.isArray(rows)) throw new Error('World directory is unavailable.');
  const statuses = new Set(['planned','registration_open','active','locked','retired']);
  const ids = new Set();
  return rows.map(row => {
    const id = Number(row?.id);
    if (!Number.isInteger(id) || id < 1 || id > 3 || ids.has(id)) {
      throw new Error('Unexpected game world ID.');
    }
    if (typeof row.name !== 'string' || row.name.length < 2 ||
        row.name.length > 80 || !statuses.has(row.state)) {
      throw new Error('Invalid game world metadata.');
    }
    ids.add(id);
    return Object.freeze({
      id: String(id).padStart(2,'0'),
      name: row.name,
      state: row.state,
      calendar: '1 real day = 1 game day'
    });
  }).sort((a,b)=>Number(a.id)-Number(b.id));
}

export function createPlayerDataService({ supabase, enabled = PUBLIC_AUTH_ENABLED } = {}) {
  if (!supabase || typeof supabase.from !== 'function' || !supabase.auth) {
    throw new Error('Supabase client required.');
  }

  function requireEnabled() {
    if (!enabled) throw new Error('Player account storage is not enabled.');
  }

  async function ownVerifiedUser() {
    const { data, error } = await supabase.auth.getUser();
    if (error) throw error;
    if (!data?.user?.id || !data.user.email_confirmed_at ||
        data.user.is_anonymous === true) {
      throw new Error('Sign in with a verified email to manage your profile.');
    }
    return data.user;
  }

  return {
    async listWorlds() {
      requireEnabled();
      // Public directory is informational only. World entry requires
      // independent, trusted server-side membership and entitlement checks.
      const { data, error } = await supabase.from('airlinerra_game_worlds')
        .select(DIRECTORY_FIELDS).order('id', { ascending: true });
      if (error) throw error;
      return safeWorldDirectory(data);
    },

    async getMyProfile() {
      requireEnabled();
      const user = await ownVerifiedUser();
      const { data, error } = await supabase.from('airlinerra_player_profiles')
        .select(PROFILE_FIELDS).eq('user_id', user.id).maybeSingle();
      if (error) throw error;
      return data || null;
    },

    async saveMyProfile({ displayName, locale = null }) {
      requireEnabled();
      const user = await ownVerifiedUser();
      const payload = {
        user_id: user.id, // sourced solely from verified Auth, never caller input
        display_name: validatedDisplayName(displayName),
        locale: validatedLocale(locale)
      };
      const { data, error } = await supabase.from('airlinerra_player_profiles')
        .upsert(payload, { onConflict: 'user_id' })
        .select(PROFILE_FIELDS).single();
      if (error) throw error;
      if (data?.user_id !== user.id) {
        throw new Error('Profile ownership verification failed.');
      }
      return data;
    }
  };
}
