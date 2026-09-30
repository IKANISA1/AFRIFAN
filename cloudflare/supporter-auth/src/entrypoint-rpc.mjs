import {observeNativeIdentityRpc,observeBrowserIdentityRpc} from './entrypoint-telemetry.mjs';
import {IdentityService} from './identity-service.mjs';
import {BrowserSessionService} from './browser-session-service.mjs';
import {publicError} from './errors.mjs';
/** Node-testable private capability logic. WorkerEntrypoint delegates here; the
 * public browser gateway does not import identity execution through this helper.
 */
export function invokeNativeIdentityCurrent(env,input,{clock=Date.now,ctx}={}){
 return observeNativeIdentityRpc(env,async()=>{try{return {ok:true,value:await new IdentityService(env,{clock}).current(input.clubId,input.accessToken)};}
  catch(error){const e=publicError(error);return {ok:false,error:e.code,status:e.status};}},{clock,ctx});
}
export function invokeBrowserIdentity(env,method,input,{clock=Date.now,ctx}={}){
 return observeBrowserIdentityRpc(env,method,async()=>{try{return {ok:true,value:await new BrowserSessionService(env,{clock})[method](input)};}
  catch(error){const e=publicError(error);return {ok:false,error:e.code,status:e.status};}},{clock,ctx});
}
