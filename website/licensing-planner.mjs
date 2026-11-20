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
 define('AIR_OPERATOR_CERTIFICATE','airline','Air Operator Certificate (AOC)',
  'Original airline: free · New separately incorporated subsidiary: $10,000',
  'Original airline: immediate · Subsidiary: 3 game days',
  'AOC issue itself requires no additional aircraft purchase; every operating flight still requires a suitable service-ready aircraft',
  ['Original airline: issued immediately when registered; no AOC application',
   'Subsidiary: register a distinct operating company under an eligible holding',
   'Subsidiary: submit one owner-verified game application; no fee at submission'],
  ['Original airline: automatically issued for $0',
   'Subsidiary: after 3 verified game days, confirm registration, airline ownership and available $10,000',
   'Subsidiary: debit $10,000 exactly once only upon successful approval; failed applications are not charged',
   'No additional aircraft, hired crew or speculative financial reserve required solely to issue the game AOC in this phase'],
  ['Before commercial departure: independently verify a ready aircraft, maintenance, route permissions, airport/slot restrictions and operational flight clearance',
   'Crew is excluded from these checks until the later crew feature is introduced'],
  'Authorises the airline to operate commercial flights in its separately approved scope',
  'Does not itself grant international traffic rights, landing slots, independent aircraft clearance or another company’s AOC',
  'Valid 365 game days; reminder 90 game days before expiry; automatic annual renewal at Safety Rating 70/100 or higher; renewal free',
  'Below 70 on renewal day: AOC expires and commercial departures pause; aircraft and route records remain',
  'Complete verified corrective actions to restore rating to at least 70; game automatically reinstates AOC for 365 game days at $0',
  'Safety Rating starts at 100/100 as an initial game baseline, deducting only verified safety incidents. No flights, ordinary maintenance, passenger image and crew currently cause no penalty. No incident engine is active yet; this is a reviewed specification, not a live grant. AOC and Safety Rating belong only to each individual passenger, cargo or commercial charter/VIP airline, not its holding. Academies and maintenance/MRO companies have separate approvals, not an airline AOC. Sister companies keep independent ratings and permissions. Even with expired AOC, an airline can repair, complete safety inspections and close verified corrective actions without operating flights. All corrective repairs, required inspections and safety audits have approved nonzero game costs paid by that airline; merely paying without completed work restores no points. Safety Rating is 100 when no verified incidents remain unresolved. It is calculated from outstanding incidents, not a permanent penalty for corrected history. An unavailable safety service cannot trap the airline without a non-flight recovery path.'),
 define('EU_AIRLINE_OPERATING_LICENCE','airline','EU airline operating licence — real-world reference','Not an Airlinerra Licence 2 foreign network application','Regulatory reference only; not a live game permission',
  'An EU home-airline operating licence is NOT an extra right sold to foreign airlines',
  ['Company registered in an eligible EU/EEA jurisdiction','Applicable AOC and valid operator registration','Applicable home-country economic, ownership and financial requirements'],
  ['Real EU economic operating licence is granted by the relevant national authority, not as foreign-airline network rights'],
  ['Separate safety, service scope, international traffic and airport operations rules still apply'],
  'Reference for EU/EEA airline economic authorisation in its own home market',
  'Does not grant a non-EU airline domestic EU cabotage or the fictional Airlinerra L2 foreign network routes',
  'Legal validity depends on real regulatory rules; this is a reference-only catalogue entry',
  'Loss of underlying home-airline regulatory eligibility may restrict an airline in real life',
  'Restore real regulatory eligibility; Airlinerra game Licence 2 uses a distinct concept',
  'DO NOT USE this legacy EU reference code as L2-EU. See the separate proposed FOREIGN_NETWORK_LICENCE_2 for the player-requested game-only permission.'),
 define('FOREIGN_NETWORK_LICENCE_2','market','Licence 2 — Foreign network expansion (planned)','First approval fee proposed: $25,000; regional and upgrade fees NOT settled','First company application after 90 game days; review duration not final',
  'One ready-to-fly delivered aircraft for first application; fleet quantity does NOT define licence level',
  ['Registered airline company at least 90 game days old; own valid AOC (Licence 1)',
   'At least one aircraft ready to fly, a home airport and enough independently verified reserves for 90 game days',
   'Safety Rating at least 80/100 and no unresolved critical maintenance defects',
   'Apply separately for a network in EU/EEA, US, UK or Japan; no foreign country-by-country application for normal home-return flights'],
  ['Foreign network rights belong to the applying airline in the specific market, never the holding',
   'EU licence levels tentatively 1 through 4; exact US, UK and Japan level numbers remain open',
   'Application approval fees and final level thresholds must be agreed and enforced server-side before issuance'],
  ['Licence 1 game rights: home country -> foreign destination -> home country, without buying Licence 2',
   'Licence 2: directed foreign network routes such as Zagreb -> Ljubljana, separate from Ljubljana -> Zagreb',
   'Licence 2: approved foreign hub -> outside destination -> same hub, e.g. Zagreb -> Hurghada and Hurghada -> Zagreb use two directed slots',
   'Fifth Freedom foreign-to-foreign sales on a home-connected service are handled inside Licence 2 market and route checks; there is no separate Licence 6 or additional Fifth Freedom licence fee',
   'EU proposed directed-route ceilings: Level 1 = 20, Level 2 = 50, Level 3 = 150, Level 4 = unlimited'],
  'Expand an airline into a network away from its home market: independently operate approved local/regional flights and outbound/return flights from a licensed foreign hub',
  'Foreign-to-foreign routes, including home-connected onward segments, are subject to Licence 2 market scope plus separately verified international traffic rights; Licence 2 is not a universal real-world grant. Airport slots, service-ready aircraft and route schedule remain independently checked',
  'No periodic renewal; player may request an optional upgrade annually, including a direct jump by multiple levels',
  'Financial, AOC, safety and critical maintenance problems may require correction, warnings or suspension; exact windows not finalized',
  'Verified corrective actions restore the qualifying rights without recreating airline accounts; exact downgrade rules under discussion',
  'NOT LIVE. Specific fictional commercial/network rights, not actual legal permissions. See docs/AIRLINERRA_LICENCE2_FOREIGN_NETWORK_2026-11-17.md. The previously stated automatic L2 award and worldwide airport-count quotas are wrong.'),
 define('CARGO_OPERATIONS_SCOPE','airline','Cargo operations approval','$50,000 game fee at approval','3 game days (verified game clock)',
  'Apply: no extra aircraft purchase required. Final approval: at least one in-service cargo or combi aircraft in this cargo company fleet; an existing suitable aircraft counts',
  ['A holding may register a separate cargo airline subsidiary without this licence, but the company cannot operate cargo flights before approval','The applicant must be a verified cargo airline subsidiary, not a holding or unrelated passenger airline','The cargo company must have its own active AOC (Licence 1)','Submitting an application is free'],
  ['At approval, verify at least one in-service cargo-capable aircraft owned or leased by this company','Confirm sufficient funds in the cargo company account for the $50,000 fee','Charge the fee once only in the same trusted transaction that issues the approval after 3 verified game days'],
  ['Cargo operating approval authorises ordinary cargo services worldwide for this company','At least 1 cargo-handling arrangement at the operating airport, plus separate market/route rights, cargo access, slots, aircraft, safety and operational gates, must be verified before each flight','Restricted dangerous goods require a separate licence'],
  'Allows the approved cargo airline to provide ordinary cargo services worldwide, subject to independent route and airport permissions',
  'Does not unlock every airport, foreign network, restricted goods or flight activation automatically',
  'Company-wide game approval; exact renewal conditions not yet released',
  'Without a valid cargo approval the cargo airline may exist but cannot perform commercial cargo operations',
  'Meet the eligibility requirements and complete the trusted approval process',
  'This entry describes staged Licence 3 rules. Cargo applications, automatic charging and actual issuance are NOT LIVE. Crew is outside the current licensing check; separate flight staffing rules may apply when implemented. Buying an additional cargo aircraft is not required when the company already has one that qualifies.'),
 define('CHARTER_VIP_SCOPE','airline','Charter / VIP operating scope','$40,000 game fee at approval','3 game days',
  'Apply: no additional aircraft purchase required. Final approval: at least one in-service passenger or combi aircraft in the charter/VIP company fleet',
  ['A holding may register a charter/VIP airline subsidiary before it receives this licence','Application is free; the applicant must be a verified, registered charter airline subsidiary with its own active AOC','One licence covers ordinary commercial charter and VIP passenger services for the approved operating company'],
  ['Check that the charter/VIP airline owns or leases at least one in-service passenger-capable aircraft','Check that the company has $40,000 and charge exactly once with approval after 3 verified game days','Never approve a planned-only subsidiary or a company using a different airline\'s AOC'],
  ['An approved licence enables the charter/VIP service scope only','Every actual flight must still pass its own market and route rights, airport access, aircraft readiness, crew and slot checks'],
  'Commercial charter and VIP passenger service for the approved company',
  'No automatic route, foreign-market, airport, aircraft or flight activation permission',
  'Company-specific approval; never inherited by the holding or sibling companies',
  'Affected charter/VIP services are blocked if AOC, operational aircraft, company registration or operating approval is invalid',
  'Meet the required company, AOC and aircraft conditions again and complete independent operational checks',
  'Licence 4 application and atomic game approval are staged and tested. Live issuance remains locked until company formation, AOC and full flight release are verified. No player fee is charged while unreleased.'),
 define('DANGEROUS_GOODS','airline','Licence 5 — Dangerous Goods Transport Approval','$60,000 game fee on approval','5 verified game days',
  'No extra aircraft purchase if the cargo company already operates one suitable in-service cargo or combi aircraft',
  ['A verified registered cargo airline subsidiary with its own active AOC','Active Cargo Operations Licence 3 and company safety rating at least 70/100','Free application; $60,000 must be available in the cargo airline account'],
  ['Recheck Licence 3, the AOC, safety rating, suitable aircraft and company funds after 5 verified game days','Charge $60,000 exactly once in the same transaction that grants the operator-level licence','Dangerous-goods training, handling and special commodity permissions remain independent operational requirements'],
  ['An operator-level Licence 5 is not a blanket permission to carry hazardous goods','Every commodity class, aircraft, crew, packaging, airport and route requires separate verified authorization before shipment','No dangerous-goods commodity classes or shipments are currently released in the game'],
  'Company-specific game-level dangerous-goods operating approval only; class-specific transport remains separately gated',
  'Does not authorize any dangerous-goods commodity class or activate flights, slots or foreign route rights',
  'Licence record persists while operating prerequisites remain valid; individual shipments can be suspended independently',
  'Dangerous-goods transport remains blocked if Licence 3, AOC, safety 70+, aircraft suitability or class authorization is missing',
  'Restore eligibility and complete separate commodity-class and flight-specific authorizations',
  'Licence 5 application, 5-game-day atomic approval and $60,000 fee are staged and tested. Live issuance and commodity-class shipping stay locked until complete cargo company, AOC and shipment systems are verified.'),
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
 define('MAINTENANCE_ORGANIZATION_LICENCE_6','special','Licence 6 — Maintenance Organization Approval (MRO)','$200,000 proposed approval fee; no application fee','10 verified game days after application',
  'MRO buildings, tools and personnel will be defined separately in the later infrastructure design; no aircraft purchase required to own the MRO subsidiary',
  ['Registered maintenance_mro subsidiary under an eligible holding; NO minimum MRO company age',
   'May apply immediately once registered and all future-defined operating-readiness requirements are met',
   'Proposed $200,000 one-time approval fee; all future infrastructure, personnel and financial-reserve requirements are still to be defined',
   'One Licence 6 belongs to the MRO company and covers internal group maintenance and qualified services for other players'],
  ['Free application, with verified company and capability readiness review after 10 game days',
   'Charge the $200,000 approval fee only if the same transaction issues the licence',
   'Specific facilities, maintenance check types, staff roles/headcounts, specialist equipment and operating reserve amounts will be defined later',
   'EU, US and non-EU national maintenance authority requirements are compliance checks within the same game licence, not new purchased licences'],
  ['Player can optionally publish the maintenance company in the public provider directory; publication is OFF by default',
   'The company chooses which approved maintenance services and aircraft types/locations it wants to advertise and sets a separate player-defined price per service',
   'The player can hide, unpublish or change future offers without losing Licence 6 or retroactively changing existing accepted jobs',
   'External booking and payments later require verified capability, facility availability, contractual quotes and approved maintenance completion'],
  'Maintain aircraft owned by the same holding or other players under one company licence; optionally offer services publicly at chosen prices',
  'Licence 6 does not automatically create buildings, personnel, aircraft-model approvals or a public marketplace; unsupported jobs stay blocked',
  'Indefinite while compliant with proposed periodic inspection; no automatic separate third-party-service licence',
  'Maintenance work stops where approved company capability, facility, staffing, technical or safety prerequisites are not met',
  'Restore actual operating readiness and pass reinspection; revoked company licences require a fresh application',
  'DESIGN ONLY; no Licence 6 issuance or marketplace exists yet. See docs/AIRLINERRA_LICENCE6_MRO_REQUIREMENTS_2026-11-20.md.'),
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
 define('FLIGHT_ACADEMY','special','Licence 7 — Flight Academy / Training Organization Approval','$40,000 confirmed on approval; application is free','7 verified game days, subject to final readiness',
  'The academy must purchase, receive and assign at least one suitable operational SMALL TRAINING AIRCRAFT before Licence 7 approval; no aircraft required merely to register the subsidiary',
  ['Registered flight_academy subsidiary under an eligible holding; NO minimum academy-company age',
   'At least ONE purchased and operational eligible small training aircraft must be assigned to the academy before approval; a simulator or borrowed airliner alone does not satisfy this minimum',
   'Later introduce a catalogue of 10–20 small training-aircraft models to choose from; precise models and costs to be determined',
   'Other infrastructure, simulators, course-specific pilot qualifications, instructors and funds must satisfy future-defined standards',
   'One company Licence 7 covers training of its holding personnel and external player-airline trainees; no extra public-training licence'],
  ['Free application; review after 7 verified game days (confirmed) and charge $40,000 once only upon approval',
   'Advanced or type-specific training may use academy simulators or a holding airline aircraft, such as an ATR 72, when correctly rated and exclusively reserved',
   'Temporary aircraft assignment for training stays on the airline fleet; explicit permanent transfers are separate and must move inventory/accounting records',
   'Commercial flights and aircraft maintenance cannot overlap training reservations on the SAME aircraft calendar; never override existing flight or maintenance reservations'],
  ['Public academy listing is optional and OFF by default; players publish chosen approved courses with a price per programme',
   'Future pilot qualifications will require relevant training or aircraft type rating; an ATR 72 pilot needs the defined ATR 72 qualification before operating it',
   'Pilot qualification validity, expiry, recurrent checks and renewal are distinct from the academy business licence',
   'An academy that loses its training aircraft, instructor or mandatory safety capability must suspend affected training until reverified'],
  'Provide own-group and third-party training under one company licence, using certified academy training aircraft, simulators and temporarily booked airline aircraft where suitable',
  'No flight-operating AOC or automatic pilot qualifications; a training reservation must never allow the same aircraft to operate a commercial flight at the same time',
  'Organisation licence continues while compliant, with inspection/revalidation every 365 verified game days and no automatic renewal fee',
  'Loss of essential aircraft, equipment, safety or instructors suspends training; serious fraud or repeated safety violations can trigger reviewed revocation. Existing individual pilot qualifications are not automatically erased',
  'Restore missing capabilities and pass reinspection; annual revalidation is not a new paid licence. Pilot qualifications are separately renewed after recurrent training; revoked academies must reapply',
  'DESIGN ONLY. Future infrastructure includes 10–20 purchasable small training-aircraft models, simulators, course-specific pilot ratings, conflict-free ATR 72/airliner training reservations and academy compliance. No academy issuance or booking systems are live. See docs/AIRLINERRA_LICENCE7_FLIGHT_ACADEMY_REQUIREMENTS_2026-11-20.md.')
