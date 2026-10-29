/** Account-local airline operations planning.
 * No hiring, flight, price, hub or route mutation calls. Only authenticated
 * World 1 reads for approved airport lookup; drafts live in sessionStorage.
 */
import {createAirportOffice} from './airline-airports-office.mjs';
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
function storageRead(storage,key){
 try{const s=storage?.getItem(key);return s?JSON.parse(s):{}}catch{return {}}
}
function storageWrite(storage,key,state){
 try{storage?.setItem(key,JSON.stringify(state));return true}catch{return false}
}
const card=(title,body,kicker='OPERATIONS PLANNING')=>'<article class="panel workspace-panel"><span class="panel-kicker">'+kicker+'</span><h2>'+title+'</h2>'+body+'</article>';
export function createOperationsCenter({doc,identity,session,goTo}={}){
 if(!doc||!identity||typeof identity!=='string'||!/^[\w-]{3,128}$/.test(identity))throw Error('Verified account required');
 const key='airlinerra.local.workplan.v1.'+identity;
 const $=id=>doc.getElementById(id);
 let server={connected:false,reader:null,countries:[],airline:null};
 const root={
  'route-list':$('workspace-route-list'),
  'hubs':$('workspace-hubs'),
  'tickets':$('workspace-tickets'),
  'staff':$('workspace-staff')
 };
 if(root['route-list'])root['route-list'].innerHTML=card('My routes',
  '<p class="hint">Saved route ideas in this browser tab. Live network routes will appear only when the protected route engine is connected.</p>'+
  '<div id="operations-route-list" class="operations-route-table"></div>'+
  '<div class="workspace-actions"><button type="button" class="secondary" data-ops-page="routes">Create a route</button></div>'+
  '<p id="operations-routes-feedback" class="hint" role="status"></p>',
  'ROUTE DIRECTORY');
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
 let state=storageRead(session,key);
 const persist=()=>storageWrite(session,key,{...storageRead(session,key),...state});
 const message=(id,text)=>{if($(id))$(id).textContent=text};
 function renderRoutes(){
  const root=$('operations-route-list');if(!root)return;
  root.replaceChildren();
  const candidates=Array.isArray(state.routes)&&state.routes.length?state.routes:state.route?[state.route]:[];
  if(!candidates.length){const p=doc.createElement('p');p.className='hint';p.textContent='No route drafts saved yet. Use Create a route to plan your first destination.';root.append(p);return;}
  for(const [index,route] of candidates.entries()){
   if(!route?.from||!route?.to)continue;
   const row=doc.createElement('div');row.className='operations-saved-row';
   const title=doc.createElement('strong');
   title.textContent=escText(route.from.code||route.from.name)+' - '+escText(route.to.code||route.to.name);
   const note=doc.createElement('span');note.textContent=String(route.flights||0)+' proposed departures/week - LOCAL DRAFT';
   const del=doc.createElement('button');del.type='button';del.className='secondary';del.dataset.opsRouteRemove=String(index);del.textContent='Remove draft';
   row.append(title,note,del);root.append(row);
  }
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
  server={...server,...value};countries();
  const home=server.airline?.homeAirportName?
   server.airline.homeAirportName+' ('+(server.airline.homeAirportCode||'-')+')':
   'Not available';message('operations-home-airport',server.connected?home:'Not connected');
  renderRoutes();renderHubs();
  airportOfficeController?.updateData(value);
 }
 const main=$('player-main');
 main?.addEventListener('click',async e=>{
  const target=e.target.closest('button');if(!target)return;
  if(target.dataset.opsPage){goTo?.(target.dataset.opsPage);return;}
  if(target.dataset.opsRouteRemove!==undefined){
   const i=Number(target.dataset.opsRouteRemove);
   const rows=Array.isArray(state.routes)&&state.routes.length?state.routes:state.route?[state.route]:[];
   if(!Number.isInteger(i)||i<0||i>=rows.length)return;
   state={...state,routes:rows.filter((_,n)=>n!==i),route:null};persist();renderRoutes();
   message('operations-routes-feedback','Route draft deleted from this browser tab.');return;
  }
  if(target.dataset.opsHubRemove!==undefined){
   const i=Number(target.dataset.opsHubRemove);
   const hubs=Array.isArray(state.hubs)?state.hubs:[];
   if(!Number.isInteger(i)||i<0||i>=hubs.length)return;
   state={...state,hubs:hubs.filter((_,n)=>n!==i)};persist();renderHubs();return;
  }
  const id=target.id;
  if(id==='operations-hub-find')await findHub();
  if(id==='operations-hub-save'){
   const select=$('operations-hub-result'),opt=select?.selectedOptions?.[0];
   if(!server.connected||!server.airline?.id||!opt||!select.value||select.disabled){
    message('operations-hub-feedback','Choose an approved airport first.');return;
   }
   const hubs=Array.isArray(state.hubs)?state.hubs:[];
   if(hubs.length>=10){message('operations-hub-feedback','Maximum 10 planned hubs per browser tab.');return;}
   const hub={key:select.value,name:opt.dataset.name,code:opt.dataset.code};
   if(hubs.some(x=>x.key===hub.key)||server.airline?.homeAirportKey===hub.key){
    message('operations-hub-feedback','That airport is already your home airport or planned hub.');return;
   }
   state={...state,hubs:[...hubs,hub]};
   const persisted=persist();renderHubs();
   if(!persisted){message('operations-hub-feedback','Browser storage is unavailable. The draft will only remain in this session.');return;}
   message('operations-hub-feedback','Hub draft saved locally. No real hub was opened.');
  }
  if(id==='ops-price-calc')priceResults();
  if(id==='ops-price-save'){
   const result=priceResults();if(!result)return;
   state={...state,ticketPrice:result.values};persist();
   message('ops-price-feedback','Fare scenario saved in this browser tab. No real prices were changed.');
  }
  if(id==='ops-staff-save'){
   const {rows,total}=formPayroll();
   if(!total){message('ops-staff-feedback','Enter valid non-negative headcounts and salaries.');return;}
   state={...state,staff:rows};persist();updateStaffTotals();
   message('ops-staff-feedback','Staffing plan saved locally. No employee was hired or paid.');
  }
  if(id==='ops-staff-reset'){
   state={...state,staff:[]};persist();
   staffRows.forEach((_,i)=>{$('ops-staff-count-'+i).value='0';$('ops-staff-salary-'+i).value='0';});
   updateStaffTotals();message('ops-staff-feedback','Staffing plan cleared.');return;
  }
 });
 doc.addEventListener('airlinerra:route-draft-saved',()=>{
  state=storageRead(session,key);renderRoutes();
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
 const airportOfficeController=createAirportOffice({doc,identity,session,goTo});
 return Object.freeze({updateData,openAirport:airport=>airportOfficeController.openAirport(airport)});
}
