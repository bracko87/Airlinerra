/**
 * PRIVATE onboarding discovery service. Never returns research airport records:
 * only manually inserted airlinerra_game.approved_game_airports rows.
 * No routes, approvals, or public deployment configured here.
 */
import { verifiedPlayerId } from './airline-activation.mjs';

export const ONBOARDING_CONTEXT_SQL = Object.freeze({
  ready: "select g.enabled, l.terms_version, l.privacy_version from airlinerra_game.platform_release_gate g left join airlinerra_game.legal_release_policy l on l.id=true and l.is_published=true and l.approved_at is not null where g.id=true",
  worlds: "select id, name from public.airlinerra_game_worlds where state in ('registration_open','active') order by id",
  airports: "select a.world_id, a.airport_key, a.airport_name, a.airport_code, a.country_iso from airlinerra_game.approved_game_airports a join public.airlinerra_game_worlds w on w.id=a.world_id and w.state in ('registration_open','active') order by a.world_id,a.airport_name nulls last,a.airport_key"
});
const SAFE_DOCUMENT = /^\/[A-Za-z0-9._/-]{1,160}\.html$/u;

// Metadata is copied from the operator's already-approved game roster;
// no airport research table is read by the player-facing service.
function airportDisplayLabel(row) {
  const name=typeof row.airport_name==='string' ? row.airport_name.trim() : '';
  const code=typeof row.airport_code==='string' ? row.airport_code.trim() : '';
  const country=typeof row.country_iso==='string' && /^[A-Z]{2}$/u.test(row.country_iso)
    ? row.country_iso : '';
  if(!name || name.length>160) return row.airport_key;
  return name + (code && code.length<=20 ? ' (' + code + ')' : '') +
    (country ? ' — ' + country : '');
}
export function createOnboardingContextService({
  verifyUserToken, database, enabled=false, documentPaths
}={}) {
  if(typeof verifyUserToken!=='function'||typeof database?.connect!=='function'){
    throw new Error('Trusted Auth verification and private PostgreSQL pool required.');
  }
  const documentReady=!!documentPaths &&
    SAFE_DOCUMENT.test(documentPaths.terms) &&
    SAFE_DOCUMENT.test(documentPaths.privacy) &&
    documentPaths.terms!==documentPaths.privacy;
  return Object.freeze({
    async getContext({accessToken}={}) {
      if(!enabled||!documentReady)throw new Error('Onboarding is not available.');
      if(typeof accessToken!=='string'||accessToken.length<16){
        throw new Error('Verified account required.');
      }
      verifiedPlayerId(await verifyUserToken(accessToken));
      const connection=await database.connect();
      try {
        const release=await connection.query(ONBOARDING_CONTEXT_SQL.ready);
        const policy=release.rows?.[0];
        if(release.rows?.length!==1||policy.enabled!==true||
          !policy.terms_version||!policy.privacy_version){
          throw new Error('Published legal documents and release approval required.');
        }
        const [worldResult,airportResult]=await Promise.all([
          connection.query(ONBOARDING_CONTEXT_SQL.worlds),
          connection.query(ONBOARDING_CONTEXT_SQL.airports)
        ]);
        const byWorld=new Map((worldResult.rows||[]).map(row=>[
          Number(row.id),{worldId:Number(row.id),name:String(row.name),airports:[]}
        ]));
        for(const row of airportResult.rows||[]){
          const bucket=byWorld.get(Number(row.world_id));
          if(bucket && typeof row.airport_key==='string'&&
             /^(?:OURAIRPORTS:[1-9][0-9]{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/u.test(row.airport_key)){
            bucket.airports.push({key:row.airport_key,label:airportDisplayLabel(row)});
          }
        }
        return Object.freeze({
          policy:{termsVersion:policy.terms_version,privacyVersion:policy.privacy_version,
            termsUrl:documentPaths.terms,privacyUrl:documentPaths.privacy},
          worlds:[...byWorld.values()].filter(world=>world.airports.length>0)
        });
      } finally {connection.release();}
    }
  });
}
