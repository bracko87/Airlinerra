/** Downward-opening, accessible country/world/airport selector.
 * The original select retains authority; menu filtering never changes its
 * value until the user actually selects a real option.
 */
export function createDownwardMenu(select,{flags=false,placeholder='Select an option',onChange=()=>{}}={}){
 if(!(select instanceof HTMLSelectElement))throw Error('Select required');
 const shell=document.createElement('div');shell.className='down-menu';
 const trigger=document.createElement('button');trigger.type='button';
 trigger.className='down-menu-trigger';trigger.setAttribute('aria-haspopup','listbox');
 trigger.setAttribute('aria-expanded','false');
 trigger.setAttribute('aria-label',select.getAttribute('aria-label')||select.labels?.[0]?.textContent||placeholder);
 const panel=document.createElement('div');panel.className='down-menu-options';panel.hidden=true;
 const label=document.createElement('span');label.className='down-menu-value';
 const caret=document.createElement('span');caret.className='down-menu-caret';caret.setAttribute('aria-hidden','true');
 const options=document.createElement('div');options.className='down-menu-list';options.setAttribute('role','listbox');
 const empty=document.createElement('p');empty.className='down-menu-empty';empty.textContent='No matching countries';empty.hidden=true;
 let search=null;
 if(flags){
  const wrap=document.createElement('div');wrap.className='down-menu-search-wrap';
  search=document.createElement('input');search.type='search';search.className='down-menu-search';
  search.setAttribute('aria-label','Search for a country by name');
  search.placeholder='Type a country name...';search.autocomplete='off';search.spellcheck=false;
  wrap.append(search);panel.append(wrap);
 }
 panel.append(options,empty);trigger.append(label,caret);shell.append(trigger,panel);
 select.after(shell);select.hidden=true;
 const flagFor=code=>{
  const img=document.createElement('img');img.className='country-flag';
  img.src='https://flagcdn.com/w40/'+code.toLowerCase()+'.png';
  img.alt='';img.setAttribute('aria-hidden','true');img.loading='lazy';return img;
 };
 const normalize=text=>String(text||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLocaleLowerCase('en');
 function filter(){
  if(!search)return;
  const term=normalize(search.value.trim());let found=0;
  for(const option of options.querySelectorAll('.down-menu-option')){
   // Search the country name, not the airport count.
   const match=normalize(option.dataset.search).includes(term);
   option.hidden=!match;if(match)found++;
  }
  empty.hidden=found>0;
 }
 function close(){
  panel.hidden=true;trigger.setAttribute('aria-expanded','false');
  if(search)search.value='';
 }
 function refresh(){
  trigger.disabled=select.disabled;
  label.replaceChildren();
  const selected=select.selectedOptions[0];
  if(flags&&select.value&&/^[A-Z]{2}$/.test(select.value))label.append(flagFor(select.value));
  label.append(document.createTextNode(selected?.textContent||placeholder));
  options.replaceChildren();
  for(const option of select.options){
   if(!option.value||option.disabled)continue;
   const button=document.createElement('button');button.type='button';
   button.className='down-menu-option';button.setAttribute('role','option');
   button.setAttribute('aria-selected',String(option.value===select.value));
   button.dataset.value=option.value;
   button.dataset.search=(flags?option.textContent.replace(/\s*\(\d+ airports?\)\s*$/,''):option.textContent).trim();
   if(flags&&/^[A-Z]{2}$/.test(option.value))button.append(flagFor(option.value));
   const span=document.createElement('span');span.className='down-menu-option-label';
   span.textContent=option.textContent;button.append(span);
   const category=option.dataset.category;
   if(['Local','Regional','Medium','Large','Major Hub','Mega Hub'].includes(category)){
    const badge=document.createElement('span');badge.className='down-menu-category';
    badge.textContent=category;button.append(badge);
   }
   button.addEventListener('click',()=>{
    select.value=option.value;close();
    select.dispatchEvent(new Event('change',{bubbles:true}));
    refresh();onChange(option.value);trigger.focus();
   });
   options.append(button);
  }
  filter();
 }
 trigger.addEventListener('click',()=>{
  if(trigger.disabled)return;
  const open=panel.hidden;
  for(const other of document.querySelectorAll('.down-menu-options:not([hidden])')){
   other.hidden=true;other.previousElementSibling?.setAttribute('aria-expanded','false');
  }
  panel.hidden=!open;trigger.setAttribute('aria-expanded',String(open));
  if(open){
   if(search){search.value='';filter();search.focus();}
   const rect=trigger.getBoundingClientRect();
   if(window.innerHeight-rect.bottom<230)
    window.scrollBy({top:Math.min(310,230-(window.innerHeight-rect.bottom)),behavior:'smooth'});
  }
 });
 if(search){
  // Typing while the closed country control is focused opens the search.
  trigger.addEventListener('keydown',event=>{
   if(event.ctrlKey||event.metaKey||event.altKey||event.key.length!==1)return;
   event.preventDefault();
   if(panel.hidden)trigger.click();
   search.value+=event.key;filter();search.focus();
  });
  search.addEventListener('input',filter);
  search.addEventListener('keydown',event=>{
   if(event.key==='Enter'){
    const first=[...options.querySelectorAll('.down-menu-option')].find(button=>!button.hidden);
    if(first){event.preventDefault();first.click();}
   }
  });
 }
 select.addEventListener('change',refresh);
 document.addEventListener('click',event=>{if(!shell.contains(event.target))close();});
 document.addEventListener('keydown',event=>{
  if(panel.hidden)return;
  if(event.key==='Escape'){close();trigger.focus();return;}
  if(event.key==='ArrowDown'||event.key==='ArrowUp'){
   event.preventDefault();
   const visible=[...options.querySelectorAll('.down-menu-option')].filter(button=>!button.hidden);
   if(!visible.length)return;
   const active=visible.indexOf(document.activeElement);
   visible[(active+(event.key==='ArrowDown'?1:-1)+visible.length)%visible.length].focus();
  }
 });
 refresh();
 return Object.freeze({refresh,close});
}
