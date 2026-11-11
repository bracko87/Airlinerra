/** Public, server-synchronized Airlinerra World 1 time.
 * One real second = one game second. The fixed world timezone is Europe/Berlin.
 * A monotonic counter is calibrated from PostgreSQL; never assume player
 * device time or timezone is authoritative for the game. */
export const WORLD_TIME_URL=
 'https://hwllkabgzaynalahvkpz.supabase.co/functions/v1/airlinerra-world-time';
const FORMAT=new Intl.DateTimeFormat('en-GB',{
 timeZone:'Europe/Berlin',day:'2-digit',month:'short',year:'numeric',
 hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23'
});
export function formatBerlinGameTime(epochMillis){
 if(!Number.isFinite(epochMillis))return null;
 const data={};
 for(const part of FORMAT.formatToParts(new Date(epochMillis)))
  if(part.type!=='literal')data[part.type]=part.value;
 return data.day+' '+data.month+' '+data.year+' · '+
  data.hour+':'+data.minute+':'+data.second+' Berlin';
}
export function verifyWorldTimeResponse(value){
 if(!value||typeof value!=='object'||value.worldId!==1||
  value.timeZone!=='Europe/Berlin'||value.speed!=='1:1'||
  value.readOnly!==true||
  typeof value.utcNow!=='string'||
  !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value.utcNow))
  return null;
 const instant=Date.parse(value.utcNow);
 return Number.isFinite(instant)?instant:null;
}
export function startBerlinGameClock({
 element,fetchImpl=globalThis.fetch,
 nowMonotonic=()=>globalThis.performance.now(),
 setEvery=globalThis.setInterval,
 clearEvery=globalThis.clearInterval,
 doc=globalThis.document
}={}){
 if(!element||typeof fetchImpl!=='function')throw Error('Game clock requires server and label');
 let anchorInstant=null,anchorMono=0,stopped=false,busy=false;
 const label=text=>{element.textContent=text;};
 const render=()=>{
  if(anchorInstant===null||stopped)return;
  const epoch=anchorInstant+Math.max(0,nowMonotonic()-anchorMono);
  const formatted=formatBerlinGameTime(epoch);
  if(formatted)label(formatted);
 };
 const sync=async()=>{
  if(busy||stopped)return false;
  busy=true;
  try{
   const response=await fetchImpl(WORLD_TIME_URL,{
    method:'GET',headers:{Accept:'application/json'},
    cache:'no-store',credentials:'omit',redirect:'error',referrerPolicy:'no-referrer'
   });
   if(!response?.ok)throw Error('Game time endpoint unavailable');
   const result=await response.json();
   const trusted=verifyWorldTimeResponse(result);
   if(trusted===null)throw Error('Invalid server clock');
   if(stopped)return false;
   anchorInstant=trusted;anchorMono=nowMonotonic();
   render();
   return true;
  }catch{
   if(!stopped){anchorInstant=null;label('Game time unavailable');}
   return false;
  }finally{busy=false;}
 };
 label('Loading Berlin time…');
 const seconds=setEvery(render,1000);
 const refresh=setEvery(()=>{void sync();},60000);
 const onVisible=()=>{if(doc?.visibilityState==='visible')void sync();};
 doc?.addEventListener?.('visibilitychange',onVisible);
 void sync();
 return Object.freeze({
  sync,render,
  stop(){stopped=true;clearEvery(seconds);clearEvery(refresh);
   doc?.removeEventListener?.('visibilitychange',onVisible);}
 });
}