,
 define('AIRCRAFT_LEASING','special','Licence 8 — Aircraft Leasing Company Approval','$100,000 once on approval; free application','7 verified game days',
  'A leasing subsidiary owns aircraft for future dry-lease contracts; minimum aircraft assets, reserve and actual title verification will be defined later',
  ['Registered aircraft_leasing subsidiary under an eligible holding with no minimum leasing-company age',
   'One company licence covers dry leasing to its own holding airlines and to other players',
   'Free application; ownership, registration, finances, leasing compliance and insurance must be verified before licence approval',
   'No additional commercial leasing licence; the future company must have independently auditable finances'],
  ['After 7 verified game days recheck genuine eligibility; charge exactly $100,000 only in the same transaction as issuance',
   'Proposed inspection every 365 verified game days; no automatic renewal fee',
   'Dry lease ownership stays with lessor, while exclusive operating use is granted to the lessee airline under contract',
   'The lease contract and aircraft operating use must enforce no double leasing or concurrent incompatible operations'],
  ['Publish Aircraft for Lease is OFF by default; owners can select aircraft and set monthly prices and conditions per offer',
   'A dry lease does not confer AOC, route access, aircraft serviceability or permission to fly without operator checks',
   'Wet lease / ACMI (aircraft plus crew/maintenance/insurance) remains with licensed operating airline permissions and is not authorized by Licence 8',
   'Confirmed contracts retain agreed terms despite future repricing or unpublishing'],
  'Operate a dry-aircraft leasing business for own-group and external airline customers under a single Licence 8',
  'No wet lease / ACMI, AOC, route rights or automatic flight scheduling permission, and no double lease of the same aircraft',
  'Continuing while compliant, with inspection every 365 game days and no automatic annual approval charge',
  'Suspend new leasing for material compliance failure; fraud, repeated violations or duplicate aircraft leasing can cause revocation after review. Existing contracts must be preserved and resolved',
  'Correct issues and pass reinspection; revocation requires new approval. Existing accepted lease obligations cannot disappear silently',
  'PHASE 1 FOUNDATION ONLY. Company formation, leasing marketplace, aircraft purchase/transfer, leases, billing and licence issuance remain disabled. See docs/AIRLINERRA_LICENCE8_AIRCRAFT_LEASING_REQUIREMENTS_2026-11-20.md.')

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
  ?(scenario==='original'?'$0 — automatically issued on registration':'$10,000 — charged once when approved')
  :item.cost;
 const reviewFor=item=>item.code==='AIR_OPERATOR_CERTIFICATE'
  ?(scenario==='original'?'Immediate on registration':'3 game days after application')
  :item.processing;
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
  for(const [label,value] of [[item.code==='AIR_OPERATOR_CERTIFICATE'?'Agreed game fee':'Proposed fee',feeFor(item)],['Approval time',reviewFor(item)],['Validity / renewal',item.validity]]){
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
