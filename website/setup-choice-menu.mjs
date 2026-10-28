/** Accessible downward-opening country, world and airport menus.
 * Keeps the underlying select authoritative for the existing form and API.
 * Flag images are real national flag images, never emoji letters/codes.
 */
export function createDownwardMenu(select,{flags=false,placeholder='Select an option',onChange=()=>{}}={}){
 if(!(select instanceof HTMLSelectElement))throw Error('Select required');
 const shell=document.createElement('div');shell.className='down-menu';
 const trigger=document.createElement('button');trigger.type='button';
 trigger.className='down-menu-trigger';trigger.setAttribute('aria-haspopup','listbox');
 trigger.setAttribute('aria-expanded','false');
 const panel=document.createElement('div');panel.className='down-menu-options';
 panel.setAttribute('role','listbox');panel.hidden=true;
 const label=document.createElement('span');label.className='down-menu-value';
 const caret=document.createElement('span');caret.className='down-menu-caret';caret.setAttribute('aria-hidden','true');
 trigger.append(label,caret);shell.append(trigger,panel);
 select.after(shell);select.hidden=true;
 const flagFor=(code)=>{
  const img=document.createElement('img');img.className='country-flag';
  img.src='/assets/flags/'+code.toLowerCase()+'.svg';
  img.alt='';img.setAttribute('aria-hidden','true');img.loading='lazy';
  return img;
 };
 function close(){panel.hidden=true;trigger.setAttribute('aria-expanded','false');}
 function refresh(){
  trigger.disabled=select.disabled;
  label.replaceChildren();
  const selected=select.selectedOptions[0];
  if(flags&&select.value&&/^[A-Z]{2}$/.test(select.value))label.append(flagFor(select.value));
  label.append(document.createTextNode(selected?.textContent||placeholder));
  panel.replaceChildren();
  for(const option of select.options){
   if(!option.value||option.disabled)continue;
   const button=document.createElement('button');button.type='button';
   button.className='down-menu-option';button.setAttribute('role','option');
   button.setAttribute('aria-selected',String(option.value===select.value));
   button.dataset.value=option.value;
   if(flags&&/^[A-Z]{2}$/.test(option.value))button.append(flagFor(option.value));
   const span=document.createElement('span');span.textContent=option.textContent;
   button.append(span);
   button.addEventListener('click',()=>{
    select.value=option.value;close();
    select.dispatchEvent(new Event('change',{bubbles:true}));
    refresh();onChange(option.value);
    trigger.focus();
   });
   panel.append(button);
  }
 }
 trigger.addEventListener('click',()=>{
  if(trigger.disabled)return;
  const open=panel.hidden;
  for(const other of document.querySelectorAll('.down-menu-options:not([hidden])')){
   other.hidden=true;other.previousElementSibling?.setAttribute('aria-expanded','false');
  }
  panel.hidden=!open;trigger.setAttribute('aria-expanded',String(open));
  if(open){
   // Always place list BELOW its control; scroll page if there is insufficient room.
   const rect=trigger.getBoundingClientRect();
   if(window.innerHeight-rect.bottom<230)window.scrollBy({top:Math.min(310,230-(window.innerHeight-rect.bottom)),behavior:'smooth'});
  }
 });
 select.addEventListener('change',refresh);
 document.addEventListener('click',event=>{if(!shell.contains(event.target))close();});
 document.addEventListener('keydown',event=>{
  if(panel.hidden)return;
  if(event.key==='Escape'){close();trigger.focus();}
  if(event.key==='ArrowDown'||event.key==='ArrowUp'){
   event.preventDefault();
   const buttons=[...panel.querySelectorAll('button')];
   const active=buttons.indexOf(document.activeElement);
   buttons[(active+(event.key==='ArrowDown'?1:-1)+buttons.length)%buttons.length]?.focus();
  }
 });
 refresh();
 return Object.freeze({refresh,close});
}
