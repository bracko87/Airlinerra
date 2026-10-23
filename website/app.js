'use strict';
// Public Supabase publishable key; NEVER use a service-role key in frontend code.
// This only reads the public status record protected by RLS.
const AIRLINERRA_SUPABASE_URL = 'https://hwllkabgzaynalahvkpz.supabase.co';
const AIRLINERRA_PUBLISHABLE_KEY = 'sb_publishable_XznHs5hhAddw-wbYtKodRg_C5RtM5vg';
const statusNode = document.getElementById('backend-status');
const detailNode = document.getElementById('backend-detail');
async function checkAirlinerraConnection(){
  if (!statusNode || !detailNode) return;
  statusNode.textContent='Checking database…';
  statusNode.dataset.state='checking';
  const controller=new AbortController();
  const timeout=setTimeout(()=>controller.abort(),10000);
  try{
    const res=await fetch(
      AIRLINERRA_SUPABASE_URL+'/rest/v1/airlinerra_site_status?select=site_name,backend_state,game_state&id=eq.main',
      {headers:{apikey:AIRLINERRA_PUBLISHABLE_KEY},signal:controller.signal}
    );
    if(!res.ok)throw Error('HTTP '+res.status);
    const rows=await res.json();
    if(!Array.isArray(rows)||rows.length!==1||rows[0].backend_state!=='ready') throw Error('Unexpected status response');
    statusNode.textContent='Database connected';
    statusNode.dataset.state='ready';
    detailNode.textContent='Airlinerra · Frankfurt · '+(rows[0].game_state==='prelaunch'?'Prelaunch test':'Game live');
  }catch(err){
    statusNode.textContent='Connection not verified';
    statusNode.dataset.state='error';
    detailNode.textContent='Website online; Supabase status request failed: '+err.message;
  }finally{clearTimeout(timeout);}
}
document.getElementById('retry')?.addEventListener('click',checkAirlinerraConnection);
checkAirlinerraConnection();
