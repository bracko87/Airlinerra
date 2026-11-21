/* Airlinerra presentation convention: use ASCII hyphens in displayed copy.
 * Do not rewrite application source, API data, input values or identifiers.
 * Runs on every page, including asynchronously rendered game views.
 */
(function(){
 'use strict';
 const DASH=/[\u2010-\u2015\u2212]/g;
 const HAS_DASH=/[\u2010-\u2015\u2212]/;
 const normalize=value=>String(value).replace(DASH,'-');
 const excluded='script,style,textarea,code,pre,kbd,samp,math,[contenteditable]:not([contenteditable="false"])';
 const attributes=['title','placeholder','aria-label','alt'];
 function normalizeText(node){
  const parent=node.parentElement;
  if(!parent||parent.closest(excluded)||!HAS_DASH.test(node.data))return;
  // An option without an explicit value uses its text as its submitted value.
  // Preserve that value before replacing the visual label.
  const option=parent.closest('option');
  if(option&&!option.hasAttribute('value'))option.setAttribute('value',option.value);
  node.data=normalize(node.data);
 }
 function normalizeElement(node){
  if(node.closest(excluded))return;
  for(const name of attributes){
   const value=node.getAttribute(name);
   if(value!==null&&HAS_DASH.test(value))node.setAttribute(name,normalize(value));
  }
  if(node.matches('option,optgroup')){
   const label=node.getAttribute('label');
   if(label!==null&&HAS_DASH.test(label))node.setAttribute('label',normalize(label));
  }
 }
 function normalizeTree(root){
  if(root.nodeType===3){normalizeText(root);return;}
  if(root.nodeType!==1&&root.nodeType!==9&&root.nodeType!==11)return;
  if(root.nodeType===1){if(root.closest(excluded))return;normalizeElement(root);}
  const walker=document.createTreeWalker(root,NodeFilter.SHOW_ELEMENT|NodeFilter.SHOW_TEXT,{
   acceptNode(node){
    if(node.nodeType===1&&node.matches(excluded))return NodeFilter.FILTER_REJECT;
    return NodeFilter.FILTER_ACCEPT;
   }
  });
  while(walker.nextNode()){
   const node=walker.currentNode;
   if(node.nodeType===3)normalizeText(node);else normalizeElement(node);
  }
 }
 function start(){
  if(!document.documentElement)return;
  const observer=new MutationObserver(records=>{
   for(const record of records){
    if(record.type==='characterData')normalizeText(record.target);
    else if(record.type==='attributes')normalizeElement(record.target);
    else for(const node of record.addedNodes)normalizeTree(node);
   }
  });
  observer.observe(document.documentElement,{subtree:true,childList:true,characterData:true,
   attributes:true,attributeFilter:[...attributes,'label']});
  normalizeTree(document.documentElement);
 }
 if(document.documentElement)start();else document.addEventListener('DOMContentLoaded',start,{once:true});
})();
