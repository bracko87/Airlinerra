/**
 * World 1 owner route/schedule readiness display, derived only from the
 * authenticated list response. Read-only. Never treats a registered timetable,
 * slots or an activated schedule as proof of passenger sales or flown movements.
 */
export function summarizeSection9FlightReadiness(result) {
 const unavailable=Object.freeze({
  verified:false,stage:'unavailable',
  text:'Airline flight readiness could not be verified. No booking or flight activation is implied.'
 });
 if(!result||typeof result!=='object'||result.activationAvailable!==false||
   !Array.isArray(result.fleet)||!Array.isArray(result.plans)||
   !Array.isArray(result.drafts)||result.fleet.length>100||
   result.plans.length>100||result.drafts.length>100)return unavailable;
 const fleet=result.fleet.filter(x=>x&&typeof x.id==='string'&&
  x.fleetStatus==='in_service').length;
 const planned=result.plans.filter(x=>x&&x.status==='planning'&&
  typeof x.planId==='string').length;
 const registered=result.drafts.filter(x=>x&&typeof x.id==='string'&&
  ['draft','active'].includes(x.status));
 const active=registered.filter(x=>x.status==='active').length;
 const slotDrafts=registered.filter(x=>x.status==='draft'&&
  x.slotsReserved===true).length;
 const prefix='Airline database: '+fleet+' in-service aircraft, '+
  planned+' planning routes, '+registered.length+' registered schedules. ';
 let stage='needs-aircraft',next=
  'Next: put an owned or leased aircraft into service before creating a route.';
 if(fleet>0){
  stage='needs-route';
  next='Next: create a route and save it to the airline database.';
 }
 if(planned>0){
  stage='needs-schedule';
  next='Next: in Create a route, enter explicit UTC departure and arrival times, then use Operational Schedule Checks to register the timetable and airport slots.';
 }
 if(registered.length>0){
  stage='needs-certification';
  next='Next: complete crew duties, game licences, traffic rights and independent operational certifications. A registered schedule is not a flown flight.';
 }
 if(active>0){
  stage='needs-execution-proof';
  next='Next: verify the trusted execution release and real departure/arrival evidence; an active timetable alone is not proof a flight operated.';
 }
 return Object.freeze({verified:true,stage,
  fleet,planned,registered:registered.length,slotDrafts,active,
  text:prefix+next+' Ticket sales remain disabled.'});
}
