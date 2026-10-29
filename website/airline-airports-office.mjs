/** Airlinerra airport office - real HQ + private hub and station proposals.
 * Airport data source is only the authenticated, approved World 1 catalog.
 * No simulation of fees, salaries, slots, demand, routes or flights.
 */
const AIRPORT_KEY=/^(?:OURAIRPORTS:[1-9]\d{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/;
const currency=v=>new Intl.NumberFormat('en-US',{style:'currency',currency:'USD',maximumFractionDigits:0}).format(v);
const safeLocalValue=(v)=>typeof v==='string'?v.trim():'';
const textValue=(v)=>typeof v==='string'&&v.trim()?v.trim():'Data pending';
export function normalizeApprovedAirport(a){
 if(!a||!AIRPORT_KEY.test(a.key||'')||typeof a.name!=='string'||!a.name.trim())return null;
 return Object.freeze({key:a.key,name:a.name.trim(),code:safeLocalValue(a.code),
  countryIso:/^[A-Z]{2}$/.test(a.countryIso||'')?a.countryIso:null,
  municipality:safeLocalValue(a.municipality)});
}
export function proposeAirportOffice({type,airport,homeAirportKey,existing=[]}={}){
 const a=normalizeApprovedAirport(airport);
 if(!a||!['hub','station'].includes(type))return {ok:false,reason:'Choose an approved airport.'};
 if(!a.countryIso)return {ok:false,reason:'Select an airport from a country first.'};
 if(a.key===homeAirportKey)return {ok:false,reason:'Headquarters is already your permanent home base.'};
 if(existing.some(x=>x?.key===a.key))return {ok:false,reason:'An office proposal already exists for this airport.'};
 if(existing.length>=20)return {ok:false,reason:'Maximum 20 combined office proposals per browser session.'};
 return {ok:true,entry:Object.freeze({...a,type,status:'draft',minimumStaff:type==='station'?1:null})};
}
const panel=(kicker,title,body)=>'<article class="panel airport-office-panel"><span class="panel-kicker">'+kicker+'</span><h2>'+title+'</h2>'+body+'</article>';
function createText(doc,tag,value,cls){
 const element=doc.createElement(tag);if(cls)element.className=cls;
 element.textContent=value;return element;
}
function row(doc,label,value,root){
 const div=doc.createElement('div');div.className='airport-profile-fact';
 div.append(createText(doc,'span',label),createText(doc,'strong',value));
 root.append(div);return div;
}
function button(doc,label,action,key){
 const b=doc.createElement('button');b.type='button';b.className='secondary';
 b.textContent=label;b.dataset.officeAction=action;
 if(key)b.dataset.airportKey=key;return b;
}
const readSession=(store,key)=>{try{return JSON.parse(store?.getItem(key)||'{}')||{}}catch{return {}}};
const saveSession=(store,key,entries)=>{
 try{const current=readSession(store,key);store?.setItem(key,JSON.stringify({...current,airportOffices:entries}));return !!store}
 catch{return false}
};
const countryLabel=code=>{
 if(!code)return 'Data pending';
 try{return new Intl.DisplayNames(['en'],{type:'region'}).of(code)||code}catch{return code}
};
export function createAirportOffice({doc,session,identity,goTo}={}){
 if(!doc||typeof identity!=='string'||!/^[\w-]{3,128}$/.test(identity))
  throw Error('Verified account required for airport office');
 const key='airlinerra.local.workplan.v1.'+identity;
 const $=id=>doc.getElementById(id);
 const host=$('workspace-hubs'),profileHost=$('workspace-airport-profile');
 let live={connected:false,airline:null,countries:[],reader:null};
 let selectedAirport=null,activeAirport=null;
 let remoteEntries=null,remoteRequest=0,remoteBusy=false,remoteOwner=null;
 const known=new Map();
 const serverMode=()=>Boolean(live.officeClient);
 const localEntries=()=>{
  const current=readSession(session,key);
  if(Array.isArray(current.airportOffices))return current.airportOffices.filter(x=>x?.status==='draft'&&
   ['hub','station'].includes(x.type)&&normalizeApprovedAirport(x));
  // Backward compatibility: previously proposed hubs had no country.
  return Array.isArray(current.hubs)?current.hubs.filter(x=>normalizeApprovedAirport(x)).map(x=>({
   ...x,type:'hub',status:'draft',countryIso:x.countryIso||null
  })):[];
 };
 const entries=()=>serverMode()?(remoteEntries||[]):localEntries();
 async function refreshRemote({announce=true}={}){
  const request=++remoteRequest;
  remoteEntries=null;renderList('hub');renderList('station');
  if(!serverMode()||!live.connected||!live.airline?.id)return false;
  const client=live.officeClient,worldId=Number(live.airline.worldId),owner=remoteOwner;
  try{
   const rows=await client.list({worldId});
   if(request!==remoteRequest||client!==live.officeClient||owner!==remoteOwner)return false;
   remoteEntries=rows.map(entry=>({...entry,minimumStaff:entry.type==='station'?1:null}));
   for(const entry of remoteEntries)remember(entry);
   renderList('hub');renderList('station');updateBrowserDraftNote();
   if(announce)feedback('Permanent office drafts loaded. No offices are active.');
   return true;
  }catch{
   if(request!==remoteRequest)return false;
   remoteEntries=null;renderList('hub');renderList('station');updateBrowserDraftNote();
   feedback('Saved office drafts could not be loaded. Browser proposals were not changed.');
   return false;
  }
 }
 if(host){
  host.innerHTML=panel('HEADQUARTERS','Registered headquarters',
   '<p class="hint">This is the airport chosen when the airline was created. It is company identity, not an additional paid hub.</p>'+
   '<div class="airport-office-headquarters"><div><span class="hint">Home airport</span><h3 id="airport-office-hq-name">Checking...</h3>'+
   '<p id="airport-office-hq-code" class="hint"></p></div>'+
   '<button type="button" class="secondary" data-office-action="home-profile">Airport profile</button></div>')+
   panel('HUBS AND STATIONS','Plan an airport office',
    '<p class="hint">Hubs support aircraft and connecting operations. A station is a smaller local presence, normally requiring at least one representative. Both remain proposals until the airport fees, staffing and activation engine are ready.</p>'+
    '<div class="airport-office-form"><label for="office-location-type">Office type</label>'+
    '<select id="office-location-type"><option value="hub">Additional hub</option><option value="station">Station</option></select>'+
    '<label for="office-country">Country</label><select id="office-country"><option value="">Choose country</option></select>'+
    '<label for="office-search">Airport name, city or code</label><input id="office-search" maxlength="40" placeholder="Search approved airports">'+
    '<button type="button" class="secondary" id="office-find">Search airports</button>'+
    '<label for="office-result">Approved airport</label><select id="office-result" disabled><option value="">Search first</option></select>'+
    '<div class="airport-office-form-actions"><button type="button" class="primary" id="office-save">Save proposed location</button>'+
    '<button type="button" class="secondary" id="office-preview">Airport profile</button></div></div>'+
    '<p id="office-feedback" class="hint" role="status"></p>'+
    '<p id="office-local-draft-note" class="hint"></p>'+
    '<button type="button" class="secondary" id="office-import-local" hidden>Import browser proposals into my airline</button>')+
   panel('NETWORK LOCATIONS','My hubs',
    '<div class="airport-office-summary"><span>Active additional hubs</span><strong>Not connected</strong></div>'+
    '<div id="office-hub-list" class="operations-route-table"></div>')+
   panel('AIRPORT REPRESENTATION','My stations',
    '<p class="hint">One proposed local representative per station is the minimum staffing concept. Salaries and airport desk fees will be configured before activation.</p>'+
    '<div class="airport-office-summary"><span>Active stations</span><strong>Not connected</strong></div>'+
    '<div id="office-station-list" class="operations-route-table"></div>')+
   panel('COST MODEL','Office costs - future activation',
    '<div class="airport-office-cost-grid"><div><strong>Hub opening charge</strong><span>Airport-dependent - not configured</span></div>'+
    '<div><strong>Hub recurring charge</strong><span>Size, slots, services and aircraft basing - data pending</span></div>'+
    '<div><strong>Station desk fee</strong><span>Airport-dependent recurring charge - not configured</span></div>'+
    '<div><strong>Station representative</strong><span>At least one employee; salary table pending integration</span></div></div>'+
    '<p class="hint">Saving an office proposal does not open a hub or station, reserve slots, hire staff or spend airline funds.</p>');
 }
 if(profileHost){
  profileHost.innerHTML=panel('AIRPORT DIRECTORY','Airport profile',
   '<div class="airport-profile-head"><div><p class="hint">World 1 approved airport</p>'+
   '<h3 id="airport-profile-name">Select an airport</h3><p id="airport-profile-location" class="hint"></p></div>'+
   '<button type="button" class="secondary" data-office-action="back">Back to hubs and stations</button></div>'+
   '<div id="airport-profile-facts" class="airport-profile-facts"></div>')+
   panel('AIRPORT INFRASTRUCTURE','Runways, terminals and slots',
    '<div id="airport-profile-infrastructure" class="airport-profile-facts"></div>')+
   panel('MARKET DEMAND','Passenger and cargo demand',
    '<p class="hint">Passenger/cargo demand, annual traffic and route potential will be populated from verified data. No artificial percentages.</p>'+
    '<div id="airport-profile-demand" class="airport-profile-facts"></div>')+
   panel('AIRLINE ACTIVITY','Airlines and airport presence',
    '<div id="airport-profile-airlines" class="airport-profile-facts"></div>'+
    '<p class="hint">Airlines with headquarters, hubs, stations and operations will be listed when a verified multi-airline operations read model exists.</p>')+
   panel('FLIGHT BOARD','Current departures and arrivals',
    '<div class="airport-flight-board"><div class="airport-flight-columns"><span>Time</span><span>Airline</span><span>Flight</span><span>Origin / destination</span><span>Status</span></div>'+
    '<p>Live airport flight movements are not connected yet.</p></div>')+
   panel('AIRPORT ROUTE NETWORK','Destinations and frequencies',
    '<p class="hint">Connections, operating airlines, flight frequency and passenger load statistics will appear when verified flight scheduling is connected.</p>');
 }
 const feedback=t=>{if($('office-feedback'))$('office-feedback').textContent=t};
 function updateBrowserDraftNote(){
  const note=$('office-local-draft-note'),importButton=$('office-import-local');
  const local=localEntries(),saved=Array.isArray(remoteEntries)?remoteEntries:[];
  const remaining=local.filter(d=>!saved.some(x=>x.key===d.key&&x.type===d.type));
  if(note)note.textContent=serverMode()?
    (remaining.length?remaining.length+' browser-only proposals are not yet saved on the server. You can import them explicitly.':
     'Browser-only proposals are kept separate from permanent offices.'):
    'These proposals are browser-only until permanent office saving is enabled.';
  if(importButton){
   importButton.hidden=!serverMode()||!live.connected||!Array.isArray(remoteEntries)||!remaining.length;
   importButton.disabled=remoteBusy;
  }
 }
 function retainUnimported(imported){
  if(!imported.length)return true;
  const remainder=localEntries().filter(x=>!imported.includes(x.key));
  return saveSession(session,key,remainder);
 }
 function remember(a){const normalized=normalizeApprovedAirport(a);if(normalized)known.set(normalized.key,normalized);return normalized}
 function headquarters(){
  const a=live.airline;
  const airport=a?.homeAirportKey?remember({key:a.homeAirportKey,name:a.homeAirportName||'Home airport',
   code:a.homeAirportCode||'',countryIso:a.homeAirportCountryIso||null,
   municipality:a.homeAirportMunicipality||''}):null;
  if($('airport-office-hq-name'))$('airport-office-hq-name').textContent=
   live.connected?airport?.name||'No headquarters assigned':'Not connected';
  if($('airport-office-hq-code'))$('airport-office-hq-code').textContent=
   airport?.code?'Airport code: '+airport.code:'Airport code unavailable';
 }
 function directories(){
  const select=$('office-country');if(!select)return;
  const previous=select.value;
  select.replaceChildren(new Option('Choose country',''));
  const items=Array.isArray(live.countries)?live.countries:[];
  for(const c of items.filter(x=>/^[A-Z]{2}$/.test(x?.countryIso||'')).sort((a,b)=>
   countryLabel(a.countryIso).localeCompare(countryLabel(b.countryIso),'en'))){
   select.add(new Option(countryLabel(c.countryIso)+' ('+c.airportCount+' airports)',c.countryIso));
  }
  if([...select.options].some(o=>o.value===previous))select.value=previous;
 }
 function renderList(type){
  const target=$(type==='hub'?'office-hub-list':'office-station-list');if(!target)return;
  target.replaceChildren();
  const items=entries().filter(e=>e.type===type);
  if(serverMode()&&remoteEntries===null){
   target.append(createText(doc,'p','Server office drafts are not loaded.','hint'));return;
  }
  if(!items.length){target.append(createText(doc,'p',
   type==='hub'?'No additional hub proposals saved.':'No station proposals saved.','hint'));return}
  for(const office of items){
   const line=doc.createElement('div');line.className='airport-office-list-row';
   const text=doc.createElement('div');
   text.append(createText(doc,'strong',office.name+' ('+(office.code||'-')+')'),
    createText(doc,'span',type==='hub'?
      'Additional hub - proposal only':'Station - proposal only; 1 planned representative minimum','hint'));
   const actions=doc.createElement('div');actions.className='airport-office-row-actions';
   actions.append(button(doc,'Airport profile','view',office.key),button(doc,
    serverMode()?'Remove server draft':'Remove draft','remove',office.key));
   line.append(text,actions);target.append(line);remember(office);
  }
 }
 function selectAirport(){
  const chosen=$('office-result')?.value;
  return chosen?known.get(chosen)||null:null;
 }
 async function search(){
  const country=$('office-country')?.value,query=$('office-search')?.value.trim()||'';
  const select=$('office-result');
  if(!select)return;
  select.replaceChildren(new Option('Search first',''));select.disabled=true;selectedAirport=null;
  if(!/^[A-Z]{2}$/.test(country)){feedback('Choose a country first.');return}
  if(!live.connected||!live.reader){feedback('Airport catalog is not connected.');return}
  feedback('Searching approved airports...');
  try{
   const page=await live.reader.airports({countryIso:country,search:query,offset:0});
   if(page.countryIso!==country||!Array.isArray(page.airports))throw Error('Unexpected catalog');
   for(const item of page.airports){
    const a=remember(item);if(!a||a.countryIso!==country)continue;
    const option=new Option(a.name+' ('+(a.code||'-')+')',a.key);select.add(option);
   }
   select.disabled=select.options.length<=1;
   feedback(select.disabled?'No matching approved airports.':
    'Select an airport. Search returns the first 50 matching approved airports.');
  }catch{feedback('Airport search is unavailable. Please retry.')}
 }
 function profileField(id,items){
  const root=$(id);if(!root)return;root.replaceChildren();
  for(const [label,value] of items)row(doc,label,String(value??'Data pending'),root);
 }
 function showProfile(a){
  const airport=remember(a);if(!airport)return;
  activeAirport=airport;
  if($('airport-profile-name'))$('airport-profile-name').textContent=airport.name;
  if($('airport-profile-location'))$('airport-profile-location').textContent=
   [airport.municipality,airport.countryIso?countryLabel(airport.countryIso):''].filter(Boolean).join(', ')||
    'Location not yet available';
  profileField('airport-profile-facts',[
   ['Airport name',airport.name],['Airport code',airport.code||'Data pending'],
   ['ICAO / IATA codes','Not fully verified'],['Country',airport.countryIso?countryLabel(airport.countryIso):'Data pending'],
   ['Municipality',textValue(airport.municipality)],['Game world','Horizon (World 1)'],
   ['Catalog key',airport.key],['Airport category','Data pending'],['Time zone','Data pending'],
   ['Latitude / longitude','Data pending']]);
  profileField('airport-profile-infrastructure',[
   ['Runway count','Data pending'],['Longest operational runway','Data pending'],
   ['Runway surfaces','Data pending'],['Passenger terminals','Data pending'],
   ['Gates / stands','Data pending'],['Available operating slots','Data pending'],
   ['Airport operational status','Data pending']]);
  profileField('airport-profile-demand',[
   ['Passenger demand (0-100%)','Data pending'],['Cargo demand (0-100%)','Data pending'],
   ['Annual passengers','Data pending'],['Annual cargo','Data pending'],
   ['Daily departures / arrivals','Data pending'],['Peak operating periods','Data pending']]);
  const isOwnHeadquarters=live.connected&&live.airline?.homeAirportKey===airport.key;
  const ownDraft=entries().find(x=>x.key===airport.key);
  profileField('airport-profile-airlines',[
   ['Your verified airline headquarters',isOwnHeadquarters?
    (live.airline.name||'Your airline')+' (registered HQ)':'Not your headquarters'],
   ['Your planned office',ownDraft?(ownDraft.type==='hub'?'Hub':'Station')+' - proposal only':
    isOwnHeadquarters?'Main home base':'No proposal'],
   ['Other airlines with headquarters','Not connected'],
   ['Airlines with active hubs','Not connected'],
   ['Airlines with active stations','Not connected'],['Operating airlines','Not connected'],
   ['Current commercial movements','Not connected']]);
  goTo?.('airport-profile');
 }
 const main=$('player-main');
 main?.addEventListener('click',async event=>{
  const target=event.target?.closest?.('button');if(!target)return;
  const action=target.dataset.officeAction;
  if(action==='back'){goTo?.('hubs');return;}
  if(action==='home-profile'){
   if(!live.airline?.homeAirportKey){feedback('No verified home airport.');return}
   const a=known.get(live.airline.homeAirportKey);if(a)showProfile(a);return;
  }
  if(action==='view'){
   const a=known.get(target.dataset.airportKey);if(a)showProfile(a);return;
  }
  if(action==='remove'){
   const key=target.dataset.airportKey;
   if(remoteBusy)return;
   if(serverMode()){
    if(!Array.isArray(remoteEntries)){feedback('Server office drafts are unavailable.');return}
    if(!remoteEntries.some(e=>e.key===key))return;
    remoteBusy=true;target.disabled=true;
    try{
     const removed=await live.officeClient.remove({worldId:Number(live.airline?.worldId),airportKey:key});
     const loaded=await refreshRemote({announce:false});
     feedback(removed?(loaded?'Permanent office draft removed. No active office was changed.':
      'Server confirmed removal, but reloading the office list failed. Please retry.'):
      'That office draft was already removed.');
    }catch{feedback('Server removal failed. No local draft was changed.')}
    finally{remoteBusy=false;target.disabled=false;updateBrowserDraftNote()}
    return;
   }
   const rows=entries(),next=rows.filter(a=>a.key!==key);
   if(rows.length===next.length)return;
   if(!saveSession(session,keyForAccount(),next)){
    feedback('Unable to save removal. Browser session storage is unavailable.');return;
   }
   renderList('hub');renderList('station');updateBrowserDraftNote();feedback('Office proposal removed. No active airport office was changed.');
   return;
  }
  if(target.id==='office-import-local'){
   if(!serverMode()||remoteBusy||!Array.isArray(remoteEntries)||!live.airline?.id)return;
   // Deliberate, user-initiated import only; never transfer browser drafts at login.
   const candidates=localEntries().filter(x=>!remoteEntries.some(y=>y.key===x.key&&y.type===x.type));
   if(!candidates.length){updateBrowserDraftNote();return;}
   remoteBusy=true;target.disabled=true;
   const imported=[];
   try{
    for(const item of candidates){
     if(item.key===live.airline.homeAirportKey)continue;
     await live.officeClient.save({
      worldId:Number(live.airline.worldId),airportKey:item.key,type:item.type
     });
     imported.push(item.key);
    }
    const loaded=await refreshRemote({announce:false});
    if(!loaded){
     feedback('Server accepted '+imported.length+' proposals, but could not verify them yet. Browser copies were kept.');
     return;
    }
    const confirmed=imported.filter(k=>remoteEntries.some(x=>x.key===k));
    if(!retainUnimported(confirmed)){
     feedback('Server drafts saved, but browser copies could not be cleared. No office was charged.');
     return;
    }
    updateBrowserDraftNote();
    feedback(confirmed.length+' proposals imported permanently. Existing server drafts were not duplicated.');
   }catch{
    const loaded=await refreshRemote({announce:false});
    if(loaded){
     const confirmed=imported.filter(k=>remoteEntries.some(x=>x.key===k));
     if(!retainUnimported(confirmed))
      feedback('Import interrupted; permanent drafts saved, but browser copies remain unchanged.');
     else feedback('Import interrupted. '+confirmed.length+' were verified and remaining browser proposals were retained.');
    }else feedback('Import interrupted. Browser copies were retained until permanent saving can be verified.');
    updateBrowserDraftNote();
   }finally{remoteBusy=false;target.disabled=false;updateBrowserDraftNote();}
   return;
  }
  if(target.id==='office-find'){await search();return;}
  if(target.id==='office-preview'){
   const a=selectAirport();if(!a){feedback('Choose an approved airport first.');return;}showProfile(a);return;
  }
  if(target.id==='office-save'){
   if(!live.connected||!live.airline?.id){feedback('Your airline must be verified before planning an office.');return;}
   const a=selectAirport();
   const proposed=proposeAirportOffice({type:$('office-location-type')?.value,airport:a,
    homeAirportKey:live.airline.homeAirportKey,existing:entries()});
   if(!proposed.ok){feedback(proposed.reason);return;}
   if(serverMode()){
    if(remoteBusy||!Array.isArray(remoteEntries)){feedback('Server drafts are not ready.');return;}
    remoteBusy=true;target.disabled=true;
    try{
     await live.officeClient.save({worldId:Number(live.airline.worldId),airportKey:proposed.entry.key,type:proposed.entry.type});
     const loaded=await refreshRemote({announce:false});
     feedback(loaded?'Permanent office draft saved. No fees or salaries were charged.':
      'Server accepted the draft, but the saved list could not be reloaded. Please retry.');
    }catch{feedback('Server save failed. No browser-only drafts were changed.')}
    finally{remoteBusy=false;target.disabled=false;updateBrowserDraftNote()}
    return;
   }
   if(!saveSession(session,keyForAccount(),[...entries(),proposed.entry])){
    feedback('Browser session storage is not available. Your proposal was not saved.');return;
   }
   renderList('hub');renderList('station');updateBrowserDraftNote();
   feedback((proposed.entry.type==='station'?'Station':'Hub')+
    ' proposal saved in this browser session. No fees or salaries were charged.');
  }
 });
 // Keep the private account draft key aligned with Route/Staff planning.
 function keyForAccount(){return key}
 function updateData(value){
  const before=remoteOwner,prevClient=live.officeClient;
  live={...live,...value};
  const owner=live.connected&&serverMode()&&live.airline?.id?
   String(live.airline.id)+':'+String(live.airline.worldId):null;
  remoteOwner=owner;
  if(owner!==before||live.officeClient!==prevClient){
   ++remoteRequest;remoteEntries=null;
  }
  headquarters();directories();renderList('hub');renderList('station');updateBrowserDraftNote();
  if(owner&&(owner!==before||live.officeClient!==prevClient))void refreshRemote();
 }
 function openAirport(airport){
  const a=remember(airport);if(!a)return false;
  showProfile(a);return true;
 }
 updateData({});
 return Object.freeze({updateData,openAirport,getActiveAirport:()=>activeAirport});
}
