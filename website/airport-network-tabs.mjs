/** Read-only airport network UI: illustrative airline and flight previews until live scheduling exists.
 * Never presents demo airlines, mock movement counts, or sample timetables as real operations.
 */
const NS='http://www.w3.org/2000/svg';
const VIEWS=Object.freeze(['airlines','statistics','destinations','cargo']);
const WEEKDAY=['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
const SCHEDULE_DAYS=[
 ['Mon','Wed','Fri'],['Tue','Thu','Sat'],['Mon','Thu'],['Tue','Fri'],
 ['Wed','Sat'],['Mon','Fri'],['Tue','Thu','Sun'],['Wed','Sat'],
 ['Mon','Thu','Sat'],['Tue','Fri','Sun']
];
const swatches=[
 ['#082e64','#ff6917'],['#18366b','#87e3f2'],['#30345b','#ffb569'],
 ['#104b69','#ff6917'],['#2e416b','#75c9dd'],['#0d4871','#f9b36d'],
 ['#092b57','#ff6917'],['#17446b','#80b5eb'],['#174377','#f1a365'],['#1d4763','#ffc07f']
];
const el=(doc,tag,cls,text)=>{
 const node=doc.createElement(tag);
 if(cls)node.className=cls;
 if(text!==undefined)node.textContent=String(text);
 return node;
};
const svgEl=(doc,tag,attrs={})=>{
 const node=doc.createElementNS(NS,tag);
 for(const [name,value] of Object.entries(attrs))node.setAttribute(name,String(value));
 return node;
};
export function createAirportAirlineLogo(doc,name,verifiedLogoUrl=null){
 const logo=el(doc,'span','airport-airline-logo-crop');
 // A short-lived URL may only come from the authenticated owner's storage read.
 // Never derive another user's private storage path from their airline name.
 const signedPrefix='https://hwllkabgzaynalahvkpz.supabase.co/storage/v1/object/sign/airlinerra-airline-logos/';
 if(typeof verifiedLogoUrl==='string'&&verifiedLogoUrl.startsWith(signedPrefix)){
  const img=el(doc,'img','airport-airline-logo-actual');
  img.alt=name+' airline logo';
  img.src=verifiedLogoUrl;
  img.loading='lazy';img.decoding='async';
  logo.setAttribute('title',name+' current company logo');
  logo.append(img);
  return logo;
 }
 logo.setAttribute('role','img');
 logo.setAttribute('aria-label','Illustrative, unofficial '+name+' logo crop');
 const idx=Math.max(0,['Panonian','Aurora Connect','Silver Atlas Air','Danube Sky','Northwind Air',
  'Blue Meridian','Cloudpath Aviation','Alpine Star','Eastline Air'].indexOf(name));
 const [base,accent]=swatches[idx%swatches.length];
 const mark=svgEl(doc,'svg',{viewBox:'0 0 180 64','aria-hidden':'true',focusable:'false'});
 mark.append(svgEl(doc,'rect',{width:180,height:64,fill:base,rx:7}));
 mark.append(svgEl(doc,'path',{d:'M-15 52 Q36 8 97 48 T208 15',fill:'none',
  stroke:accent,'stroke-width':13,'stroke-linecap':'round'}));
 mark.append(svgEl(doc,'path',{d:'M-10 60 Q35 29 89 52 T208 25',fill:'none',
  stroke:'#fff','stroke-opacity':'.75','stroke-width':3}));
 const t=svgEl(doc,'text',{x:34,y:42,fill:'#fff','font-size':27,'font-weight':850,
  'font-family':'Arial, sans-serif','letter-spacing':'-1'});
 t.textContent=name.split(/\s+/).map(x=>x[0]).join('').slice(0,2).toUpperCase();
 mark.append(t);
 logo.append(mark);
 return logo;
}
export function sampleAirportDestinations(flights){
 return [...new Set(flights.map(f=>String(f.route||'').split('·').slice(1).join('·').trim())
  .filter(Boolean))].sort((a,b)=>a.localeCompare(b));
}
function airportLocalDate(timezone){
 const now=new Date();
 try{
  const parts=Object.fromEntries(new Intl.DateTimeFormat('en-GB',{timeZone:timezone,
   day:'2-digit',month:'2-digit',year:'numeric'}).formatToParts(now)
   .filter(x=>x.type!=='literal').map(x=>[x.type,x.value]));
  return new Date(Date.UTC(Number(parts.year),Number(parts.month)-1,Number(parts.day)));
 }catch{
  return new Date(Date.UTC(now.getUTCFullYear(),now.getUTCMonth(),now.getUTCDate()));
 }
}
function labels(doc,headers,values,empty){
 const grid=el(doc,'div','airport-network-data-table');
 grid.dataset.columns=String(headers.length);
 const top=el(doc,'div','airport-network-data-row airport-network-data-head');
 for(const title of headers)top.append(el(doc,'span','',title));
 grid.append(top);
 if(!values.length){
  grid.append(el(doc,'p','airport-network-empty',empty||'No entries available'));
  return grid;
 }
 for(const row of values){
  const line=el(doc,'div','airport-network-data-row');
  for(const value of row)line.append(el(doc,'span','',value));
  grid.append(line);
 }
 return grid;
}
const note=(doc,text)=>el(doc,'p','airport-network-note',text);
const item=(doc,title,value)=>{
 const div=el(doc,'div','airport-network-metric');
 div.append(el(doc,'span','',title),el(doc,'strong','',value));
 return div;
};
const formatAmount=(n,suffix='')=>typeof n==='number'&&Number.isFinite(n)&&n>=0?
 new Intl.NumberFormat('en-US',{notation:'compact',maximumFractionDigits:n>=1e6?1:0}).format(n)+suffix:'—';
export function createAirportNetworkTabs({doc,host,flights=[]}={}){
 if(!host)return {setAirport:()=>{}};
 let airport=null,detail=null,active='airlines',destination='';
 let ownAirlineName='',ownLogoUrl=null;
 const logoFor=name=>name===ownAirlineName?ownLogoUrl:null;
 const tabs=el(doc,'div','airport-network-tabs');
 tabs.setAttribute('role','tablist');tabs.setAttribute('aria-label','Airport network information');
 const buttons=new Map();
 for(const [value,label] of [['airlines','Airlines'],['statistics','Statistics'],
  ['destinations','Destinations'],['cargo','Cargo']]){
  const button=el(doc,'button','airport-network-tab',label);
  button.type='button';button.dataset.airportNetworkTab=value;
  button.setAttribute('role','tab');button.setAttribute('aria-controls','airport-network-content');
  tabs.append(button);buttons.set(value,button);
 }
 const pane=el(doc,'section','airport-network-content');
 pane.id='airport-network-content';pane.setAttribute('role','tabpanel');
 host.replaceChildren(tabs,pane);
 const carrierRows=()=>[...new Set(flights.map(f=>f.airline))].map(name=>({
  name,examples:flights.filter(f=>f.airline===name).length
 }));
 function renderDayGroups(destinationFilter=null){
  const base=airportLocalDate(detail?.timezone||'Europe/Berlin');
  const root=el(doc,'div','airport-network-week-list');
  for(let offset=0;offset<7;offset++){
   const day=new Date(base.getTime()+offset*86400000);
   const weekday=WEEKDAY[day.getUTCDay()];
   const title=new Intl.DateTimeFormat('en-GB',{
    timeZone:'UTC',weekday:'long',day:'numeric',month:'long'
   }).format(day);
   const section=el(doc,'section','airport-network-day');
   section.append(el(doc,'h3','airport-network-day-title',title));
   const entries=flights.map((f,i)=>({...f,index:i})).filter(f=>
    (destinationFilter===null||f.route.split('·').slice(1).join('·').trim()===destinationFilter)
    && SCHEDULE_DAYS[f.index%SCHEDULE_DAYS.length].includes(weekday));
   if(!entries.length)section.append(el(doc,'p','airport-network-day-empty','No sample flights'));
   for(const flight of entries){
    const line=el(doc,'div','airport-network-day-flight');
    line.append(el(doc,'span','airport-network-day-time',flight.time),
     el(doc,'span','airport-network-day-number',flight.flight),
     el(doc,'span','airport-network-day-airline',flight.airline),
     createAirportAirlineLogo(doc,flight.airline,logoFor(flight.airline)),
     el(doc,'span','airport-network-day-route',flight.route));
    section.append(line);
   }
   root.append(section);
  }
  return root;
 }
 function showAirlines(){
  pane.append(note(doc,'Fictional airlines and example flight counts. Actual airline operations will be listed when schedules are available.'));
  const list=el(doc,'div','airport-network-airline-list');
  for(const airline of carrierRows()){
   const line=el(doc,'div','airport-network-airline-row');
   line.append(el(doc,'span','airport-network-airline-name',airline.name),
    createAirportAirlineLogo(doc,airline.name,logoFor(airline.name)),
    el(doc,'span','airport-network-airline-operations',
     airline.examples+' example '+(airline.examples===1?'flight':'flights')+' on preview board'));
   list.append(line);
  }
  pane.append(list);
 }
 function showStatistics(){
  pane.append(note(doc,'Daily flight activity below is fictional until real airline schedules and completed-flight statistics are connected.'));
  pane.append(renderDayGroups());
  const metrics=el(doc,'div','airport-network-metrics airport-network-bottom-metrics');
  metrics.append(item(doc,'Annual departing passengers',formatAmount(detail?.demand?.annualDepartingPassengers)),
   item(doc,'Registered airline headquarters',
    Number.isInteger(detail?.airportActivity?.registeredHeadquarters)?
     String(detail.airportActivity.registeredHeadquarters):'—'),
   item(doc,'Real daily airline data','Awaiting operations'));
  pane.append(metrics);
 }
 function showDestinations(){
  const origin=el(doc,'div','airport-network-origin');
  origin.append(el(doc,'span','','Origin airport'),
   el(doc,'strong','',airport?.name||'Select an airport'));
  pane.append(origin,note(doc,'Fictional flight schedule for the next seven days; no real bookings or scheduled flights.'));
  const selector=el(doc,'div','airport-network-destination-control');
  const lab=el(doc,'label','','Destination');
  lab.htmlFor='airport-network-destination-select';
  const select=el(doc,'select');select.id='airport-network-destination-select';
  const places=sampleAirportDestinations(flights);
  if(!places.includes(destination))destination=places[0]||'';
  for(const place of places){
   const option=el(doc,'option','',place);option.value=place;
   option.selected=place===destination;select.append(option);
  }
  selector.append(lab,select);pane.append(selector);
  pane.append(renderDayGroups(destination));
 }
 function showCargo(){
  pane.append(note(doc,'Real annual outbound cargo is shown below. Cargo carried by each airline will appear after flight and handling statistics become available.'));
  const metrics=el(doc,'div','airport-network-metrics');
  const tier=detail?.demand?.cargoGroup;
  metrics.append(item(doc,'Annual outbound cargo',formatAmount(detail?.demand?.annualOutboundCargoTonnes,' tonnes')),
   item(doc,'Cargo demand',Number.isInteger(tier)?'Group '+tier+' of 5':'—'),
   item(doc,'Cargo flights today','Awaiting operations'));
  pane.append(metrics);
  pane.append(labels(doc,['Cargo airline','Cargo carried today','Share'],[],
   'No airline cargo movements have been recorded.'));
 }
 function render(){
  for(const [view,button] of buttons){
   const selected=view===active;
   button.setAttribute('aria-selected',selected?'true':'false');
   button.tabIndex=selected?0:-1;
  }
  pane.replaceChildren();
  if(active==='airlines')showAirlines();
  if(active==='statistics')showStatistics();
  if(active==='destinations')showDestinations();
  if(active==='cargo')showCargo();
 }
 host.addEventListener('click',event=>{
  const button=event.target?.closest?.('[data-airport-network-tab]');
  if(!button||!host.contains(button)||!VIEWS.includes(button.dataset.airportNetworkTab))return;
  active=button.dataset.airportNetworkTab;render();
 });
 host.addEventListener('change',event=>{
  if(event.target?.id==='airport-network-destination-select'){
   destination=event.target.value;render();
  }
 });
 function setAirport(a,p){
  const changed=airport?.key!==a?.key;
  airport=a||null;detail=p||null;
  if(changed)destination='';
  render();
 }
 render();
 function setOwnerLogo(airlineName,url){
  ownAirlineName=typeof airlineName==='string'?airlineName:'';
  ownLogoUrl=typeof url==='string'?url:null;
  render();
 }
 return Object.freeze({setAirport,setOwnerLogo});
}
