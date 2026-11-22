import {planAutomaticCrewHiring} from './automatic-crew-hiring-engine.mjs';
// Private worker entry point, not exposed through a player-facing route.
// caller supplies trusted airline ownership and a verified game-clock instant.
export async function runAutomaticCrewRecruitment({client,playerId,airlineId,runId,windowStartUtc,availableFromUtc,execute=false}){
 if(typeof client?.query!=='function'||typeof execute!=='boolean'||typeof runId!=='string')throw Error('INVALID_AUTO_RECRUITMENT_WORKER_INPUT');
 const read=await client.query('SELECT airlinerra_game.section9_owned_automatic_recruitment_snapshot_v1($1::uuid,$2::uuid,$3::timestamptz) AS result',[playerId,airlineId,windowStartUtc]);
 const snapshot=read.rows?.[0]?.result;
 if(snapshot?.airlineId!==airlineId||snapshot.status!=='automatic_crew_recruitment_snapshot')throw Error('AUTO_RECRUITMENT_SNAPSHOT_UNVERIFIED');
 const plan=planAutomaticCrewHiring(snapshot,availableFromUtc);
 if(!execute||!plan.executeAllowed)return {plan,execution:null};
 const write=await client.query('SELECT airlinerra_game.section9_execute_automatic_crew_hire_v1($1::uuid,$2::uuid,$3::uuid,$4::timestamptz,$5::jsonb,$6::jsonb) AS result',[playerId,airlineId,runId,windowStartUtc,JSON.stringify(snapshot),JSON.stringify(plan.hireGroups)]);
 if(typeof write.rows?.[0]?.result?.status!=='string')throw Error('AUTO_RECRUITMENT_EXECUTION_UNVERIFIED');
 return {plan,execution:write.rows[0].result};
}
