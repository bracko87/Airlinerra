/**
 * Read-only, owner-verified AOC status foundation.
 *
 * No user-supplied player/holding ID can select records. The verified Auth
 * session resolves the player; the database independently checks ownership.
 * There is NO action to issue/review/reinstate, alter safety or spend money.
 * The released UI endpoint is intentionally not connected yet.
 */
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export const AOC_STATUS_SQL=Object.freeze({
 verifiedGameDay:'SELECT airlinerra_game.section9_verified_permission_game_day_v1() AS game_day',
 ownerStatus:'SELECT airlinerra_game.section9_aoc_owned_status_v1($1::uuid,$2::uuid,$3::date) AS result'
});
const statuses=new Set(['planned_not_released','not_issued','active','expired']);
const validStatus=(data,airlineId)=>data&&typeof data==='object'&&!Array.isArray(data)&&
 data.airlineId===airlineId&&data.worldId===1&&
 statuses.has(data.status)&&data.readOnly===true&&
 typeof data.issued==='boolean';
export function createSection9AocReadService({database,identityAuthority}={}){
 if(typeof database?.connect!=='function'||
   typeof identityAuthority?.authorizeStatus!=='function')
  throw Error('AOC_READ_AUTHORITY_NOT_CONFIGURED');
 return Object.freeze({
  async getOwnedStatus({airlineId}={}){
   if(typeof airlineId!=='string'||!UUID.test(airlineId))
    throw Error('AOC_READ_INVALID_AIRLINE_ID');
   const identity=await identityAuthority.authorizeStatus({airlineId});
   if(identity?.authorized!==true||
      identity.source!=='verified_game_player_session'||
      typeof identity.ownerPlayerId!=='string'||
      !UUID.test(identity.ownerPlayerId)||
      (identity.airlineId!==undefined&&identity.airlineId!==airlineId))
    throw Error('AOC_READ_UNVERIFIED_PLAYER');
   const client=await database.connect();
   try{
    const day=await client.query(AOC_STATUS_SQL.verifiedGameDay,[]);
    if(day.rowCount!==1||!Array.isArray(day.rows)||
       !Object.hasOwn(day.rows[0],'game_day'))throw Error('AOC_READ_UNVERIFIED_CLOCK');
    const verifiedDay=day.rows[0].game_day;
    if(verifiedDay!==null&&
      !(typeof verifiedDay==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(verifiedDay)))
      throw Error('AOC_READ_UNEXPECTED_GAME_DAY');
    const r=await client.query(AOC_STATUS_SQL.ownerStatus,
      [identity.ownerPlayerId,airlineId,verifiedDay]);
    if(r.rowCount!==1||!validStatus(r.rows?.[0]?.result,airlineId))
      throw Error('AOC_READ_INVALID_RESPONSE');
    // A release gate can remain off while protected company records exist.
    // Never synthesize a player-issued AOC from a default Safety Rating.
    return Object.freeze(r.rows[0].result);
   }finally{client.release();}
  }
 });
}
