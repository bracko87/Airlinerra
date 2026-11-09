/**
 * Airlinerra licence planning workspace.
 * Design-only: no requests, no grants, no payment and no inferred player eligibility.
 * Real permissions must come from the authenticated server.
 */
const define=(code,group,title,cost,processing,aircraft,application,approval,operation,unlocks,limits,validity,loss,recovery,notes='')=>Object.freeze({
 code,group,title,cost,processing,aircraft,application,approval,operation,unlocks,limits,validity,loss,recovery,notes
});
export const LICENCE_PLAN=Object.freeze([
 define('HOLDING_FORMATION','company','Holding company registration','$100,000','1 game day after release',
  'No aircraft required',
  ['An existing original airline owned by the player in this world','Original airline registered at least 60 elapsed calendar days ago (server clock)','No existing parent holding in this world','Holding name and eligible country selected','Holding has an authorised formation funding source'],
  ['Pay the formation fee from an authorised account','Meet the separate minimum holding reserve (amount awaiting balancing)','Pass ownership, world and legal formation checks'],
  ['Holding must receive real recorded funds before creating subsidiaries'],
  'Own the existing airline and later establish subsidiaries and a treasury',
  'Does not grant any flight or maintenance permissions; initially one holding per player per world',
  'Company registration persists; compliance and company existence still matter',
  'Holding formation is disabled if legally dissolved or restricted','Restore company compliance or complete permitted legal re-registration',
  'The 60-day threshold is based on real elapsed calendar days since airline registration, not the game-day clock.'),
 define('SUBSIDIARY_FORMATION','company','New subsidiary registration','$75,000','2 game days',
  'No aircraft required',
  ['Active and owned holding in the same world','Choose legal country and unique company name','Choose passenger, regional, cargo, charter/VIP or MRO business type','Holding has sufficient unreserved cash for fee and capital'],
  ['Pay $75,000 game registration fee separately from capital','Transfer planned subsidiary capital through the audited holding ledger','Meet local ownership and incorporation eligibility'],
  ['A new airline remains inactive until it receives its own operator permission','An MRO cannot offer maintenance until separately approved'],
  'Create and fund a legally separate company under the holding',
  'No inherited AOC, traffic rights, aircraft or staff from the original airline',
  'Registration persists while company legally exists',
  'Company may become inactive or be legally dissolved','Re-register if dissolved; otherwise restore compliance'),
 define('AIR_OPERATOR_CERTIFICATE','airline','Air Operator Certificate (AOC)','Original airline: included in activation · New subsidiary: $150,000','7 game days',
  'Apply: no aircraft. Final approval: at least 1 suitable delivered and inspected aircraft (owned or leased)',
  ['Registered airline in a supported home jurisdiction','Name and verified operating company identity','Appoint a safety manager and accountable operations manager','Sufficient cash for application and required reserves'],
  ['At least 1 correct passenger- or cargo-capable aircraft registered to this operator, delivered, inspected and service-ready','Qualified employed pilots for that aircraft configuration (count from aircraft rules)','Appropriate cabin crew where passengers are carried','Approved home base, safety procedures, operating manuals and maintenance arrangements','Maintain a proposed minimum $250,000 airline cash reserve after fees'],
  ['Before each flight: confirm valid crew, aircraft, maintenance, market rights, slots, runway and schedule restrictions'],
  'Commercial flying within approved aircraft and activity scope',
  'AOC does not give international market access, airport slots, or authority for unapproved aircraft/operations',
  'Ongoing, subject to safety and financial compliance; annual game compliance review',
  'Commercial departures needing the AOC stop immediately on suspension; existing schedules are kept',
  'Correct the failed conditions and pass reinspection; revocation requires a new application',
  'The same eligible aircraft can support multiple compatible approvals. New subsidiaries never inherit the original AOC.'),
 define('EU_AIRLINE_OPERATING_LICENCE','airline','EU commercial operating licence','Included in corresponding airline certification','Reviewed together with AOC',
  'No additional aircraft beyond the approved AOC fleet',
  ['Airline established in an eligible EU jurisdiction','Eligible ownership/control and business registration','AOC application or active AOC','Finances sufficient for the proposed operations'],
  ['Valid applicable AOC','Pass the economic/financial and ownership/control review','Approved passenger, cargo and/or mail commercial service scope'],
  ['Keep financial viability and operator permissions current'],
  'Commercial services in the approved scope as an eligible EU carrier',
  'No blanket access to non-EU markets or every airport; other country-specific rules still apply',
  'Ongoing while conditions remain satisfied; annual game review',
  'Commercial activity requiring the licence is suspended',
  'Restore financial/ownership compliance and valid AOC; reapply if revoked'),
 define('CARGO_OPERATIONS_SCOPE','airline','Cargo operations approval','$50,000','3 game days',
  'Apply: no purchase. Final approval: 1 cargo-capable, delivered and inspected aircraft; an existing suitable aircraft counts',
  ['Registered airline with applicable operator approval (or linked pending application)','Specify cargo types and aircraft configurations','Funds available for application fee'],
  ['1 cargo-capable aircraft in this airline fleet, delivered, inspected and ready','Qualified flight crew for that aircraft type','At least 1 cargo-handling arrangement at the operating home base','Trained responsible cargo/ground personnel and approved loading procedures'],
  ['Cargo space/weight limits, cargo handling access and airport/route market rights checked on every flight','Dangerous goods require separate authorisation where applicable'],
  'Carry ordinary commercial freight within the approved operating scope',
  'Cannot carry restricted dangerous goods automatically; no extra passenger or foreign route rights',
  'Ongoing with annual game compliance review',
  'Cargo services are blocked; unaffected passenger services may continue',
  'Restore suitable aircraft, crew/handling capability and complete review',
  'Buying an additional cargo aircraft is not required when the airline already has one that qualifies.'),
 define('CHARTER_VIP_SCOPE','airline','Charter / VIP operating scope','$40,000','3 game days',
  'Apply: no purchase. Final approval: 1 suitable delivered, inspected aircraft',
  ['Registered operator with a valid or pending AOC','Choose charter/VIP commercial service type','Funds available for the application'],
  ['Suitable operational aircraft allocated to the operator','Type-qualified flight crew and any required cabin staff','Charter passenger safety/service procedures approved'],
  ['Required country permits, aircraft suitability and airport slots still checked for every charter flight'],
  'Offer commercial charter/VIP flights in the approved scope',
  'No automatic right to serve closed or restricted foreign markets',
  'Ongoing with annual game compliance review',
  'Affected charter/VIP departures stop; other approved services continue',
  'Correct missing aircraft, staff or procedures; pass renewal review'),
 define('DANGEROUS_GOODS','airline','Dangerous-goods transport approval','$60,000','5 game days',
  'No separate aircraft purchase; qualifying cargo aircraft required before a dangerous-goods flight',
  ['Valid or pending cargo operating scope','Specify hazardous-goods classes to be carried','Responsible cargo compliance manager appointed'],
  ['Staff trained for permitted goods classes','Procedures, safe packaging/handling and emergency response capability','Any authority-specific approval or exemption required for the selected goods class'],
  ['Each flight verifies approved goods class, aircraft limitations, handlers and route/airport restrictions'],
  'Transport only the specifically approved dangerous-goods classes',
  'Other goods classes, incompatible aircraft and barred airports remain prohibited',
  'Annual game review, plus any shorter authority-specific expiry',
  'Affected dangerous-goods shipments stop; ordinary cargo may continue',
  'Retrain staff, correct procedures and requalify the relevant goods classes'),
 define('DOMESTIC_TRAFFIC','market','Home-country domestic traffic rights','No separate fee when verified','Immediate if eligible',
  'No additional aircraft required to obtain market entitlement',
  ['Valid operator approval for the airline nationality and activity','Selected market lies within the home-country or authorised common market','Game market policy confirms permission'],
  ['Verify home-market authorisation and allowed passenger/cargo scope'],
  ['Every specific airport pair needs normal runway, schedule, slot and crew checks'],
  'Operate domestic flights where the operator is actually authorised',
  'Foreign domestic flights are not covered unless integrated-market or cabotage rights apply',
  'Ongoing while market and operator conditions remain valid',
  'Affected domestic schedules stop if underlying operator right is suspended',
  'Restore operator approval or market eligibility'),
 define('INTEGRATED_MARKET','market','Integrated aviation market access','No separate market fee when eligible','Immediate after verification',
  'No extra aircraft for market access',
  ['Valid operator licence and applicable AOC','Eligible carrier nationality and ownership/control','A verified common-aviation-market agreement covering this carrier and service'],
  ['Verify covered territories, service types and any exceptions'],
  ['Route activation still checks all airport and operator-specific restrictions'],
  'Use the verified common-market privileges without individual paid permits',
  'Not a universal right to operate outside the eligible integrated market',
  'While carrier eligibility and market rules remain effective',
  'Routes depending on lost market privileges stop',
  'Restore carrier eligibility or request separate market authority'),
 define('THIRD_FOURTH_FREEDOM','market','Ordinary international service rights','No separate fee if market access is already verified','Immediate, otherwise approval dependent',
  'No extra aircraft just to obtain a market right',
  ['Valid operator approval for passenger/cargo service','Home country, foreign destination country and operating airline specified','Bilateral or equivalent market access actually verified for the company'],
  ['Satisfy any allocation or designation requirement in the specific market'],
  ['Respect route, frequency, airport and weekly-capacity limits at activation'],
  'Operate authorised home-to-foreign and foreign-to-home commercial services',
  'Does not cover third-country-to-third-country or foreign domestic flights',
  'While the verified traffic right and operator approvals remain valid',
  'Affected country-pair schedules stop when rights are suspended or expire',
  'Revalidate market rights; renew allocation or obtain fresh approval'),
 define('FIFTH_FREEDOM','market','Fifth freedom rights','$100,000–$250,000 (if available)','7 game days',
  'No aircraft purchase required just for application',
  ['Valid airline operator licence and normal international traffic rights','Specify home-connected multi-country service and the desired foreign segment','Evidence that the states allow the specific fifth-freedom service','Eligible airline and available market allocation'],
  ['Pay proposed permit fee and receive explicit airline/market permission'],
  ['Fly only approved sequence, service type, airports and weekly capacity'],
  'Carry paid traffic on a permitted foreign-to-foreign segment linked to home-country service',
  'No general seventh-freedom or foreign domestic cabotage right',
  'Normally 1 game year unless the specific market states otherwise',
  'The affected fifth-freedom segment cannot be sold or activated',
  'Renew the route/market allocation or remove the restricted segment'),
 define('SEVENTH_FREEDOM','market','Seventh freedom rights','$200,000 (only where permitted)','10 game days',
  'No extra aircraft to apply; assigned fleet must meet flight rules',
  ['Valid operator approval for the proposed service','Specify both foreign markets and airline nationality','Specific agreement allowing this carrier to fly between those foreign markets'],
  ['Receive explicitly approved service and country-pair scope','Meet any capital, aircraft or market capacity allocation required by that agreement'],
  ['Operate only the authorised foreign-to-foreign services and frequencies'],
  'Offer authorised foreign-to-foreign flights not linked to the airline home state',
  'Not a foreign domestic cabotage permit',
  'Normally 1 game year where granted',
  'Affected foreign-to-foreign commercial schedules stop',
  'Reapply when legally permitted, or end the service'),
 define('CABOTAGE','market','Foreign domestic / cabotage rights','$250,000 (if legally available)','10 game days',
  'No additional aircraft required for market-right application',
  ['Valid airline approval','Specify the foreign country and proposed domestic city pairs','A verified special or integrated-market right permitting this carrier to carry local domestic traffic'],
  ['Receive explicit airline, country, service and frequency authority','Pay fee only if that market actually offers such a permission'],
  ['Use only the authorised domestic foreign market and any approved frequencies'],
  'Transport paying passengers/cargo within an eligible foreign country',
  'Unavailable markets remain blocked regardless of cash; payment cannot create rights',
  'Defined by market grant, normally 1 game year in this proposal',
  'Affected foreign domestic departures blocked',
  'Revalidate the market or cease cabotage services'),
 define('FOREIGN_BASE_PERMIT','airport','Foreign operating base permission','$50,000','5 game days',
  'No extra aircraft required for base approval',
  ['Airline has valid operating approval','Select foreign airport and country','Market rules allow that airline to establish a base','Sufficient company funds for the base setup'],
  ['Airport premises/handling agreement','Station manager and relevant support staffing','Applicable local permits and base access approved'],
  ['Aircraft stationing, traffic rights, slots and facility capacity separately checked'],
  'Open and manage the authorised operating base',
  'A foreign base does not create fifth/seventh freedom or domestic foreign market rights',
  'Ongoing, subject to airport contract and local compliance review',
  'Foreign base operations stop; other approved bases remain unchanged',
  'Renew airport contract, local authorisation or restore required staff'),
 define('PART145_MAINTENANCE','special','EU Part-145 MRO approval','$200,000','10 game days',
  'No aircraft purchase needed to certify an MRO',
  ['Registered MRO operating company','Maintenance facility in an eligible jurisdiction','Qualified maintenance manager appointed','Sufficient funds for fees and operation'],
  ['At least 1 approved workshop/hangar suitable for proposed maintenance','Required trained and authorised mechanics/certifying staff','Tools, manuals, safety/quality procedures and aircraft/task scope defined'],
  ['Each maintenance job checked against approved tasks, aircraft types, people and hangar capacity'],
  'Perform and sell approved maintenance services',
  'Does not allow repairs beyond licensed aircraft types or task ratings',
  'Ongoing, subject to annual game compliance review',
  'Regulated MRO services stop; airline flight authorisations are separate',
  'Restore certified staff, facilities and scope; pass reinspection'),
 define('NON_EU_MAINTENANCE','special','National maintenance approval (non-EU)','$200,000 proposed baseline','10 game days',
  'No aircraft purchase needed to certify an MRO',
  ['Registered MRO subsidiary in selected non-EU country','Valid local facility, staff and management plan','National regulator rules identified for the business'],
  ['Approved facility, qualified mechanics, tools and safety system','Specific national authority approval with defined aircraft/task scope'],
  ['Maintenance service only within authorised scope and country rules'],
  'Offer maintenance in the country of the verified national approval',
  'EU Part-145 is not automatically transferable or valid worldwide',
  'Ongoing; country-specific renewal may shorten it',
  'Maintenance services needing this approval stop',
  'Complete the required national inspection or reapplication'),
 define('AIRPORT_SLOTS','airport','Airport take-off and landing slot allocation','Airport-specific allocation price','Seasonal / airport-specific',
  'No purchase required merely to request a slot',
  ['Valid airline and planned route','Airport is slot-controlled for the requested times','Proposed departure or arrival time and operating days'],
  ['Slot capacity allocation approved for specific date/time and airport'],
  ['Schedules must match the allocation; aircraft, runway and curfew checks remain'],
  'Use the allocated departure/arrival window',
  'Slots are not permanent airline licences and do not guarantee market access',
  'Airport season or specific allocation period',
  'Affected flights must be rescheduled or cancelled',
  'Request new slots; do not automatically restore old times',
  'Proposed future game layer; airport slot research/allocator must be built.'),
 define('FLIGHT_ACADEMY','special','Flight academy / training approval','$40,000 (future standalone academy)','7 game days',
  'Training aircraft needed for approved flight programmes, not for academy infrastructure planning',
  ['Existing airline training department, or separately registered trading academy','Choose training programmes and appropriate jurisdiction','Qualified chief instructor'],
  ['Required instructor qualifications and training manuals','At least 1 suitable training aircraft for a flight-training programme','Training facilities and approved programme'],
  ['Training sessions use qualified instructors, available aircraft and approved syllabi'],
  'Provide the authorised training programme; external sales only for a licensed subsidiary',
  'No airline AOC or commercial route rights are granted',
  'Ongoing with annual game compliance review',
  'Affected training courses stop; other airline services remain unaffected',
  'Restore instructors, training fleet and procedures; pass reinspection',
  'The initial academy belongs under airline infrastructure; a separate subsidiary is optional later.')
]);
const GROUPS=Object.freeze([
 ['all','All permissions'],['company','Company'],['airline','Airline'],['market','Markets'],['airport','Airports & bases'],['special','Special operations']
]);
function element(doc,tag,cls,text){
 const node=doc.createElement(tag);
 if(cls)node.className=cls;
 if(text!==undefined)node.textContent=String(text);
 return node;
}
function paragraph(doc,parent,cls,label,value){
 const block=element(doc,'div',cls);
 block.append(element(doc,'strong','',label),element(doc,'p','',value));
 parent.append(block);
 return block;
}
export function createLicensingPlanner({doc,root,getAirline=()=>null}={}){
 if(!doc?.createElement||!root?.replaceChildren)throw Error('Licence planner requires a document and host');
 let group='all',query='',selected='AIR_OPERATOR_CERTIFICATE',scenario='original';
 let licenceSelect,categorySelect,scenarioSelect,search,details,afterApproval,company;
 const listFor=()=>LICENCE_PLAN.filter(item=>(group==='all'||item.group===group)&&
   (item.title+' '+item.code+' '+item.application.join(' ')+' '+item.approval.join(' ')).toLowerCase().includes(query));
 const feeFor=item=>item.code==='AIR_OPERATOR_CERTIFICATE'
  ?(scenario==='original'?'Included in original airline activation':'$150,000 for new airline subsidiary')
  :item.cost;
 const field=(name,control)=>{
  const label=element(doc,'label','lp-field workspace-label');
  label.append(element(doc,'span','',name),control);
  return label;
 };
 const buildSelect=(name,items)=>{
  const control=element(doc,'select','lp-select');
  control.setAttribute('aria-label',name);
  for(const [value,title] of items){
   const option=element(doc,'option','',title);
   option.value=value;
   control.append(option);
  }
  return control;
 };
 const checklist=(title,items)=>{
  const panel=element(doc,'div','lp-step');
  panel.append(element(doc,'h3','',title));
  const list=element(doc,'ul','lp-criteria');
  for(const item of items){
   const line=element(doc,'li','');
   line.append(element(doc,'span','lp-criterion-icon','○'),element(doc,'span','',item));
   list.append(line);
  }
  panel.append(list);
  return panel;
 };
 const renderOptions=()=>{
  const available=listFor();
  if(!available.some(item=>item.code===selected))selected=available[0]?.code||'';
  licenceSelect.replaceChildren();
  if(!available.length){
   const option=element(doc,'option','','No matching permissions');
   option.value='';
   licenceSelect.append(option);
   licenceSelect.disabled=true;
  }else{
   licenceSelect.disabled=false;
   for(const item of available){
    const option=element(doc,'option','',item.title);
    option.value=item.code;
    licenceSelect.append(option);
   }
   licenceSelect.value=selected;
  }
  renderDetails();
 };
 const renderDetails=()=>{
  details.replaceChildren();
  afterApproval.replaceChildren();
  const item=LICENCE_PLAN.find(x=>x.code===selected);
  if(!item){
   details.append(element(doc,'p','hint','No permission matches these filters. Try another category or search.'));
   afterApproval.hidden=true;
   return;
  }
  afterApproval.hidden=false;
  details.append(element(doc,'h3','lp-selected-name',item.title),
   element(doc,'p','hint lp-aircraft',item.aircraft));
  const metrics=element(doc,'div','workspace-kpis lp-metrics');
  for(const [label,value] of [['Proposed fee',feeFor(item)],['Review time',item.processing],['Validity / renewal',item.validity]]){
   const cell=element(doc,'div','');
   cell.append(element(doc,'span','',label),element(doc,'strong','',value));
   metrics.append(cell);
  }
  details.append(metrics);
  const stages=element(doc,'div','workspace-task-list lp-steps');
  stages.append(checklist('1 · To apply',item.application),
    checklist('2 · For final approval',item.approval),
    checklist('3 · Before operating',item.operation));
  details.append(stages);
  if(item.notes)details.append(element(doc,'p','hint lp-footnote',item.notes));
  const action=element(doc,'div','workspace-actions lp-actions');
  const blocked=element(doc,'button','secondary','Applications not yet available');
  blocked.type='button';blocked.disabled=true;
  action.append(blocked,element(doc,'span','hint',
    'Design only. No licence is granted, no application is submitted and no money is charged.'));
  details.append(action);
  const textGrid=element(doc,'div','workspace-task-list lp-effects');
  for(const [label,value] of [['What it unlocks',item.unlocks],
    ['What stays restricted',item.limits],
    ['If suspended, expired or lost',item.loss],
    ['How to restore',item.recovery]]){
   const line=element(doc,'div','');
   line.append(element(doc,'strong','',label),element(doc,'span','',value));
   textGrid.append(line);
  }
  afterApproval.append(textGrid);
 };
 const show=()=>{
  if(!licenceSelect){
   const application=element(doc,'article','panel workspace-panel lp-panel');
   application.append(element(doc,'span','panel-kicker','LICENSING PLANNING'),
     element(doc,'h2','','Licence application requirements'),
     element(doc,'p','hint','Choose a licence to check exactly what is needed to apply, receive approval and begin operating. Fees and timelines below are proposals, not active game charges.'));
   company=element(doc,'p','hint lp-company','');
   application.append(company);
   const controls=element(doc,'div','workspace-money-grid lp-controls');
   categorySelect=buildSelect('Permission category',GROUPS);
   categorySelect.value=group;
   categorySelect.addEventListener('change',()=>{
    group=GROUPS.some(([value])=>value===categorySelect.value)?categorySelect.value:'all';
    renderOptions();
   });
   licenceSelect=buildSelect('Licence or permit',[]);
   licenceSelect.addEventListener('change',()=>{
    if(LICENCE_PLAN.some(item=>item.code===licenceSelect.value))
     selected=licenceSelect.value;
    renderDetails();
   });
   scenarioSelect=buildSelect('Cost scenario',[
    ['original','Original airline'],['subsidiary','New subsidiary airline']
   ]);
   scenarioSelect.value=scenario;
   scenarioSelect.addEventListener('change',()=>{
    scenario=scenarioSelect.value==='subsidiary'?'subsidiary':'original';
    renderDetails();
   });
   search=element(doc,'input','lp-search');
   search.type='search';search.placeholder='Search licence names or requirements';
   search.setAttribute('aria-label','Search licences and requirements');
   search.addEventListener('input',()=>{query=search.value.trim().toLowerCase();renderOptions();});
   controls.append(field('Permission category',categorySelect),field('Licence or permit',licenceSelect),
    field('Cost scenario',scenarioSelect),field('Search permissions',search));
   application.append(controls);
   details=element(doc,'div','lp-details');
   application.append(details);
   const after=element(doc,'article','panel workspace-panel lp-panel');
   after.append(element(doc,'span','panel-kicker','APPROVAL AND COMPLIANCE'),
    element(doc,'h2','','After approval'),
    element(doc,'p','hint','An approval unlocks only its defined activity. Other airline, market and airport rules still apply.'));
   afterApproval=element(doc,'div','lp-after');
   after.append(afterApproval);
   root.replaceChildren(application,after);
  }
  const airline=getAirline();
  company.textContent=airline?.name
   ?'Signed-in airline: '+airline.name+' · requirements not evaluated'
   :'No verified airline context available · planning example only';
  renderOptions();
 };
 return Object.freeze({show});
}
