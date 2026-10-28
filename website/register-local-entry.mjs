import {isLocalDemoOrigin} from './local-demo-session.mjs';
if(isLocalDemoOrigin(window.location)){
  const link=document.getElementById('local-registration-entry');
  if(link)link.hidden=false;
}
