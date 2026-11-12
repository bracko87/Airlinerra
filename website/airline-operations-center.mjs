/** Account-local airline operations planning.
 * No hiring, flight, price, hub or route mutation calls. Only authenticated
 * World 1 reads for approved airport lookup; player workplans live in Supabase.
 */
import {createAirportOffice} from './airline-airports-office.mjs';
import {createSection9RouteDetails} from './section9-route-details.mjs';
import {createSection9PartnerConsole} from './section9-partner-console.mjs';
import {summarizeSection9FlightReadiness} from './section9-flight-readiness.mjs';
export const STAFF_DEPARTMENTS=Object.freeze({
 'Board and Executive':[
  ['Chairperson','Oversight and governance'],['Chief Executive Officer','Overall airline leadership'],
  ['Chief Operating Officer','Daily operating strategy'],['Chief Financial Officer','Budget and accounting'],
  ['Chief Commercial Officer','Pricing and sales strategy'],['Chief Technical Officer','Engineering strategy'],
  ['Chief People Officer','HR and employment'],['Chief Information Officer','IT and systems']],
 'Flight Operations':[
  ['Director of Flight Operations','Flight operations leadership'],
  ['Chief Pilot','Flight crew supervision'],['Captain','Aircraft command'],
  ['First Officer','Flight crew'],['Flight Dispatcher','Flight release and planning'],
  ['Crew Scheduler','Rosters and duty limits']],
 'Cabin Services':[
  ['Head of Cabin Crew','Cabin services leadership'],
  ['Purser / Cabin Manager','Cabin supervision'],['Flight Attendant','Passenger safety and service'],
  ['Catering Coordinator','Catering planning']],
 'Maintenance and Engineering':[
  ['Maintenance Director','Aircraft airworthiness'],
  ['Licensed Aircraft Engineer','Aircraft servicing'],
  ['Maintenance Planner','Maintenance schedule'],
  ['Aircraft Technician','Line and hangar maintenance']],
 'Ground and Hub Operations':[
  ['Station Manager','Local station coordination'],['Ground Operations Manager','Ground staff oversight'],
  ['Ramp Agent','Aircraft turnaround'],['Baggage Handler','Baggage logistics'],
  ['Passenger Services Agent','Check-in and boarding'],
  ['Load Controller','Weight and balance']],
 'Commercial and Support':[
  ['Revenue Manager','Fare and yield strategy'],['Route Analyst','Network planning'],
  ['Sales and Marketing Specialist','Promotion and sales'],
  ['Customer Support Agent','Customer inquiries'],
  ['Finance and Payroll Officer','Accounting and payroll'],
  ['HR Specialist','Recruitment and training'],
  ['IT Systems Administrator','Digital operations'],
  ['Safety and Compliance Officer','Operational compliance'],
  ['Security Officer','Airport and company security']]
});
export function payrollEstimate(rows){
 if(!Array.isArray(rows))return null;
 let people=0,total=0;
 for(const row of rows){
  const count=Number(row?.count),salary=Number(row?.salary);
  if(!Number.isSafeInteger(count)||count<0||count>10000||!Number.isFinite(salary)||salary<0||salary>1000000)return null;
  people+=count;total+=count*salary;
 }
 return Number.isSafeInteger(people)&&Number.isSafeInteger(total)?{people,monthly:total,yearly:total*12}:null;
}
export function ticketRevenueEstimate({flights,seats,occupancy,price,cost}={}){
 const n=[flights,seats,occupancy,price,cost].map(Number);
 if(n.some(x=>!Number.isFinite(x))||n[0]<0||n[0]>70||!Number.isInteger(n[0])||
  n[1]<0||n[1]>1000||!Number.isInteger(n[1])||n[2]<0||n[2]>100||
  n[3]<0||n[3]>100000||n[4]<0||n[4]>10000000)return null;
 const passengers=Math.round(n[0]*n[1]*n[2]/100);
 const revenue=passengers*n[3],costs=n[0]*n[4];
 return Object.freeze({passengers,revenue,costs,net:revenue-costs});
}
const money=n=>new Intl.NumberFormat('en-US',{style:'currency',currency:'USD',maximumFractionDigits:0}).format(n);
const escText=(t)=>String(t||'');
const card=(title,body,kicker='OPERATIONS PLANNING')=>'<article class="panel workspace-panel"><span class="panel-kicker">'+kicker+'</span><h2>'+title+'</h2>'+body+'</article>';
export function createOperationsCenter({doc,identity,session,goTo,getAirlineLogoUrl}={}){
 if(!doc||!identity||typeof identity!=='string'||!/^[\w-]{3,128}$/.test(identity))throw Error('Verified account required');
 const key='airlinerra.local.workplan.v1.'+identity;
 const $=id=>doc.getElementById(id);
 let server={connected:false,reader:null,scheduler:null,countries:[],airline:null};
 const root={
  'route-list':$('workspace-route-list'),
  'route-details':$('workspace-route-details'),
  'hubs':$('workspace-hubs'),
  'tickets':$('workspace-tickets'),
  'staff':$('workspace-staff')
 };
 if(root['route-list'])root['route-list'].innerHTML=card('My routes',
  '<p class="hint">Inactive route plans are loaded from your airline database. Drafts are not active flights and do not reserve airport slots.</p>'+
  '<div id="operations-route-list" class="operations-route-table"></div>'+
  '<div class="workspace-actions"><button type="button" class="secondary" data-ops-page="routes">Create a route</button></div>'+
  '<p id="operations-routes-feedback" class="hint" role="status"></p>'+
  '<p id="operations-flight-readiness" class="hint" role="status">Flight readiness will appear after the airline database is checked.</p>'+
  '<div id="operations-partner-console" class="operations-partner-console"></div>',
  'ROUTE DIRECTORY');
 if(root['route-details'])root['route-details'].innerHTML=card('Route Details',
  '<div class="workspace-actions"><button type="button" class="secondary" data-ops-page="route-list">Back to My routes</button>'+
  '<button type="button" class="secondary" id="operations-route-edit-from-details">Edit route</button>'+
  '<button type="button" class="secondary" id="operations-route-cancel-open">Cancel route</button>'+
  '<button type="button" class="primary" id="operations-route-publish-plan" hidden>Save to airline database</button></div>'+
  '<section id="operations-route-cancel-confirm" class="route-cancel-confirm" role="dialog" aria-labelledby="operations-route-cancel-title" hidden>'+
   '<h4 id="operations-route-cancel-title">Cancel this route?</h4>'+
   '<p id="operations-route-cancel-info">This removes the local draft and all planned departures displayed for it. No real bookings or airport slots will be changed.</p>'+
   '<div class="workspace-actions">'+
    '<button type="button" class="secondary" id="operations-route-cancel-dismiss">Keep route</button>'+
    '<button type="button" class="primary" id="operations-route-cancel-confirm-button">Confirm cancellation</button></div>'+
  '</section>'+
  '<p id="operations-route-detail-save-status" class="hint" role="status"></p>'+
  '<div id="operations-route-detail" class="operations-route-detail-content"></div>',
  'ROUTE INFORMATION');
 if(root.tickets)root.tickets.innerHTML=card('Ticket prices and fare analysis',
  '<p class="hint">Enter your own fare, seat capacity, expected load factor and per-flight costs. All output is a planning scenario, not a passenger-demand forecast or a live ticket price.</p>'+
  '<div class="workspace-money-grid">'+
   '<div><label class="workspace-label" for="ops-price-class">Cabin class</label><select id="ops-price-class"><option value="economy">Economy</option><option value="premium">Premium Economy</option><option value="business">Business</option><option value="first">First Class</option></select></div>'+
   '<div><label class="workspace-label" for="ops-price-seat">Seats per flight</label><input id="ops-price-seat" type="number" min="0" max="1000" step="1" value="0"></div>'+
   '<div><label class="workspace-label" for="ops-price-fare">Ticket price (USD)</label><input id="ops-price-fare" type="number" min="0" max="100000" value="0"></div>'+
   '<div><label class="workspace-label" for="ops-price-load">Assumed load factor (%)</label><input id="ops-price-load" type="number" min="0" max="100" value="0"></div>'+
   '<div><label class="workspace-label" for="ops-price-flights">Departures per week</label><input id="ops-price-flights" type="number" min="0" max="70" step="1" value="0"></div>'+
   '<div><label class="workspace-label" for="ops-price-cost">Operating cost per departure (USD)</label><input id="ops-price-cost" type="number" min="0" max="10000000" value="0"></div>'+
  '</div><div class="workspace-actions"><button id="ops-price-calc" type="button" class="primary">Calculate fare scenario</button>'+
  '<button id="ops-price-save" type="button" class="secondary">Save fare draft</button></div>'+
  '<p id="ops-price-feedback" role="status" class="hint"></p><div id="ops-price-results" class="workspace-detail"></div>',
  'FARE STRATEGY')+
  card('Pricing analysis',
  '<div class="workspace-task-list">'+
  '<div><strong>Fare classes</strong><span>Economy, Premium Economy, Business and First Class</span></div>'+
  '<div><strong>Revenue management</strong><span>Price adjustments, load factor and yield comparisons</span></div>'+
  '<div><strong>Competitor analysis</strong><span>Live competitor prices and real demand are not connected</span></div>'+
  '<div><strong>Sales channels</strong><span>Distribution, ancillaries and baggage fees will need transaction support</span></div></div>',
  'COMMERCIAL PLANNING');
 if(root.staff)root.staff.innerHTML=card('Personnel and organizational structure',
  '<p class="hint">Plan staffing across airline departments. Set positions, headcount and gross monthly salary in USD for budgeting. A zero here means no planned headcount, not a live employment count.</p>'+
  '<div class="workspace-kpis"><div><span>Real employees</span><strong>Not connected</strong></div>'+
  '<div><span>Planned positions filled</span><strong id="ops-staff-people">0</strong></div>'+
  '<div><span>Estimated monthly payroll</span><strong id="ops-staff-monthly">$0</strong></div>'+
  '<div><span>Estimated annual payroll</span><strong id="ops-staff-annual">$0</strong></div></div>'+
  '<div id="ops-staff-roles"></div>'+
  '<div class="workspace-actions"><button class="primary" id="ops-staff-save" type="button">Save staffing plan</button>'+
  '<button class="secondary" id="ops-staff-reset" type="button">Clear staffing plan</button></div>'+
  '<p id="ops-staff-feedback" class="hint" role="status"></p>'+
  '<p class="hint">Budget estimates only. No employees are hired, no salaries charged, and no staff market orders are placed.</p>',
  'STAFF AND SALARIES');
 let state={},playerStore=null;
 let remotePlans=[],remotePlanTicket=0,loadedPlanAirline=null,loadedPlanScheduler=null;
 const persist=async(...fields)=>{
  if(!playerStore?.ready('workplan'))return false;
  const patch=Object.fromEntries(fields.map(field=>[field,state[field]??null]));
  try{state=await playerStore.update('workplan',patch);return true}catch{return false}
 };
 const localRoutes=()=>Array.isArray(state.routes)&&state.routes.length?state.routes:
  state.route?[state.route]:[];
 const allRoutes=()=>{
  const remoteNumbers=new Set(remotePlans.map(x=>x.flightNumber));
  return [...remotePlans,...localRoutes().filter(x=>!remoteNumbers.has(x?.flightNumber))];
 };
 const normalizePlan=plan=>plan&&typeof plan.planId==='string'&&
  /^[A-Z0-9]{2}[0-9]{1,4}$/.test(plan.flightNumber||'')&&
  typeof plan.from?.key==='string'&&typeof plan.to?.key==='string'&&
  plan.from.key!==plan.to.key&&Array.isArray(plan.schedule)?{
   ...plan,serverPlanningId:plan.planId,
   status:'planning',storage:'server-planning',
   operationallyVerified:plan.serverScheduleStatus==='active'&&
    plan.serverScheduleOperationallyVerified===true&&
    typeof plan.serverScheduleId==='string'&&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(plan.serverScheduleId),
   serverScheduleId:typeof plan.serverScheduleId==='string'&&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(plan.serverScheduleId)?
     plan.serverScheduleId:null,
   slotsReserved:false,
   flights:plan.schedule.length,aircraftId:'owned:'+plan.aircraftInventoryId
  }:null;
 async function loadRemotePlans(){
  const airlineId=server.airline?.id,scheduler=server.scheduler;
  const ticket=++remotePlanTicket;
  if(!server.connected||!airlineId||typeof scheduler?.list!=='function'){
   remotePlans=[];
   message('operations-flight-readiness',
    'Airline database is not connected. Flight readiness cannot be verified.');
   renderRoutes();return;
  }
  try{
   const reply=await scheduler.list(airlineId);
   if(ticket!==remotePlanTicket)return;
   if(!Array.isArray(reply?.plans))throw Error('Plan list unavailable');
   remotePlans=reply.plans.map(normalizePlan).filter(Boolean);
   message('operations-flight-readiness',
    summarizeSection9FlightReadiness(reply).text);
   renderRoutes();
  }catch{
   if(ticket!==remotePlanTicket)return;
   remotePlans=[];
   message('operations-flight-readiness',
    'Airline flight readiness could not be verified. No flight activation was confirmed.');
   renderRoutes();
   message('operations-routes-feedback',
    'Server planning routes could not be loaded. Browser drafts are still visible; refresh when connected.');
  }
 }
 const message=(id,text)=>{if($(id))$(id).textContent=text};
 const partners=createSection9PartnerConsole({
  doc,host:$('operations-partner-console'),getServer:()=>server
 });
 const details=createSection9RouteDetails({
  doc,host:$('operations-route-detail'),getServer:()=>server,
  getRoutes:()=>allRoutes()
 });
 function renderRoutes(){
  const root=$('operations-route-list');if(!root)return;
  root.replaceChildren();
  const candidates=allRoutes();
  if(!candidates.length){
   const p=doc.createElement('p');p.className='hint';
   p.textContent='No saved route drafts. Use Create a route to prepare your first flight.';
   root.append(p);return;
  }
  const grid=doc.createElement('div');grid.className='operations-route-directory';
  const headings=['Flight','City to city','Departure','Arrival','Aircraft','Weekly days','Saved as','More'];
  const head=doc.createElement('div');head.className='operations-route-directory-row is-heading';
  for(const label of headings){
   const col=doc.createElement('span');col.textContent=label;head.append(col);
  }
  grid.append(head);
  const days=['Mo','Tu','We','Th','Fr','Sa','Su'];
  for(const [index,route] of candidates.entries()){
   if(!route?.from||!route?.to)continue;
   const row=doc.createElement('div');row.className='operations-route-directory-row';
   const add=text=>{
    const cell=doc.createElement('span');
    cell.textContent=String(text??'—');row.append(cell);return cell;
   };
   add(route.flightNumber||'—');
   add((route.from.name||route.from.municipality||'—')+' → '+
    (route.to.name||route.to.municipality||'—'));
   const schedule=Array.isArray(route.schedule)?route.schedule.filter(x=>
    Number.isInteger(x?.day)&&x.day>=0&&x.day<=6&&/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(x.time)):[];
   const times=[...new Set(schedule.map(x=>x.time))];
   add(times.length===1?times[0]:times.length>1?'Varies':'—');
   add('Pending');
   add(route.aircraftLabel||'Not assigned');
   const weekdays=doc.createElement('span');weekdays.className='operations-route-weekdays';
   weekdays.setAttribute('aria-label','Days: '+(schedule.length?schedule.map(x=>days[x.day]).join(', '):'None selected'));
   for(let day=0;day<7;day++){
    const cell=doc.createElement('span');
    const active=schedule.some(f=>f.day===day);
    cell.className='operations-route-day'+(active?' is-active':'');
    cell.textContent=days[day];weekdays.append(cell);
   }
   row.append(weekdays);
   const state=doc.createElement('span');
   state.className='operations-route-save-type';
   state.textContent=route.serverScheduleId?
    (route.operationallyVerified?'Active schedule · bookings closed':
     'Server schedule draft · inactive'):
    route.serverPlanningId?'Airline planning draft':'Local planning draft';
   row.append(state);
   const link=doc.createElement('button');link.type='button';
   link.className='operations-route-open-text';
   link.dataset.opsRouteEdit=String(index);link.textContent='More information';
   row.append(link);grid.append(row);
  }
  root.append(grid);
 }
 function renderHubs(){
  const list=$('operations-hubs-list');if(!list)return;
  list.replaceChildren();
  const hubs=Array.isArray(state.hubs)?state.hubs:[];
  if(!hubs.length){const p=doc.createElement('p');p.className='hint';p.textContent='No planned additional hubs. Your verified home airport remains your current base.';list.append(p);}
  for(const [i,h] of hubs.entries()){
   const row=doc.createElement('div');row.className='operations-saved-row';
   const title=doc.createElement('strong');title.textContent=escText(h.name)+' ('+escText(h.code||'-')+')';
   const note=doc.createElement('span');note.textContent='Proposed hub - NOT OPEN';
   const del=doc.createElement('button');del.type='button';del.dataset.opsHubRemove=String(i);del.textContent='Remove';del.className='secondary';
   row.append(title,note,del);list.append(row);
  }
 }
 function countries(){
  const select=$('operations-hub-country');if(!select)return;
  const previous=select.value;
  select.replaceChildren(new Option('Choose country',''));
  const names=new Intl.DisplayNames(['en'],{type:'region'});
  for(const entry of [...server.countries].filter(c=>/^[A-Z]{2}$/.test(c.countryIso||'')).
    sort((a,b)=>names.of(a.countryIso).localeCompare(names.of(b.countryIso),'en'))){
   select.add(new Option(names.of(entry.countryIso)+' ('+entry.airportCount+' airports)',entry.countryIso));
  }
  if([...select.options].some(o=>o.value===previous))select.value=previous;
 }
 async function findHub(){
  const country=$('operations-hub-country')?.value,query=$('operations-hub-search')?.value.trim()||'';
  const select=$('operations-hub-result');select.replaceChildren(new Option('Search first',''));select.disabled=true;
  if(!/^[A-Z]{2}$/.test(country)){message('operations-hub-feedback','Choose a country first.');return;}
  if(!server.reader){message('operations-hub-feedback','Approved airport directory is not connected.');return;}
  message('operations-hub-feedback','Searching approved airports...');
  try{
   const response=await server.reader.airports({countryIso:country,search:query,offset:0});
   if(response.countryIso!==country||!Array.isArray(response.airports))throw Error('Unexpected response');
   select.replaceChildren(new Option('Select approved airport',''));
   for(const a of response.airports){
    if(typeof a.key!=='string'||typeof a.name!=='string')continue;
    const option=new Option(a.name+' ('+(a.code||'-')+')',a.key);
    option.dataset.name=a.name;option.dataset.code=a.code||'-';select.append(option);
   }
   select.disabled=response.airports.length===0;
   message('operations-hub-feedback',response.airports.length?'Select an airport and save a planned hub.':'No matching approved airports.');
  }catch{message('operations-hub-feedback','Airport search failed. Try again.');}
 }
 const staffRows=Object.entries(STAFF_DEPARTMENTS).flatMap(([dep,roles])=>roles.map(([title,desc])=>({dep,title,desc})));
 function formPayroll(){
  const result=staffRows.map((item,i)=>({count:Number($('ops-staff-count-'+i)?.value||0),salary:Number($('ops-staff-salary-'+i)?.value||0)}));
  return {rows:result,total:payrollEstimate(result)};
 }
 function updateStaffTotals(){
  const {total}=formPayroll();
  message('ops-staff-people',total?String(total.people):'Check amounts');
  message('ops-staff-monthly',total?money(total.monthly):'Invalid');
  message('ops-staff-annual',total?money(total.yearly):'Invalid');
 }
 function initStaff(){
  const host=$('ops-staff-roles');if(!host)return;
  host.replaceChildren();
  let cursor=0;
  for(const [department,roles] of Object.entries(STAFF_DEPARTMENTS)){
   const details=doc.createElement('details');details.className='operations-staff-department';
   if(cursor===0)details.open=true;
   const summary=doc.createElement('summary');summary.textContent=department+' ('+roles.length+' roles)';
   details.append(summary);
   const table=doc.createElement('div');table.className='operations-staff-table';
   const heading=doc.createElement('div');heading.className='operations-staff-heading';
   for(const label of ['Role and responsibilities','Planned staff','Monthly salary (USD)']){
    const cell=doc.createElement('strong');cell.textContent=label;heading.append(cell);
   }
   table.append(heading);
   for(const [title,desc] of roles){
    const i=cursor++;
    const row=doc.createElement('div');row.className='operations-staff-row';
    const name=doc.createElement('div'),strong=doc.createElement('strong'),hint=doc.createElement('small');
    strong.textContent=title;hint.textContent=desc;name.append(strong,hint);
    const count=doc.createElement('input');count.id='ops-staff-count-'+i;count.type='number';
    count.min='0';count.max='10000';count.step='1';count.value='0';
    count.setAttribute('aria-label',title+' planned headcount');
    const salary=doc.createElement('input');salary.id='ops-staff-salary-'+i;salary.type='number';
    salary.min='0';salary.max='1000000';salary.step='1';salary.value='0';
    salary.setAttribute('aria-label',title+' monthly salary USD');
    row.append(name,count,salary);table.append(row);
   }
   details.append(table);host.append(details);
  }
  const stored=Array.isArray(state.staff)?state.staff:[];
  stored.slice(0,staffRows.length).forEach((item,i)=>{
   if(Number.isInteger(item?.count)&&item.count>=0&&item.count<=10000)$('ops-staff-count-'+i).value=String(item.count);
   if(Number.isFinite(item?.salary)&&item.salary>=0&&item.salary<=1000000)$('ops-staff-salary-'+i).value=String(item.salary);
  });
  host.addEventListener('input',updateStaffTotals);
  updateStaffTotals();
 }
 function priceValues(){
  return {cabin:$('ops-price-class')?.value,
    seats:Number($('ops-price-seat')?.value),price:Number($('ops-price-fare')?.value),
    occupancy:Number($('ops-price-load')?.value),flights:Number($('ops-price-flights')?.value),
    cost:Number($('ops-price-cost')?.value)};
 }
 function priceResults(){
  const p=priceValues();
  const estimate=ticketRevenueEstimate(p);
  const target=$('ops-price-results');if(target)target.replaceChildren();
  if(!estimate){message('ops-price-feedback','Check seats, prices, load factor (0-100%), frequency and operating costs.');return null;}
  const rows=[
   ['Scenario passengers / week',String(estimate.passengers)],
   ['Scenario fare revenue / week',money(estimate.revenue)],
   ['Assumed flight costs / week',money(estimate.costs)],
   ['Scenario operating margin / week',money(estimate.net)]
  ];
  if(target)for(const [label,value] of rows){
   const div=doc.createElement('div');div.className='detail-row';
   const name=doc.createElement('span');name.textContent=label;
   const figure=doc.createElement('strong');figure.textContent=value;
   div.append(name,figure);target.append(div);
  }
  message('ops-price-feedback','Calculation uses your inputs only. It is not a live fare, booking or demand prediction.');
  return {values:p,estimate};
 }
 function updateData(value){
  server={...server,...value};
  playerStore=value?.playerDraftStore||null;
  state=playerStore?.ready('workplan')?playerStore.snapshot('workplan'):{};
  const savedPrice=state.ticketPrice;
  if(savedPrice&&typeof savedPrice==='object')
   for(const [id,key] of [['ops-price-seat','seats'],['ops-price-fare','price'],
    ['ops-price-load','occupancy'],['ops-price-flights','flights'],
    ['ops-price-cost','cost'],['ops-price-class','cabin']])
    if($(id)&&savedPrice[key]!==undefined)$(id).value=String(savedPrice[key]);
  initStaff();countries();
  const home=server.airline?.homeAirportName?
   server.airline.homeAirportName+' ('+(server.airline.homeAirportCode||'-')+')':
   'Not available';message('operations-home-airport',server.connected?home:'Not connected');
  renderRoutes();renderHubs();void partners.refresh();
  if(server.airline?.id!==loadedPlanAirline||server.scheduler!==loadedPlanScheduler){
   loadedPlanAirline=server.airline?.id||null;loadedPlanScheduler=server.scheduler;
   void loadRemotePlans();
  }
  airportOfficeController?.updateData(value);
 }
 const main=$('player-main');
 main?.addEventListener('click',async e=>{
  const target=e.target.closest('button');if(!target)return;
  if(target.dataset.opsPage){goTo?.(target.dataset.opsPage);return;}
  if(target.dataset.opsRouteEdit!==undefined){
   const i=Number(target.dataset.opsRouteEdit);
   const candidates=allRoutes();
   if(!Number.isInteger(i)||i<0||i>=candidates.length)return;
   goTo?.('route-details');
   void details.open(i);
   const plan=allRoutes()[i];
   const saveButton=$('operations-route-publish-plan');
   if(saveButton){
    saveButton.hidden=Boolean(plan?.serverPlanningId||plan?.serverScheduleId)||
     typeof server.scheduler?.planSave!=='function';
    saveButton.disabled=false;
   }
   message('operations-route-detail-save-status','');
   if($('operations-route-cancel-confirm'))$('operations-route-cancel-confirm').hidden=true;
   return;
  }
  if(target.id==='operations-route-edit-from-details'){
   const i=details.index(),route=allRoutes()[i];
   if(Number.isInteger(i)&&route){
    goTo?.('routes');
    doc.dispatchEvent(new CustomEvent('airlinerra:edit-route-draft',{detail:{route}}));
   }
   return;
  }
  if(target.id==='operations-route-cancel-open'){
   const route=allRoutes()[details.index()];
   const confirmation=$('operations-route-cancel-confirm');
   if(!route||!confirmation)return;
   if(route.serverScheduleId){
    confirmation.hidden=true;
    message('operations-route-detail-save-status',
     'This route has reserved airport slots. Cancellation remains unavailable until passenger and slot release checks are connected. Nothing changed.');
    return;
   }
   if(route.serverPlanningId&&
    (!server.airline?.id||typeof server.scheduler?.planDelete!=='function')){
    confirmation.hidden=true;
    message('operations-route-detail-save-status',
     'Protected planning-route cancellation is not connected. Nothing changed.');
    return;
   }
   confirmation.hidden=false;
   message('operations-route-cancel-info','Cancel '+String(route.flightNumber||'this route')+
    '? This is an inactive planning route with no passenger bookings or reserved airport slots. Its planned departures will be removed.');
   return;
  }
  if(target.id==='operations-route-cancel-dismiss'){
   const confirmation=$('operations-route-cancel-confirm');
   if(confirmation)confirmation.hidden=true;
   return;
  }
  if(target.id==='operations-route-cancel-confirm-button'){
   const i=details.index(),route=allRoutes()[i];
   const confirmation=$('operations-route-cancel-confirm');
   if(!route||route.serverScheduleId||typeof route.flightNumber!=='string'){
    if(confirmation)confirmation.hidden=true;
    message('operations-route-detail-save-status','Cancellation not available. No route changed.');
    return;
   }
   const number=route.flightNumber;
   const serverPlanningId=route.serverPlanningId||null;
   if(serverPlanningId){
    if(!server.airline?.id||typeof server.scheduler?.planDelete!=='function'){
     message('operations-route-detail-save-status',
      'Server cancellation connection unavailable. Nothing changed.');return;
    }
    target.disabled=true;
    message('operations-route-detail-save-status','Cancelling inactive server planning route…');
    try{
     const response=await server.scheduler.planDelete({
      airlineId:server.airline.id,planId:serverPlanningId
     });
     if(response?.deleted!==true||response.planId!==serverPlanningId)
      throw Error('Unconfirmed planning route cancellation');
     remotePlans=remotePlans.filter(p=>p.serverPlanningId!==serverPlanningId);
    }catch{
     message('operations-route-detail-save-status',
      'Cancellation not confirmed by the airline database. No route has been removed locally.');
     target.disabled=false;return;
    }
    target.disabled=false;
   }
   const previous=localRoutes(),next=previous.filter(r=>r?.flightNumber!==number);
   const hadLocal=next.length!==previous.length;
   if(hadLocal){
    const oldState=state;
    state={...state,routes:next,route:state.route?.flightNumber===number?null:state.route};
    if(!await persist('routes','route')){
     state=oldState;
     if(confirmation)confirmation.hidden=true;
     renderRoutes();
     message('operations-route-detail-save-status',
      serverPlanningId?'Server planning route cancelled, but the stored workspace draft could not be updated. Refresh My Routes to reconcile.':
      'NOT SAVED — Supabase could not confirm draft cancellation.');
     return;
    }
   }else if(!serverPlanningId){
    if(confirmation)confirmation.hidden=true;
    message('operations-route-detail-save-status','Draft already unavailable. Nothing changed.');
    return;
   }
   if(confirmation)confirmation.hidden=true;
   renderRoutes();
   goTo?.('route-list');
   message('operations-routes-feedback',number+
    ' inactive planning route cancelled. Planned departures removed. No booked flights, passengers, airport slots or finances were changed.');
   doc.dispatchEvent(new CustomEvent('airlinerra:route-draft-cancelled',
    {detail:{flightNumber:number,serverSaved:Boolean(serverPlanningId)}}));
   if(serverPlanningId)void loadRemotePlans();
   return;
  }
  if(target.dataset.opsRouteRemove!==undefined){
   const i=Number(target.dataset.opsRouteRemove);
   const rows=Array.isArray(state.routes)&&state.routes.length?state.routes:state.route?[state.route]:[];
   if(!Number.isInteger(i)||i<0||i>=rows.length)return;
   const previous=state;
    state={...state,routes:rows.filter((_,n)=>n!==i),route:null};
    if(!await persist('routes','route')){
     state=previous;message('operations-routes-feedback','NOT SAVED — database did not confirm draft deletion.');return;
    }
    renderRoutes();
   message('operations-routes-feedback','Route draft deleted from your Supabase workplan.');return;
  }
  if(target.id==='operations-route-publish-plan'){
   const i=details.index(),route=allRoutes()[i];
   const scheduler=server.scheduler,airlineId=server.airline?.id;
   if(!route||!airlineId||typeof scheduler?.planSave!=='function'||
      route.serverPlanningId||route.serverScheduleId)return;
   if(!route.aircraftId?.startsWith('owned:')||!route.operation||
      route.from?.key===route.to?.key){
    message('operations-route-detail-save-status','This workplan draft is missing a verified aircraft, two airports, or operating options.');
    return;
   }
   target.disabled=true;
   message('operations-route-detail-save-status','Saving your existing route to the airline database...');
   try{
    const result=await scheduler.planSave({
     airlineId,aircraftInventoryId:route.aircraftId.slice(6),
     flightNumber:route.flightNumber,originAirportKey:route.from.key,
     destinationAirportKey:route.to.key,weeklySchedule:route.schedule,
     departureStand:route.operation.departureStand??null,
     arrivalStand:route.operation.arrivalStand,
     turnaroundMinutes:route.operation.turnaroundMinutes,
     fares:route.operation.fares,service:route.operation.service,
     launchDelayDays:[0,3,7].includes(route.launchDelayDays)?route.launchDelayDays:0,
     referenceDepartureUtc:route.referenceDepartureUtc&&route.referenceArrivalUtc?
      route.referenceDepartureUtc:null,
     referenceArrivalUtc:route.referenceDepartureUtc&&route.referenceArrivalUtc?
      route.referenceArrivalUtc:null
    });
    if(result?.status!=='planning'||typeof result.planId!=='string'||
       result.canActivateNormalFlight!==false||result.slotsReserved!==false)
     throw Error('Unverified planning save');
    const local=localRoutes().map(x=>x.flightNumber===route.flightNumber?{
     ...x,serverPlanningId:result.planId,storage:'server-planning'
    }:x);
    state={...state,routes:local};
    const mirrored=await persist('routes');
    await loadRemotePlans();
    message('operations-route-detail-save-status',
     route.flightNumber+' is saved in your airline database. '+
      (mirrored?'Supporting draft details also saved.':'Supporting draft mirror could not be verified.')+
      ' No slots or flights activated.');
    target.hidden=true;
   }catch{
    message('operations-route-detail-save-status',
     'NOT SAVED — the airline server rejected this planning route. Review aircraft and airport permissions.');
    target.disabled=false;
   }
   return;
  }
  if(target.dataset.opsHubRemove!==undefined){
   const i=Number(target.dataset.opsHubRemove);
   const hubs=Array.isArray(state.hubs)?state.hubs:[];
   if(!Number.isInteger(i)||i<0||i>=hubs.length)return;
   const previous=state;state={...state,hubs:hubs.filter((_,n)=>n!==i)};
    if(!await persist('hubs')){state=previous;message('operations-hub-feedback','NOT SAVED — database hub draft deletion failed.');return}
    renderHubs();return;
  }
  const id=target.id;
  if(id==='operations-hub-find')await findHub();
  if(id==='operations-hub-save'){
   const select=$('operations-hub-result'),opt=select?.selectedOptions?.[0];
   if(!server.connected||!server.airline?.id||!opt||!select.value||select.disabled){
    message('operations-hub-feedback','Choose an approved airport first.');return;
   }
   const hubs=Array.isArray(state.hubs)?state.hubs:[];
   if(hubs.length>=10){message('operations-hub-feedback','Maximum 10 planned hubs per airline draft.');return;}
   const hub={key:select.value,name:opt.dataset.name,code:opt.dataset.code};
   if(hubs.some(x=>x.key===hub.key)||server.airline?.homeAirportKey===hub.key){
    message('operations-hub-feedback','That airport is already your home airport or planned hub.');return;
   }
   state={...state,hubs:[...hubs,hub]};
   const persisted=await persist('hubs');
   if(!persisted){state={...state,hubs};message('operations-hub-feedback','NOT SAVED — Supabase did not confirm this hub proposal.');return;}
   renderHubs();message('operations-hub-feedback','Hub proposal saved in Supabase as a draft. No real hub was opened.');
  }
  if(id==='ops-price-calc')priceResults();
  if(id==='ops-price-save'){
   const result=priceResults();if(!result)return;
   const previous=state;state={...state,ticketPrice:result.values};
    if(!await persist('ticketPrice')){state=previous;message('ops-price-feedback','NOT SAVED — Supabase did not confirm this fare scenario.');return}
   message('ops-price-feedback','Fare scenario saved in Supabase. No real prices were changed.');
  }
  if(id==='ops-staff-save'){
   const {rows,total}=formPayroll();
   if(!total){message('ops-staff-feedback','Enter valid non-negative headcounts and salaries.');return;}
   const previous=state;state={...state,staff:rows};
    if(!await persist('staff')){state=previous;message('ops-staff-feedback','NOT SAVED — Supabase did not confirm this staffing plan.');return}
    updateStaffTotals();
   message('ops-staff-feedback','Staffing plan saved in Supabase as a draft. No employee was hired or paid.');
  }
  if(id==='ops-staff-reset'){
   const previous=state;state={...state,staff:[]};
    if(!await persist('staff')){state=previous;message('ops-staff-feedback','NOT SAVED — database did not confirm staffing reset.');return}
   staffRows.forEach((_,i)=>{$('ops-staff-count-'+i).value='0';$('ops-staff-salary-'+i).value='0';});
   updateStaffTotals();message('ops-staff-feedback','Staffing plan cleared in Supabase.');return;
  }
 });
 // The schedule timetable links to the existing route-details page,
 // not to an unactivated live-flight simulator.
 doc.addEventListener('airlinerra:schedule-open-flight',event=>{
  const flightNumber=event.detail?.flightNumber;
  if(!/^[A-Z0-9]{2}[0-9]{1,4}$/.test(flightNumber||''))return;
  const routes=allRoutes();
  const index=routes.findIndex(x=>x.flightNumber===flightNumber);
  if(index<0){
   goTo?.('route-list');
   message('operations-routes-feedback',
    flightNumber+' has no matching saved route details here yet. Flight operation is not activated.');
   return;
  }
  goTo?.('route-details');
  void details.open(index);
  const plan=routes[index],saveButton=$('operations-route-publish-plan');
  if(saveButton){
   saveButton.hidden=Boolean(plan?.serverPlanningId||plan?.serverScheduleId)||
    typeof server.scheduler?.planSave!=='function';
   saveButton.disabled=false;
  }
 });
 doc.addEventListener('airlinerra:route-draft-saved',event=>{
  state=playerStore?.ready('workplan')?playerStore.snapshot('workplan'):{};renderRoutes();void details.refresh();
  const flight=typeof event?.detail?.flightNumber==='string'?event.detail.flightNumber:'Route';
  message('operations-routes-feedback',event?.detail?.serverSaved?
   flight+' saved in the airline database as an inactive planning route. No flight or slot was activated.':
   flight+' saved as a non-operational planning draft in Supabase. No server flight was created.');
  if(event?.detail?.serverSaved)void loadRemotePlans();
 });
 const prices=state.ticketPrice;
 if(prices&&typeof prices==='object'){
  for(const [id,key] of [['ops-price-seat','seats'],['ops-price-fare','price'],
   ['ops-price-load','occupancy'],['ops-price-flights','flights'],
   ['ops-price-cost','cost'],['ops-price-class','cabin']]){
   if($(id)&&prices[key]!==undefined)$(id).value=String(prices[key]);
  }
 }
 initStaff();renderRoutes();renderHubs();
 const airportOfficeController=createAirportOffice({doc,identity,session,goTo,getAirlineLogoUrl});
 return Object.freeze({updateData,openAirport:airport=>airportOfficeController.openAirport(airport),refreshAirlineLogo:()=>airportOfficeController.refreshAirlineLogo()});
}
