/** Self-hosted route-map renderer using real airport coordinates and
 * Natural Earth public-domain outlines. No third-party scripts, map tiles,
 * made-up airport coordinates, block times, slots or demand.
 */
import {WORLD_OUTLINES} from './world-outlines.mjs';
const NS='http://www.w3.org/2000/svg';
const RAD=Math.PI/180;
export function airportCoordinates(a){
 const lat=Number(a?.latitude),lon=Number(a?.longitude);
 if(a?.latitude===null||a?.latitude===undefined||a?.longitude===null||a?.longitude===undefined||
  !Number.isFinite(lat)||!Number.isFinite(lon)||Math.abs(lat)>90||Math.abs(lon)>180)return null;
 return {lat,lon};
}
export function routeDistanceKm(from,to){
 const a=airportCoordinates(from),b=airportCoordinates(to);
 if(!a||!b)return null;
 const dLat=(b.lat-a.lat)*RAD,dLon=(b.lon-a.lon)*RAD;
 const x=Math.sin(dLat/2)**2+Math.cos(a.lat*RAD)*Math.cos(b.lat*RAD)*Math.sin(dLon/2)**2;
 return Math.round(6371.0088*2*Math.atan2(Math.sqrt(x),Math.sqrt(1-x)));
}
const merc=(lat)=>Math.log(Math.tan(Math.PI/4+Math.max(-85,Math.min(85,lat))*RAD/2))/RAD;
const normalize=(lon,mid)=>lon+360*Math.round((mid-lon)/360);
const clamp=(value,a,b)=>Math.max(a,Math.min(b,value));
function makeSvg(doc,tag,attributes={},text){
 const el=doc.createElementNS(NS,tag);
 for(const [k,v] of Object.entries(attributes))el.setAttribute(k,String(v));
 if(text!==undefined)el.textContent=String(text);
 return el;
}
export function renderRouteMap(container,from,to,{doc=globalThis.document}={}){
 if(!container)return null;
 container.replaceChildren();
 const first=airportCoordinates(from),last=airportCoordinates(to);
 if(!first||!last){
  const empty=doc.createElement('p');
  empty.className='route-map-empty';
  empty.textContent='Map route pending - verified coordinates are not available for both airports.';
  container.append(empty);return null;
 }
 const midLon=(first.lon+last.lon)/2;
 const ax=normalize(first.lon,midLon),bx=normalize(last.lon,ax);
 const mid=(ax+bx)/2;
 const y1=merc(first.lat),y2=merc(last.lat);
 let spanX=Math.max(Math.abs(bx-ax)*1.4,3.5),spanY=Math.max(Math.abs(y2-y1)*1.4,3.5);
 const aspect=760/350;
 if(spanX/spanY<aspect)spanX=spanY*aspect;
 else spanY=spanX/aspect;
 const minX=mid-spanX/2,maxX=mid+spanX/2;
 const yMid=(y1+y2)/2,minY=yMid-spanY/2,maxY=yMid+spanY/2;
 const xy=(lon,lat)=>[760*(normalize(lon,mid)-minX)/(maxX-minX),350*(maxY-merc(lat))/(maxY-minY)];
 const svg=makeSvg(doc,'svg',{
  viewBox:'0 0 760 350',role:'img',
  'aria-label':'Geographic planning map from '+from.name+' to '+to.name,
  preserveAspectRatio:'xMidYMid meet'
 });
 svg.append(makeSvg(doc,'rect',{width:760,height:350,fill:'#e5f0f8'}));
 const geography=makeSvg(doc,'g',{class:'route-map-land'});
 for(const ring of WORLD_OUTLINES){
  // Skip rings that lie entirely far beyond the active map, cheaply.
  const pts=ring.map(([lon,lat])=>xy(lon,lat));
  if(!pts.length)continue;
  const box={x1:Math.min(...pts.map(x=>x[0])),x2:Math.max(...pts.map(x=>x[0])),
   y1:Math.min(...pts.map(x=>x[1])),y2:Math.max(...pts.map(x=>x[1]))};
  if(box.x2< -60||box.x1>820||box.y2< -60||box.y1>410)continue;
  // World polygons crossing the antimeridian can wrap over the map;
  // avoid drawing a misleading continent-spanning diagonal seam.
  if(pts.some((p,i)=>i>0&&Math.abs(p[0]-pts[i-1][0])>380))continue;
  const d=pts.map(([x,y],i)=>(i?'L':'M')+x.toFixed(1)+' '+y.toFixed(1)).join(' ')+'Z';
  geography.append(makeSvg(doc,'path',{d,fill:'#f7fbff',stroke:'#bfd2e2','stroke-width':.8}));
 }
 svg.append(geography);
 const guide=makeSvg(doc,'g',{'stroke':'#cadeec','stroke-width':.6,'stroke-dasharray':'3 5'});
 const step=Math.max(1,Math.round(spanX/6));
 for(let lon=Math.ceil(minX/step)*step;lon<=maxX;lon+=step){
  const x=760*(lon-minX)/(maxX-minX);
  guide.append(makeSvg(doc,'line',{x1:x,y1:0,x2:x,y2:350}));
 }
 svg.append(guide);
 const start=xy(first.lon,first.lat),end=xy(last.lon,last.lat);
 const line=makeSvg(doc,'line',{x1:start[0],y1:start[1],x2:end[0],y2:end[1],
  stroke:'#ff6917','stroke-width':3.5,'stroke-linecap':'round'});
 svg.append(line);
 for(const [i,point,a] of [[0,start,from],[1,end,to]]){
  const x=clamp(point[0],16,744),y=clamp(point[1],16,334);
  svg.append(makeSvg(doc,'circle',{cx:x,cy:y,r:6,fill:'#ff6917',stroke:'#fff','stroke-width':2}));
  const code=(typeof a.code==='string'&&a.code.trim()?a.code:a.name).slice(0,22);
  const label=makeSvg(doc,'g',{});
  const tx=clamp(x+(i===0?11:-11),46,714),ty=clamp(y+(i===0?-14:24),24,326);
  const width=clamp(code.length*7+16,48,180);
  const left=clamp(tx-(i===0?0:width),4,760-width-4);
  label.append(makeSvg(doc,'rect',{x:left,y:ty-17,width,height:25,rx:5,fill:'#092b57'}));
  label.append(makeSvg(doc,'text',{x:left+8,y:ty,fill:'#fff','font-size':12,'font-weight':650},code));
  svg.append(label);
 }
 container.append(svg);
 return {distanceKm:routeDistanceKm(from,to),midLongitude:mid,
  centerLatitude:(first.lat+last.lat)/2};
}
