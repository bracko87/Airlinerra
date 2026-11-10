/**
 * Game-styled HH:MM picker for player controls.
 * Keeps the original input/value/change event as the single source of truth.
 * Does not depend on the browser's native <input type="time"> popup.
 */
export const gameTimeValue=value=>/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(String(value||''))?
 String(value):null;
const two=n=>String(n).padStart(2,'0');

export function installGameTimePickers({doc,root}={}){
 if(!doc?.querySelectorAll||!root?.querySelectorAll)throw Error('Game time picker needs document and root');
 const controls=new Map();
 let opened=null;
 const eligible=node=>node?.tagName==='INPUT'&&node.type==='time'&&
  !node.hasAttribute('data-native-time')&&!controls.has(node);
 const close=()=>{
  if(!opened)return;
  opened.popup.hidden=true;
  opened.trigger.setAttribute('aria-expanded','false');
  opened=null;
 };
 const attach=input=>{
  if(!eligible(input))return;
  const originalType=input.type;
  // Removing the "time" type is necessary: readonly alone does not suppress
  // native browser picker UIs across desktop browsers.
  input.type='text';input.readOnly=true;input.inputMode='none';
  input.classList.add('game-time-input');
  const wrap=doc.createElement('span');wrap.className='game-time-wrap';
  input.before(wrap);
  const trigger=doc.createElement('button');trigger.type='button';
  trigger.className='game-time-trigger';
  trigger.textContent='◷';
  trigger.setAttribute('aria-haspopup','dialog');
  trigger.setAttribute('aria-expanded','false');
  trigger.setAttribute('aria-label','Choose '+(input.getAttribute('aria-label')||'time'));
  const popup=doc.createElement('div');popup.className='game-time-popup';popup.hidden=true;
  popup.setAttribute('role','dialog');
  popup.setAttribute('aria-label','Select hours and minutes');
  wrap.append(input,trigger,popup);
  let chosen=gameTimeValue(input.value)||'09:00';
  const refresh=()=>{trigger.disabled=input.disabled;input.setAttribute('aria-readonly','true');
   if(!gameTimeValue(input.value))input.value=chosen;};
  const render=()=>{
   popup.replaceChildren();
   const heading=doc.createElement('div');heading.className='game-time-heading';
   heading.textContent='Departure time · '+chosen;
   popup.append(heading);
   const columns=doc.createElement('div');columns.className='game-time-columns';
   for(const [type,total,active] of [['hour',24,chosen.slice(0,2)],['minute',60,chosen.slice(3,5)]]){
    const group=doc.createElement('div');group.className='game-time-list';
    group.setAttribute('role','group');
    group.setAttribute('aria-label',type==='hour'?'Hours':'Minutes');
    for(let n=0;n<total;n++){
     const time=two(n),button=doc.createElement('button');button.type='button';
     button.className='game-time-option';button.textContent=time;
     button.dataset.gameTimePart=type;button.dataset.gameTimeValue=time;
     button.setAttribute('aria-pressed',String(time===active));
     button.addEventListener('click',()=>{
      chosen=type==='hour'?time+chosen.slice(2):chosen.slice(0,3)+time;
      render();
     });
     group.append(button);
    }
    columns.append(group);
   }
   popup.append(columns);
   const actions=doc.createElement('div');actions.className='game-time-actions';
   for(const [label,action] of [['Cancel','cancel'],['Apply time','apply']]){
    const button=doc.createElement('button');button.type='button';
    button.textContent=label;button.dataset.gameTimeAction=action;
    button.className=action==='apply'?'primary':'secondary';
    button.addEventListener('click',()=>{
     if(action==='apply'&&gameTimeValue(chosen)&&input.value!==chosen){
      input.value=chosen;input.dispatchEvent(new Event('change',{bubbles:true}));
     }
     close();trigger.focus();
    });
    actions.append(button);
   }
   popup.append(actions);
  };
  const open=()=>{
   if(input.disabled)return;
   if(opened?.input===input){close();return;}
   close();chosen=gameTimeValue(input.value)||'09:00';
   render();popup.hidden=false;
   const rect=wrap.getBoundingClientRect();
   popup.style.left=Math.max(8,Math.min(rect.left,window.innerWidth-304))+'px';
   const required=370;
   const above=window.innerHeight-rect.bottom<required&&rect.top>required;
   popup.style.top=Math.max(8,above?rect.top-required:Math.min(window.innerHeight-required-8,rect.bottom+5))+'px';
   trigger.setAttribute('aria-expanded','true');
   opened={input,popup,trigger,wrap};
   popup.querySelector('.game-time-option[aria-pressed="true"]')?.focus();
  };
  trigger.addEventListener('click',open);
  input.addEventListener('click',open);
  input.addEventListener('keydown',event=>{
   if(event.key==='Enter'||event.key===' '||event.key==='ArrowDown'){
    event.preventDefault();open();
   }
  });
  controls.set(input,{refresh,destroy(){
   if(opened?.input===input)close();
   wrap.before(input);wrap.remove();input.type=originalType;
   input.readOnly=false;input.classList.remove('game-time-input');
  }});
  refresh();
 };
 const scan=()=>{for(const input of root.querySelectorAll('input[type="time"]'))attach(input)};
 scan();
 const observer=new MutationObserver(records=>{
  let rescan=false;
  for(const record of records){
   if(record.type==='attributes'&&controls.has(record.target))
    controls.get(record.target).refresh();
   if(record.type==='childList')
    for(const node of record.addedNodes){
     if(node.nodeType===1&&(node.matches?.('input[type="time"]')||
       node.querySelector?.('input[type="time"]')))rescan=true;
    }
  }
  if(rescan)scan();
  for(const [input,ctrl] of controls){
   if(!input.isConnected){ctrl.destroy();controls.delete(input)}
  }
 });
 observer.observe(root,{subtree:true,childList:true,attributes:true,attributeFilter:['disabled']});
 const onClick=event=>{if(opened&&!opened.wrap.contains(event.target))close()};
 const onKey=event=>{if(opened&&event.key==='Escape'){const active=opened;close();active.trigger.focus()}};
 const onScroll=event=>{if(opened&&!opened.popup.contains(event.target))close()};
 doc.addEventListener('click',onClick);
 doc.addEventListener('keydown',onKey);
 doc.addEventListener('scroll',onScroll,true);
 const refresh=()=>{scan();for(const ctrl of controls.values())ctrl.refresh()};
 return Object.freeze({refresh,destroy(){
  observer.disconnect();doc.removeEventListener('click',onClick);
  doc.removeEventListener('keydown',onKey);doc.removeEventListener('scroll',onScroll,true);
  close();for(const ctrl of controls.values())ctrl.destroy();controls.clear();
 }});
}
