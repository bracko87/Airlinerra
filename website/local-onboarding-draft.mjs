/** Local browser-tab draft only. Never a registered airline or legal agreement. */
import {isLocalDemoOrigin} from './local-demo-session.mjs';
const KEY='airlinerra-local-airline-draft-v1';
export function validDraft(d){
 return Boolean(d&&Number.isInteger(d.worldId)&&d.worldId>=1&&d.worldId<=3&&
 typeof d.countryIso==='string'&&/^[A-Z]{2}$/u.test(d.countryIso)&&
 typeof d.airportKey==='string'&&/^OURAIRPORTS:[1-9][0-9]{0,18}$/u.test(d.airportKey)&&
 typeof d.airlineName==='string'&&d.airlineName.length>=3&&d.airlineName.length<=60&&
 /^[\p{L}\p{N} .&'()\-]+$/u.test(d.airlineName));
}
export function saveLocalDraft(storage,location,input){
 if(!isLocalDemoOrigin(location))throw Error('Local draft only');
 const d={worldId:Number(input.worldId),countryIso:input.countryIso,
 airportKey:input.airportKey,airlineName:String(input.airlineName||'').trim()};
 if(!validDraft(d))throw Error('Complete valid demo setup first');
 storage.setItem(KEY,JSON.stringify({version:1,...d}));
 return Object.freeze({...d,previewOnly:true});
}
export function readLocalDraft(storage,location){
 if(!isLocalDemoOrigin(location))return null;
 try{const d=JSON.parse(storage.getItem(KEY)||'null');
 return d?.version===1&&validDraft(d)?Object.freeze({
 worldId:d.worldId,countryIso:d.countryIso,airportKey:d.airportKey,airlineName:d.airlineName,previewOnly:true
 }):null;}catch{return null}
}
export function clearLocalDraft(storage,location){
 if(!isLocalDemoOrigin(location))return false;
 storage.removeItem(KEY);return true;
}
