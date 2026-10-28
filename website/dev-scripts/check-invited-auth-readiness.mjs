/** Read-only live check: executed ONLY when generating the manual testing ZIP. */
import {inspectInvitedTesterProvider} from '../invited-tester-entry.mjs';
import {AIRLINERRA_INVITED_TESTER_PUBLIC_SETTINGS as conf}
  from '../invited-tester-public-settings.mjs';

try{
  const state=await inspectInvitedTesterProvider({
    supabaseUrl:conf.supabaseUrl,
    publishableKey:conf.publishableKey
  });
  if(state.inviteOnly!==true||state.emailConfirmedRequired!==true||
    state.anonymousDisabled!==true){
    throw new Error('Private invite-only identity gate not verified.');
  }
  process.stdout.write('Hosted Airlinerra Auth is invite-only: signup and anonymous login disabled; email confirmation required.\n');
}catch{
  process.stderr.write('Manual package blocked: hosted Airlinerra Auth safety settings could not be independently verified.\n');
  process.exitCode=1;
}
