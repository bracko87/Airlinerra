/** Real backend onboarding client. Never accepts fabricated accounts, airline IDs or
 * client-side financial calculations. All writes require fresh hosted Auth.
 */
export function createRealOnboardingClient({auth,origin,fetchImpl=(...args)=>fetch(...args)}={}){
 if(!['http://localhost:5188','https://airlinerra.com'].includes(origin)||
   typeof auth?.getAccessToken!=='function'||typeof fetchImpl!=='function')
   throw Error('Verified Airlinerra Auth client required');
 async function post(path,payload){
  if(!['/api/v1/onboarding/context','/api/v1/legal/consents','/api/v1/airlines'].includes(path))
   throw Error('Unsupported onboarding operation');
  const token=await auth.getAccessToken();
  const response=await fetchImpl(origin+path,{
   method:'POST',headers:{'content-type':'application/json',authorization:'Bearer '+token},
   credentials:'omit',cache:'no-store',redirect:'error',mode:'same-origin',referrerPolicy:'no-referrer',
   body:JSON.stringify(payload)
  });
  let result;try{result=await response.json()}catch{throw Error('Invalid server response')}
  if(!response.ok){
   if(response.status===401)throw Error('Your account session expired. Sign in again.');
   if(response.status===409)throw Error('The legal policy or airline status changed. Refresh the page.');
   if(response.status===503)throw Error('Airline setup is temporarily unavailable. Please try again.');
   throw Error(typeof result?.error==='string'?result.error:'Onboarding request rejected');
  }
  return result;
 }
 return Object.freeze({
  context:()=>post('/api/v1/onboarding/context',{}),
  acceptLegal:({termsVersion,privacyVersion})=>post('/api/v1/legal/consents',{
   termsVersion,privacyVersion,acceptTerms:true,acceptPrivacy:true
  }),
  createAirline:({worldId,airlineName,homeAirportKey})=>
   post('/api/v1/airlines',{worldId,airlineName,homeAirportKey})
 });
}
