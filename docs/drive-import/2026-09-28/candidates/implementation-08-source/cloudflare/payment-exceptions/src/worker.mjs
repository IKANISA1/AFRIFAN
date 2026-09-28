import {WorkerEntrypoint} from 'cloudflare:workers';
import {PaymentExceptionService} from './service.mjs';
import {rpc} from './policy.mjs';
/** No generic SQL, payment writer, refund, identity-provider or HTTP capability. */
export class PaymentExceptionCases extends WorkerEntrypoint {
  access(input) { return rpc(()=>new PaymentExceptionService(this.env).access(input)); }
  operation(input) { return rpc(()=>new PaymentExceptionService(this.env).operation(input)); }
  get(input) { return rpc(()=>new PaymentExceptionService(this.env).get(input)); }
  list(input) { return rpc(()=>new PaymentExceptionService(this.env).list(input)); }
  history(input) { return rpc(()=>new PaymentExceptionService(this.env).history(input)); }
  command(input) { return rpc(()=>new PaymentExceptionService(this.env).command(input)); }
  fetch() { return new Response(null,{status:404,headers:{'cache-control':'no-store'}}); }
}
export default {fetch(){return new Response(null,{status:404,headers:{'cache-control':'no-store'}});}};
