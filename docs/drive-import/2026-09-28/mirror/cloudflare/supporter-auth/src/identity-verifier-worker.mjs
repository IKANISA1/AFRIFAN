import { WorkerEntrypoint } from 'cloudflare:workers';
import { IdentityService } from './identity-service.mjs';
import { publicError } from './errors.mjs';
/** Private capability. Only explicitly reviewed domain gateways may be bound to it. */
export class SupporterIdentityVerifier extends WorkerEntrypoint {
 async current({clubId,accessToken}){try{return {ok:true,value:await new IdentityService(this.env).current(clubId,accessToken)};}
  catch(error){const e=publicError(error);return {ok:false,error:e.code,status:e.status};}}
 async fetch(){return new Response(null,{status:404});}
}
export default {fetch(){return new Response(null,{status:404});}};
