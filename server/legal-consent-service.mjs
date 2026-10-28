/**
 * Backend-only acceptance of the published Airlinerra Terms and Privacy
 * Policy. No listener or public RPC is installed; enabled defaults to false.
 *
 * Exactly the versions shown to a player must be accepted. Only the server's
 * freshly verified Auth user ID is stored, never client-supplied identity.
 */
import { verifiedPlayerId } from './airline-activation.mjs';
import { OWNER_PRIVATE_PILOT_VERSION } from './onboarding-context-service.mjs';

const POLICY_VERSION = /^[A-Za-z0-9][A-Za-z0-9._-]{0,49}$/;

export const INSERT_PRIVATE_PILOT_ACK_SQL=[
 'insert into airlinerra_game.owner_private_pilot_consents(player_id,version)',
 'select u.id,$2::text from auth.users u',
 'join airlinerra_game.owner_premium_email_reservations r on r.email=lower(btrim(u.email))',
 'where u.id=$1::uuid and u.email_confirmed_at is not null',
 'and coalesce(u.is_anonymous,false)=false and u.deleted_at is null',
 'and (u.banned_until is null or u.banned_until<=now())',
 "and $2::text='owner_private_pilot_20261028'",
 'on conflict(player_id) do nothing returning acknowledged_at'
].join(' ');
export const READ_PRIVATE_PILOT_ACK_SQL=[
 'select acknowledged_at from airlinerra_game.owner_private_pilot_consents',
 'where player_id=$1::uuid and version=$2::text'
].join(' ');
export const READ_PUBLISHED_POLICY_SQL = [
  'select terms_version, privacy_version',
  'from airlinerra_game.legal_release_policy',
  'where id = true and is_published = true and approved_at is not null',
  'for share'
].join(' ');

export const INSERT_CONSENT_SQL = [
  'insert into airlinerra_game.account_consents',
  '(player_id, terms_version, privacy_version)',
  'select u.id, $2::text, $3::text from auth.users u',
  'where u.id = $1::uuid',
  'and u.email_confirmed_at is not null',
  'and coalesce(u.is_anonymous, false) = false',
  'and u.deleted_at is null',
  'and (u.banned_until is null or u.banned_until <= now())',
  'and exists (select 1 from airlinerra_game.legal_release_policy l',
  'where l.id = true and l.is_published = true and l.approved_at is not null',
  'and l.terms_version = $2::text and l.privacy_version = $3::text)',
  'on conflict (player_id, terms_version, privacy_version) do nothing',
  'returning accepted_at'
].join(' ');

export const EXISTING_CONSENT_SQL = [
  'select accepted_at from airlinerra_game.account_consents',
  'where player_id = $1::uuid and terms_version = $2::text',
  'and privacy_version = $3::text',
  'and exists (select 1 from auth.users u where u.id = $1::uuid',
  'and u.email_confirmed_at is not null',
  'and coalesce(u.is_anonymous, false) = false',
  'and u.deleted_at is null',
  'and (u.banned_until is null or u.banned_until <= now()))'
].join(' ');

export function validatedPolicyAcceptance(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('Invalid legal acceptance request.');
  }
  const keys = Object.keys(value);
  if (keys.length !== 4 ||
      keys.some(k => !['termsVersion', 'privacyVersion', 'acceptTerms', 'acceptPrivacy'].includes(k))) {
    throw new Error('Unexpected legal acceptance fields.');
  }
  if (value.acceptTerms !== true || value.acceptPrivacy !== true) {
    throw new Error('Terms and privacy policy must be explicitly accepted.');
  }
  if (typeof value.termsVersion !== 'string' ||
      !POLICY_VERSION.test(value.termsVersion) ||
      typeof value.privacyVersion !== 'string' ||
      !POLICY_VERSION.test(value.privacyVersion)) {
    throw new Error('Invalid published policy version.');
  }
  return Object.freeze({
    termsVersion: value.termsVersion,
    privacyVersion: value.privacyVersion
  });
}

export function createLegalConsentService({
  verifyUserToken, database, enabled = false, enablePrivatePilot=false
} = {}) {
  if (typeof verifyUserToken !== 'function' ||
      !database || typeof database.connect !== 'function') {
    throw new Error('Trusted Auth verification and PostgreSQL pool are required.');
  }

  async function acceptPublishedPolicy({ accessToken, acceptance } = {}) {
    if (!enabled) throw new Error('Airlinerra legal acceptance is not yet enabled.');
    if (typeof accessToken !== 'string' || accessToken.length < 16) {
      throw new Error('Verified player authentication is required.');
    }

    const playerId = verifiedPlayerId(await verifyUserToken(accessToken));
    const requested = validatedPolicyAcceptance(acceptance);
    const connection = await database.connect();
    let transactionStarted = false;
    try {
      await connection.query('BEGIN');
      transactionStarted = true;
      // One verified owner may acknowledge REVIEW DRAFTS in a separate pilot table.
      // This NEVER marks public Terms or Privacy as legally published.
      if(enablePrivatePilot &&
        requested.termsVersion===OWNER_PRIVATE_PILOT_VERSION &&
        requested.privacyVersion===OWNER_PRIVATE_PILOT_VERSION){
        const params=[playerId,OWNER_PRIVATE_PILOT_VERSION];
        const inserted=await connection.query(INSERT_PRIVATE_PILOT_ACK_SQL,params);
        let acceptedAt=inserted.rows?.[0]?.acknowledged_at??null;
        if(acceptedAt===null){
          const existing=await connection.query(READ_PRIVATE_PILOT_ACK_SQL,params);
          acceptedAt=existing.rows?.[0]?.acknowledged_at??null;
        }
        if(acceptedAt===null)throw Error('Private pilot acknowledgement was not authorized.');
        await connection.query('COMMIT');
        transactionStarted=false;
        return Object.freeze({
          termsVersion:OWNER_PRIVATE_PILOT_VERSION,
          privacyVersion:OWNER_PRIVATE_PILOT_VERSION,acceptedAt
        });
      }
      // Hold a shared lock on the current legal release while writing consent.
      const current = await connection.query(READ_PUBLISHED_POLICY_SQL);
      if (current.rows?.length !== 1) {
        throw new Error('Published legal documents are not available.');
      }
      const policy = current.rows[0];
      if (policy.terms_version !== requested.termsVersion ||
          policy.privacy_version !== requested.privacyVersion) {
        throw new Error('The terms or privacy policy changed. Review the latest version.');
      }

      const params = [playerId, requested.termsVersion, requested.privacyVersion];
      const created = await connection.query(INSERT_CONSENT_SQL, params);
      let acceptedAt = created.rows?.[0]?.accepted_at ?? null;
      if (acceptedAt === null) {
        // A conflict is idempotent. Absence of a matching row instead means
        // unverified/banned/deleted Auth user or changed database state.
        const existing = await connection.query(EXISTING_CONSENT_SQL, params);
        acceptedAt = existing.rows?.[0]?.accepted_at ?? null;
        if (acceptedAt === null) {
          throw new Error('Legal acceptance could not be verified.');
        }
      }

      await connection.query('COMMIT');
      transactionStarted = false;
      return Object.freeze({
        termsVersion: requested.termsVersion,
        privacyVersion: requested.privacyVersion,
        acceptedAt
      });
    } catch (error) {
      if (transactionStarted) {
        try { await connection.query('ROLLBACK'); } catch { /* preserve root error */ }
      }
      throw error;
    } finally {
      connection.release();
    }
  }

  return Object.freeze({ acceptPublishedPolicy });
}
