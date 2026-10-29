/** Shared, owner-authenticated World 1 airport selector.
 * Reads ONLY approved airport pages via the existing verified player API.
 * Never mixes locations across countries; never runs a server-side write.
 */
export const airportFlag=code=>/^[A-Z]{2}$/.test(code||'')?
 String.fromCodePoint(...[...code].map(c=>c.charCodeAt(0)+127397)):'';
export const airportCountryName=code=>{
 if(!/^[A-Z]{2}$/.test(code||''))return 'Unknown country';
 try{return new Intl.DisplayNames(['en'],{type:'region'}).of(code)||code}
 catch{return code}
};
export function populateAirportCountries(select,countries,doc=globalThis.document){
 if(!select)return;
 const previous=select.value;
 select.replaceChildren(new Option('Choose country',''));
 for(const c of [...(countries||[])].filter(x=>/^[A-Z]{2}$/.test(x?.countryIso||''))
  .sort((a,b)=>airportCountryName(a.countryIso).localeCompare(airportCountryName(b.countryIso),'en'))){
  const count=Number(c.airportCount)||0;
  select.add(new Option(airportFlag(c.countryIso)+' '+airportCountryName(c.countryIso)+
   ' ('+count+' '+(count===1?'airport':'airports')+')',c.countryIso));
 }
 if([...select.options].some(o=>o.value===previous))select.value=previous;
}
export function validAirportLocation(a){
 return !!(a&&typeof a.key==='string'&&/^(OURAIRPORTS:[1-9]\d{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/.test(a.key)&&
  typeof a.name==='string'&&a.name.trim()&&/^[A-Z]{2}$/.test(a.countryIso||''));
}
export function createAirportCountryPicker({country,search,airport,getReader,onStatus=()=>{},onSelect=()=>{}}={}){
 if(!country||!search||!airport||typeof getReader!=='function')throw Error('Country airport inputs are required');
 let generation=0,loading=false,entries=[],known=new Map(),selected='';
 const reset=label=>{
  airport.replaceChildren(new Option(label,''));airport.disabled=true;selected='';
  onSelect(null);
 };
 const current=()=>known.get(airport.value)||null;
 const filter=()=>{
  const words=search.value.toLocaleLowerCase('en').trim();
  const filtered=words?entries.filter(a=>
   [a.name,a.code,a.municipality].some(s=>String(s||'').toLocaleLowerCase('en').includes(words))):entries;
  airport.replaceChildren(new Option(loading?'Loading airports...':'Select approved airport',''));
  for(const a of filtered){
   const label=a.name+' ('+(a.code||'Code pending')+')'+(a.municipality?' - '+a.municipality:'');
   const option=new Option(label,a.key);
   option.dataset.airportName=a.name;option.dataset.code=a.code||'';
   airport.add(option);
  }
  airport.disabled=loading||filtered.length===0;
  if(selected&&filtered.some(a=>a.key===selected))airport.value=selected;
  else{selected='';airport.value='';}
  onSelect(current());
  if(!loading)onStatus(filtered.length+' of '+entries.length+' approved airports shown'+
    (words?' - filtered by search.':'.'));
 };
 const load=async()=>{
  const ticket=++generation,iso=country.value,reader=getReader();
  entries=[];known=new Map();selected='';loading=false;
  reset('Choose country first');
  if(!/^[A-Z]{2}$/.test(iso))return;
  if(!reader?.airports){reset('Approved airport directory unavailable');onStatus('Airport directory unavailable.');return;}
  loading=true;reset('Loading approved airports...');
  onStatus('Loading all approved airports in '+airportCountryName(iso)+'...');
  try{
   const all=[],seen=new Set();let offset=0;
   for(let pageIndex=0;pageIndex<65;pageIndex++){
    const page=await reader.airports({countryIso:iso,search:'',offset});
    if(ticket!==generation)return;
    if(page.countryIso!==iso||!Array.isArray(page.airports))throw Error('Unexpected country catalog');
    for(const a of page.airports){
     if(!validAirportLocation(a)||a.countryIso!==iso||seen.has(a.key))continue;
     seen.add(a.key);all.push(a);
    }
    if(page.nextOffset===null||page.nextOffset===undefined)break;
    if(!Number.isSafeInteger(page.nextOffset)||page.nextOffset<=offset||page.nextOffset>3100)
     throw Error('Invalid catalog pagination');
    offset=page.nextOffset;
    if(pageIndex===64)throw Error('Airport page cap reached');
   }
   if(ticket!==generation)return;
   entries=all.sort((a,b)=>a.name.localeCompare(b.name,'en'));
   known=new Map(entries.map(a=>[a.key,a]));
   loading=false;filter();
  }catch{
   if(ticket!==generation)return;
   entries=[];known=new Map();loading=false;
   reset('Airport directory unavailable');
   onStatus('Airport directory could not be loaded. Retry the country selection.');
  }
 };
 const onCountry=()=>{search.value='';void load()};
 const onSearch=()=>{if(!loading)filter()};
 const onAirport=()=>{selected=airport.value;onSelect(current())};
 country.addEventListener('change',onCountry);
 search.addEventListener('input',onSearch);
 airport.addEventListener('change',onAirport);
 reset('Choose country first');
 return Object.freeze({load,refresh:load,selected:current,
  invalidate:()=>{generation++;loading=false;entries=[];known=new Map();reset('Choose country first');},
  getAirports:()=>entries.slice()});
}
