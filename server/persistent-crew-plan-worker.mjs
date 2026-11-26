import {planWeeklyCrew} from './weekly-crew-allocation-engine.mjs';
// Private worker only. The database independently validates every seat and duty.
// Saving a preview does not reserve live crew or affect commercial operations.
export async function preparePersistentCrewPlan({client,playerId,airlineId,planId,windowStartUtc,save=false}){
 if(typeof client?.query!=='function'||typeof planId!=='string'||typeof save!=='boolean')throw Error('INVALID_CREW_PLAN_WORKER_INPUT');
 const args=[playerId,airlineId,windowStartUtc];
 const response=await client.query('SELECT airlinerra_game.section9_owned_weekly_crew_input_v1($1::uuid,$2::uuid,$3::timestamptz) AS result',args);
 const snapshot=response.rows?.[0]?.result;
 if(snapshot?.status!=='weekly_crew_bootstrap_input_preview')throw Error('CREW_PLAN_INPUT_NOT_VERIFIED');
 if(snapshot.invalidOccurrenceCount!==0||snapshot.cabinHeadcountReconciled!==true)return {status:'crew_plan_input_unreconciled',saved:false};
 if(!snapshot.flights.length)return {status:'no_dated_flights',saved:false};
 const plan=planWeeklyCrew(snapshot);
 if(!save||plan.unassignedFlightCount!==0)return {status:'crew_plan_preview_only',plan,saved:false};
 const output=await client.query('SELECT airlinerra_game.section9_save_owned_crew_plan_preview_v1($1::uuid,$2::uuid,$3::uuid,$4::timestamptz,$5::jsonb,$6::jsonb) AS result',[playerId,airlineId,planId,windowStartUtc,JSON.stringify(snapshot),JSON.stringify(plan.assignments)]);
 if(typeof output.rows?.[0]?.result?.status!=='string')throw Error('CREW_PLAN_SAVE_NOT_VERIFIED');
 return {status:output.rows[0].result.status,plan,receipt:output.rows[0].result,saved:output.rows[0].result.saved===true||output.rows[0].result.status==='validated_preview'&&output.rows[0].result.replayed===true};
}

// Review-only path: deliberately no save option and no call to the old
// plan writer, which cannot yet independently validate merged history.
export async function previewStorageAwareCrewPlan({client,playerId,airlineId,windowStartUtc,save=false}){
 if(typeof client?.query!=='function'||save!==false)throw Error('STORAGE_AWARE_CREW_PREVIEW_ONLY');
 const response=await client.query('SELECT airlinerra_game.owned_storage_aware_crew_input_preview_v1($1::uuid,$2::uuid,$3::timestamptz) AS result',[playerId,airlineId,windowStartUtc]);
 const snapshot=response.rows?.[0]?.result;
 if(snapshot?.status!=='storage_aware_crew_input_preview'||snapshot.airlineId!==airlineId||snapshot.storageHistoryIncluded!==true||snapshot.enforceRollingWeeklyDutyHours!==true||snapshot.saveAllowed!==false||snapshot.crewReleased!==false||snapshot.dispatchEnforced!==false||Date.parse(snapshot.windowStartUtc)!==Date.parse(windowStartUtc))throw Error('STORAGE_AWARE_CREW_INPUT_NOT_VERIFIED');
 const plan=planWeeklyCrew(snapshot);
 return {status:'storage_aware_crew_plan_preview',plan,excludedEmployees:snapshot.excludedEmployees,saved:false,crewReleased:false,dispatchEnforced:false};
}
