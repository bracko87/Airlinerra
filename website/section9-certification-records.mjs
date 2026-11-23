/** Read-only summary of recorded certificate rows.
 * Never interprets database rows as independently verified signed activation.
 */
export const CERTIFICATION_SOURCES=Object.freeze([
 ['operator_licence','Operator licence (AOC)','licenses'],
 ['route_traffic_rights','Traffic rights','licenses'],
 ['airport_slot_capacity','Reserved airport slots','schedule'],
 ['trusted_flight_execution','Flight execution and crew','staff'],
 ['commercial_finance','Commercial finance','finance']
]);
export function summarizeRecordedCertifications(reply){
 if(reply?.status!=='signed_certification_records_read_only'||
  reply.readOnly!==true||reply.canActivateNormalFlight!==false||
  reply.certificationRevalidated!==false||
  typeof reply.scheduleId!=='string'||!Number.isInteger(reply.scheduleVersion)||
  !Array.isArray(reply.certificates))return null;
 const gameDate=/^\d{4}-\d{2}-\d{2}$/.test(reply.verifiedGameDate||'')?
  reply.verifiedGameDate:null;
 const checks=CERTIFICATION_SOURCES.map(([type,label,page])=>{
  const matching=reply.certificates.filter(c=>c?.type===type&&
   c.scheduleVersion===reply.scheduleVersion);
  const row=matching.length===1?matching[0]:null;
  const valid=!!gameDate&&row?.status==='certified'&&
   /^\d{4}-\d{2}-\d{2}$/.test(row.validToGameDate||'')&&
   row.validToGameDate>=gameDate;
  return Object.freeze({type,label,page,
   state:valid?'recorded':row?.status==='revoked'?'blocked':'unverified',
   explanation:valid?
    'A current certificate is recorded for this schedule version; its signature and live conditions have not been rechecked by this display.':
    !gameDate?'Verified game date unavailable; certificate validity cannot be established.':
    !row?'No unique current certificate record for this schedule version.':
    row.status==='revoked'?'This certification has been revoked.':
    'A current certified record was not found or its validity has ended.'});
 });
 return Object.freeze({
  summary:'Recorded certification status · read-only. This view does not revalidate signatures, maintenance, live crew, airport capacity or authorize flight activation.',
  gameDate,checks:Object.freeze(checks),
  scheduleStatus:reply.scheduleStatus,
  operationallyVerified:reply.operationallyVerified===true
 });
}
