import {traceOperation} from '../../shared-telemetry/telemetry.mjs';
const NATIVE=new Map([['otp/challenges','otp_challenge'],['otp/verifications','otp_verify'],['session','session_read'],
 ['sessions/refresh','session_refresh'],['sessions/revoke','session_revoke'],['deletion-requests','account_deletion']]);
const BROWSER=new Map([['start','session_start'],['bootstrapView','session_bootstrap'],['challenge','otp_challenge'],
 ['verify','otp_verify'],['current','session_read'],['rotate','session_refresh'],['logout','session_revoke']]);
const BROWSER_MUTATIONS=new Set(['start','challenge','verify','rotate','logout']);
/** Only a finite operation label is derived from the request. Ingress club IDs are
 * untrusted caller values, so native observations never copy them into telemetry.
 */
export function nativeOperation(request){try{const suffix=new URL(request.url).pathname.match(/^\/v1\/auth\/clubs\/[1-9]\d{0,9}\/(.+)$/)?.[1];return NATIVE.get(suffix)??'route';}catch{return 'route';}}
export function configuredBrowserClub(env){try{const value=env?.BROWSER_CLUB_ID;if(typeof value!=='string'||!/^[1-9]\d{0,9}$/.test(value))return null;
 const id=Number(value);return Number.isSafeInteger(id)&&id<=2147483647?id:null;}catch{return null;}}
export function httpOutcome(value){const status=value?.status;return status>=500?'unavailable':status===401||status===403?'denied':status>=400?'rejected':status>=200&&status<400?'completed':'unknown';}
export function rpcOutcome(value){if(value?.ok===true)return 'completed';const status=value?.status??value?.error?.status;
 return value?.ok===false?(status>=500?'unavailable':status===401||status===403?'denied':'rejected'):'unknown';}
export function observeNativeRequest(env,request,work,{clock=Date.now,ctx,selectOutcome=httpOutcome}={}){
 return traceOperation(env,{service:'supporter_auth',operation:nativeOperation(request),clubId:null},work,{clock,ctx,selectOutcome});
}
export function observeBrowserRequest(env,operation,work,{clock=Date.now,ctx,selectOutcome=httpOutcome}={}){
 return traceOperation(env,{service:'supporter_browser',operation,clubId:configuredBrowserClub(env)},work,{clock,ctx,selectOutcome});
}
/** Private wrappers observe once at the capability entrypoint, never inside domain work. */
export function observeNativeIdentityRpc(env,work,{clock=Date.now,ctx}={}){
 return traceOperation(env,{service:'supporter_auth',operation:'session_read',clubId:null},work,{clock,ctx,selectOutcome:rpcOutcome});
}
export function observeBrowserIdentityRpc(env,method,work,{clock=Date.now,ctx}={}){
 return traceOperation(env,{service:'supporter_auth',operation:BROWSER.get(method)??'route',clubId:configuredBrowserClub(env)},work,{clock,ctx,
  selectOutcome:value=>BROWSER_MUTATIONS.has(method)&&value?.ok===false?'unknown':rpcOutcome(value)});
}
export function observeIdentityMaintenance(env,work,{clock=Date.now,ctx,operation='identity_maintenance',selectOutcome}={}){
 return traceOperation(env,{service:'supporter_auth',operation,clubId:null},work,{clock,ctx,
  selectOutcome:selectOutcome??(value=>value?.disabled===true?'no_work':'completed')});
}
