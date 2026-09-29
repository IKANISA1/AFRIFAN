import { WorkerEntrypoint } from 'cloudflare:workers';
import { BrowserSessionService,expireBrowserSecrets } from './browser-session-service.mjs';
import { publicError } from './errors.mjs';
async function invoke(env,method,input){
 try{return {ok:true,value:await new BrowserSessionService(env)[method](input)};}
 catch(e){const error=publicError(e);return {ok:false,error:error.code,status:error.status};}
}
const hidden=()=>new Response(null,{status:404,headers:{'cache-control':'no-store'}});
/** Bind only the dedicated same-origin browser gateway to this identity capability. */
export class BrowserIdentity extends WorkerEntrypoint {
 start(input){return invoke(this.env,'start',input);}
 bootstrap(cookie){return invoke(this.env,'bootstrapView',cookie);}
 challenge(input){return invoke(this.env,'challenge',input);}
 verify(input){return invoke(this.env,'verify',input);}
 current(cookie){return invoke(this.env,'current',cookie);}
 rotate(input){return invoke(this.env,'rotate',input);}
 logout(input){return invoke(this.env,'logout',input);}
 fetch(){return hidden();}
}
export default {fetch:hidden,scheduled(_event,env,ctx){ctx.waitUntil(expireBrowserSecrets(env.AUTH_DB));}};
