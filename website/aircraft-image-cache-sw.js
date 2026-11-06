/* Airlinerra aircraft artwork: bounded, persistent cache of PUBLIC images only.
 * This worker controls /player.html and deliberately never caches user accounts,
 * Supabase Auth, API responses, flight data, or protected pages.
 * Bump CACHE_NAME if existing public image filenames are overwritten in Storage.
 */
const CACHE_NAME='airlinerra-public-aircraft-images-v1';
const CACHE_PREFIX='airlinerra-public-aircraft-images-';
const MAX_IMAGES=60;
const STORAGE_HOST='hwllkabgzaynalahvkpz.supabase.co';
const AIRCRAFT_PREFIX='/storage/v1/object/public/Admin/Airplanes/';

function isPublicAircraftImage(request){
 if(request.method!=='GET'||request.destination!=='image')return false;
 const url=new URL(request.url);
 return url.protocol==='https:'&&url.hostname===STORAGE_HOST&&
  url.pathname.startsWith(AIRCRAFT_PREFIX);
}
async function trimCache(cache){
 const entries=await cache.keys();
 for(const request of entries.slice(0,Math.max(0,entries.length-MAX_IMAGES)))
  await cache.delete(request);
}
self.addEventListener('install',event=>{event.waitUntil(self.skipWaiting())});
self.addEventListener('activate',event=>{
 event.waitUntil((async()=>{
  const names=await caches.keys();
  await Promise.all(names.filter(name=>name.startsWith(CACHE_PREFIX)&&name!==CACHE_NAME)
   .map(name=>caches.delete(name)));
  await self.clients.claim();
 })());
});
self.addEventListener('fetch',event=>{
 const request=event.request;
 if(!isPublicAircraftImage(request))return;
 event.respondWith((async()=>{
  let cache=null;
  try{
   cache=await caches.open(CACHE_NAME);
   const hit=await cache.match(request);
   if(hit)return hit;
  }catch{/* Disabled/evicted browser storage must not break image loading. */}
  let response;
  try{response=await fetch(request)}catch{return Response.error()}
  if(cache&&(response.ok||response.type==='opaque')){
   const saving=cache.put(request,response.clone())
    .then(()=>trimCache(cache)).catch(()=>{});
   event.waitUntil(saving);
  }
  return response;
 })());
});
