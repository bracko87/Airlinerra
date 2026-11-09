/** Give visible native game selects the existing Airlinerra custom menu.
 * The select itself retains the real value, disabled state and change events.
 * The route's hidden airport state controls and already-enhanced setup menus are
 * deliberately excluded. No network or game-state writes occur here.
 */
import {createDownwardMenu} from './setup-choice-menu.mjs';

export function installGameSelectMenus({doc,root}={}){
 if(!doc?.querySelectorAll||!root?.querySelectorAll)throw Error('Game select menu needs a DOM root');
 const controllers=new Map();
 const eligible=select=>select?.tagName==='SELECT'&&
  !select.hidden&&!select.multiple&&select.getAttribute('aria-hidden')!=='true'&&
  !select.closest('.down-menu')&&!select.classList.contains('route-native-airport')&&
  !select.classList.contains('route-native-country')&&!select.hasAttribute('data-native-select');
 const addSelect=select=>{
  if(!eligible(select)||controllers.has(select))return;
  const ctrl=createDownwardMenu(select,{placeholder:'Choose an option'});
  if(select.nextElementSibling?.classList.contains('down-menu'))
   select.nextElementSibling.classList.add('game-select-menu');
  controllers.set(select,ctrl);
 };
 const scan=()=>{for(const select of root.querySelectorAll('select'))addSelect(select);};
 const refresh=()=>{
  scan();
  for(const [select,controller] of controllers){
   if(!select.isConnected){controller.destroy();controllers.delete(select);continue;}
   controller.refresh();
  }
 };
 scan();
 // Workspaces populate selects asynchronously. Observe their options so the
 // custom presentation tracks the authoritative native select after any list.
 const observer=new MutationObserver(records=>{
  let addedSelect=false;
  const changed=new Set();
  for(const record of records){
   const target=record.target;
   const select=target?.tagName==='SELECT'?target:
    target?.closest?.('select');
   if(select&&controllers.has(select)){changed.add(select);continue;}
   if(record.type==='childList')
    for(const node of record.addedNodes){
     if(node.nodeType!==1)continue;
     if(node.tagName==='SELECT'||node.querySelector?.('select'))addedSelect=true;
   }
  }
  if(addedSelect)scan();
  for(const select of changed)controllers.get(select)?.refresh();
 });
 observer.observe(root,{subtree:true,childList:true,attributes:true,attributeFilter:['disabled','selected','label']});
 const refreshListener=()=>refresh();
 doc.addEventListener('airlinerra:refresh-game-select-menus',refreshListener);
 return Object.freeze({refresh,destroy(){
  observer.disconnect();
  doc.removeEventListener('airlinerra:refresh-game-select-menus',refreshListener);
  for(const controller of controllers.values())controller.destroy();
  controllers.clear();
 }});
}
