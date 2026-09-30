import { WorkerEntrypoint } from 'cloudflare:workers';
import { invokeNativeIdentityCurrent } from './entrypoint-rpc.mjs';
/** Private capability. Only explicitly reviewed domain gateways may be bound to it. */
export class SupporterIdentityVerifier extends WorkerEntrypoint {
 async current({clubId,accessToken}){return invokeNativeIdentityCurrent(this.env,{clubId,accessToken},{ctx:this.ctx});}
 async fetch(){return new Response(null,{status:404});}
}
export default {fetch(){return new Response(null,{status:404});}};
