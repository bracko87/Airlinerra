/** Completely simulated local onboarding; no real Auth, email, password storage or airline writes. */
import {createLocalCatalogClient} from '/local-catalog-client.mjs';
import {beginLocalDemo,setLocalTestProfile,isLocalDemoOrigin} from '/local-demo-session.mjs';
import {saveLocalDraft} from '/local-onboarding-draft.mjs';
import {startAttempt,loadAttempt,confirmAttempt,completePasswordStep,clearAttempt} from './state.mjs';
const doc=document,store=sessionStorage;
if(!isLocalDemoOrigin(location))throw Error('Local registration unavailable outside loopback');
const dataClient=createLocalCatalogClient({location});
const error=doc.getElementById('error');
function showError(message){error.hidden=!message;error.textContent=message||''}
function stage(name){
 for(const id of ['identity','email','password','airline']){
  doc.getElementById('stage-'+id).hidden=id!==name;
  const el=doc.getElementById('progress-'+id);
  el.className=id===name?'current':(['identity','email','password','airline'].indexOf(id)<['identity','email','password','airline'].indexOf(name)?'complete':'');
 }
 showError('');
}
let catalogReady=false;
async function loadCatalog(){
 if(catalogReady)return;
 const data=await dataClient.overview();
 if(!Array.isArray(data.countries)||!Array.isArray(data.worlds)||!data.readOnly)throw Error('Catalog unavailable');
 const world=doc.getElementById('test-world'),country=doc.getElementById('test-country');
 world.replaceChildren(new Option('Select test world',''));
 for(const w of data.worlds){
  const option=new Option(w.name+' — '+w.state+' (preview only)',String(w.id));
  // Only World 1 has approved airports in the local catalog.
  option.disabled=Number(w.id)!==1;
  world.append(option);
 }
 world.value='1';world.disabled=false;
 country.replaceChildren(new Option('Select country',''));
 for(const c of data.countries){
  const name=new Intl.DisplayNames(['en'],{type:'region'}).of(c.countryIso);
  country.append(new Option(name+' ('+c.airportCount+' airports)',c.countryIso));
 }
 country.disabled=false;
 doc.getElementById('test-airport-query').disabled=false;
 doc.getElementById('test-search-airports').disabled=false;
 catalogReady=true;
}
async function refreshStage(){
 const params=new URL(location.href).searchParams;
 if(params.has('confirm')){
  const confirmed=confirmAttempt(store,params.get('confirm'));
  history.replaceState(null,'',location.pathname);
  if(!confirmed)showError('Confirmation link is invalid or has already been replaced. Restart the test.');
 }
 const attempt=loadAttempt(store);
 if(!attempt){stage('identity');return}
 if(!attempt.emailConfirmed){
  stage('email');doc.getElementById('inbox-address').textContent=attempt.email;
  doc.getElementById('confirmation-link').href='/__local_registration__/?confirm='+encodeURIComponent(attempt.token);
  return;
 }
 if(!attempt.passwordStepComplete){stage('password');return}
 stage('airline');
 try{await loadCatalog()}catch{showError('Local approved-airport catalog is unavailable. Restart the localhost preview server.')}
}
doc.getElementById('create-test-account').addEventListener('submit',e=>{
 e.preventDefault();
 const bytes=crypto.getRandomValues(new Uint8Array(16));
 const token=Array.from(bytes,x=>x.toString(16).padStart(2,'0')).join('');
 try{
  startAttempt(store,{name:doc.getElementById('test-name').value,
    email:doc.getElementById('test-email').value,token});
  void refreshStage();
 }catch(err){showError(err.message)}
});
doc.getElementById('test-password-form').addEventListener('submit',e=>{
 e.preventDefault();
 const one=doc.getElementById('test-password'),two=doc.getElementById('test-confirm-password');
 try{
  completePasswordStep(store,one.value,two.value);
  void refreshStage();
 }catch(err){showError(err.message)}
 finally{one.value='';two.value=''}
});
doc.getElementById('test-country').addEventListener('change',()=>{
 const airport=doc.getElementById('test-airport');
 airport.replaceChildren(new Option('Search for an airport',''));airport.disabled=true;
});
doc.getElementById('test-search-airports').addEventListener('click',async()=>{
 const countryIso=doc.getElementById('test-country').value,term=doc.getElementById('test-airport-query').value.trim();
 if(!/^[A-Z]{2}$/.test(countryIso)){showError('Choose a country first');return}
 try{
  const data=await dataClient.airports({countryIso,search:term});
  const select=doc.getElementById('test-airport');
  select.replaceChildren(new Option('Choose a home airport',''));
  for(const a of data.airports){
   const option=new Option(a.name+(a.code?' ('+a.code+')':'')+' · '+a.municipality,a.key);
   select.append(option);
  }
  select.disabled=data.airports.length===0;
  showError(data.airports.length?'':'No airports found. Try another name or airport code.');
 }catch{showError('Airport lookup unavailable. Use a shorter search term or try again.')}
});
doc.getElementById('test-airline-form').addEventListener('submit',e=>{
 e.preventDefault();
 const attempt=loadAttempt(store);
 if(!attempt?.emailConfirmed||!attempt.passwordStepComplete)return showError('Complete email confirmation and password steps first.');
 try{
  const worldId=Number(doc.getElementById('test-world').value),
   countryIso=doc.getElementById('test-country').value,
   airport=doc.getElementById('test-airport'),
   airlineName=doc.getElementById('test-airline-name').value;
  if(worldId!==1)throw Error('Only World 1 has an approved airport catalog in this preview');
  if(airport.disabled||!airport.value||!Array.from(airport.options).some(x=>x.value===airport.value))
   throw Error('Select an approved home airport');
  saveLocalDraft(store,location,{worldId,countryIso,airportKey:airport.value,airlineName});
  setLocalTestProfile(store,location,{name:attempt.name,email:attempt.email});
  const target=beginLocalDemo(store,location);
  clearAttempt(store);
  location.assign(target.replace('#overview','#onboarding'));
 }catch(err){showError(err.message)}
});
doc.getElementById('restart').addEventListener('click',()=>{
 clearAttempt(store);location.replace('/__local_registration__/');
});
void refreshStage();
