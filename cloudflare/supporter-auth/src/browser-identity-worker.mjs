import { WorkerEntrypoint } from 'cloudflare:workers';
import { invokeBrowserIdentity } from './entrypoint-rpc.mjs';
import { observeIdentityMaintenance } from './entrypoint-telemetry.mjs';
import { expireBrowserSecrets } from './browser-session-service.mjs';
const hidden=()=>new Response(null,{status:404,headers:{'cache-control':'no-store'}});
/** Bind only the dedicated same-origin browser gateway to this identity capability. */
export class BrowserIdentity extends WorkerEntrypoint {
 start(input){return invokeBrowserIdentity(this.env,'start',input,{ctx:this.ctx});}
 bootstrap(cookie){return invokeBrowserIdentity(this.env,'bootstrapView',cookie,{ctx:this.ctx});}
 challenge(input){return invokeBrowserIdentity(this.env,'challenge',input,{ctx:this.ctx});}
 verify(input){return invokeBrowserIdentity(this.env,'verify',input,{ctx:this.ctx});}
 current(cookie){return invokeBrowserIdentity(this.env,'current',cookie,{ctx:this.ctx});}
 rotate(input){return invokeBrowserIdentity(this.env,'rotate',input,{ctx:this.ctx});}
 logout(input){return invokeBrowserIdentity(this.env,'logout',input,{ctx:this.ctx});}
 fetch(){return hidden();}
}
export default {fetch:hidden,scheduled(_event,env,ctx){ctx.waitUntil(observeIdentityMaintenance(env,()=>expireBrowserSecrets(env.AUTH_DB),{ctx,operation:'browser_secret_expiry'}));}};
