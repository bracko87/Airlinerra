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
export function createAirportCountryPicker({country,search,airport,getReader,onStatus=()=>{},onSelect=()=>{},onResults=()=>{}}={}){
 if(!country||!search||!airport||typeof getReader!=='function')throw Error('Country airport inputs are required');
 let generation=0,loading=false,entries=[],known=new Map(),selected='',searchTimer=null;
 const reset=label=>{
  airport.replaceChildren(new Option(label,''));airport.disabled=true;selected='';
  onSelect(null);
  onResults([],false);
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
  onResults(filtered.slice(0,30),!loading);
  if(!loading)onStatus(filtered.length+' of '+entries.length+' approved airports shown'+
    (words?' - filtered by search.':'.'));
 };
 const load=async()=>{
  const ticket=++generation,iso=country.value,reader=getReader();
  entries=[];known=new Map();selected='';loading=false;
  reset('Choose country or type an airport name');
  const global=iso===''&&search.value.trim().length>=2;
  if(!/^[A-Z]{2}$/.test(iso)&&!global){
   onStatus('Type at least 2 characters to search all approved airports, or choose a country.');
   return;
  }
  if(!reader?.airports){reset('Approved airport directory unavailable');onStatus('Airport directory unavailable.');return;}
  loading=true;reset('Loading approved airports...');
  onStatus(global?'Searching all approved airports...':'Loading approved airports in '+airportCountryName(iso)+'...');
  try{
   const all=[],seen=new Set();let offset=0;
   for(let pageIndex=0;pageIndex<65;pageIndex++){
    const page=await reader.airports({countryIso:iso,search:global?search.value.trim():'',offset});
    if(ticket!==generation)return;
    if(page.countryIso!==iso||!Array.isArray(page.airports))throw Error('Unexpected airport catalog');
    for(const a of page.airports){
     if(!validAirportLocation(a)||(!global&&a.countryIso!==iso)||seen.has(a.key))continue;
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
 const onCountry=()=>{
  if(searchTimer!==null){clearTimeout(searchTimer);searchTimer=null;}
  search.value='';void load();
 };
 const onSearch=()=>{
  if(country.value){
   if(!loading)filter();
   return;
  }
  if(searchTimer!==null)clearTimeout(searchTimer);
  const query=search.value.trim();
  if(query.length<2){
   ++generation;entries=[];known=new Map();selected='';
   reset('Type an airport or city');
   onStatus('Type 2 or more characters to search airports in all countries.');
   return;
  }
  searchTimer=setTimeout(()=>{searchTimer=null;void load();},250);
 };
 const onAirport=()=>{selected=airport.value;onSelect(current())};
 const choose=key=>{
  const choice=known.get(key);
  if(!choice)return false;
  selected=key;
  // Keep the search text as the selected airport; one combined airport field.
  search.value=choice.name;
  filter();
  airport.value=key;onSelect(current());
  onResults([],false);
  return true;
 };
 country.addEventListener('change',onCountry);
 search.addEventListener('input',onSearch);
 airport.addEventListener('change',onAirport);
 reset('Choose country first');
 return Object.freeze({load,refresh:load,selected:current,choose,
  invalidate:()=>{
   generation++;if(searchTimer!==null){clearTimeout(searchTimer);searchTimer=null;}
   loading=false;entries=[];known=new Map();reset('Choose country first');
  },
  getAirports:()=>entries.slice()});
}
