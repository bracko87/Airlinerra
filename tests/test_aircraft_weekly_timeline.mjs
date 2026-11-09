import test from 'node:test';
import assert from 'node:assert/strict';
import {buildAircraftWeeklyTimeline,WEEKDAYS} from '../website/aircraft-weekly-timeline.mjs';
const belgrade={key:'OURAIRPORTS:4610',name:'Belgrade Nikola Tesla Airport',municipality:'Belgrade'};
const tivat={key:'OURAIRPORTS:TT',name:'Tivat Airport',municipality:'Tivat'};
const podgorica={key:'OURAIRPORTS:PG',name:'Podgorica Airport',municipality:'Podgorica'};
const aircraftId='test-aircraft-a319';
const route=(flightNumber,from,to,day,time,arrivalStand='terminal',id=aircraftId)=>({
 flightNumber,from,to,aircraftId:id,
 schedule:[{day,time}],operation:{arrivalStand}
});
const check=(rows,proposal=null)=>buildAircraftWeeklyTimeline({
 aircraftId,routes:rows,proposal,homeAirportKey:belgrade.key
});
test('conflicting Belgrade to Podgorica at 11:00 after Belgrade to Tivat at 09:00 is rejected',()=>{
 const prior=route('PA101',belgrade,tivat,0,'09:00','remote');
 const next=route('PA202',belgrade,podgorica,0,'11:00');
 const result=check([prior],next);
 assert.deepEqual(result.events.map(x=>x.flightNumber),['PA101','PA202']);
 assert.equal(result.errors[0].code,'AIRCRAFT_WRONG_AIRPORT');
 assert.match(result.errors[0].text,/in Tivat after PA101 Monday 09:00/);
 assert.match(result.errors[0].text,/cannot depart from Belgrade on PA202 Monday 11:00/);
});
test('a return from Tivat uses previous arrival remote stand; following flight in Belgrade uses terminal',()=>{
 const a=route('PA101',belgrade,tivat,0,'09:00','remote');
 const b=route('PA102',tivat,belgrade,0,'14:00','terminal');
 const c=route('PA103',belgrade,podgorica,1,'09:00','remote');
 const result=check([a,b],c);
 assert.equal(result.errors.length,0);
 assert.equal(result.events[0].departureStand,null);
 assert.equal(result.events[1].departureStand,'remote');
 assert.equal(result.events[2].departureStand,'terminal');
 assert.equal(result.dayPositions[0].airport,'Belgrade');
 assert.equal(result.dayPositions[1].airport,'Podgorica');
 assert.equal(result.events[0].timingVerified,false);
 assert.ok(result.warnings.some(x=>/flight duration/.test(x)));
});
test('same time duplicate assignment is forbidden, even from same origin',()=>{
 const x=route('PA101',belgrade,tivat,0,'09:00');
 const y=route('PA102',belgrade,tivat,0,'09:00');
 const result=check([x],y);
 assert.ok(result.errors.some(issue=>issue.code==='SAME_TIME'));
});
test('locations are checked across weekdays and multiple aircraft stay independent',()=>{
 const x=route('PA101',belgrade,tivat,0,'09:00');
 const y=route('PA102',belgrade,podgorica,1,'10:00');
 assert.ok(check([x],y).errors.some(e=>e.code==='AIRCRAFT_WRONG_AIRPORT'));
 const independent=route('PA201',belgrade,podgorica,1,'10:00','terminal','different-a319');
 assert.equal(check([x],independent).errors.length,0);
});
test('first flight draft does not show a wrong-airport or return-loop warning',()=>{
 const repeated={...route('PA101',belgrade,tivat,0,'09:00'),schedule:[0,1,2,3,4,5,6].map(day=>({day,time:'09:00'}))};
 const result=check([],repeated);
 assert.equal(result.errors.length,0);
 assert.ok(!result.warnings.some(w=>/Weekly cycle is incomplete/.test(w)));
 assert.equal(result.events[0].departureStand,null);
});
test('an edited flight can replace its previous draft without being compared to itself',()=>{
 const old=route('PA101',belgrade,tivat,0,'09:00');
 const revised=route('PA101',belgrade,podgorica,0,'09:30');
 const result=buildAircraftWeeklyTimeline({
  aircraftId,routes:[old],proposal:revised,excludeFlightNumber:'PA101'
 });
 assert.equal(result.errors.length,0);
 assert.equal(result.events.length,1);
 assert.equal(result.events[0].to,'Podgorica');
});
test('legacy drafts with missing aircraft assignment or arrival stand do not invent position',()=>{
 const legacy=route('PA101',belgrade,tivat,0,'09:00');
 delete legacy.operation.arrivalStand;
 const next=route('PA102',tivat,belgrade,0,'15:00');
 const result=check([legacy],next);
 assert.equal(result.errors.length,0);
 assert.equal(result.events[1].departureStand,null);
 assert.equal(check([{...legacy,aircraftId:null}]).events.length,0);
 assert.equal(buildAircraftWeeklyTimeline({routes:[legacy]}).aircraftId,null);
 assert.equal(WEEKDAYS.length,7);
});

test('fictional Aleksandrovo LYAL is shown by airport identity rather than Nova Crnja municipality',()=>{
 const aleks={key:'OURAIRPORTS:LYAL',code:'LYAL',name:'Aleksandrovo Airport',municipality:'Nova Crnja'};
 const plan=check([route('PA444',belgrade,aleks,0,'09:00')]);
 assert.equal(plan.events[0].to,'Aleksandrovo');
 assert.equal(plan.errors.length,0);
});
