import {WorkerEntrypoint} from 'cloudflare:workers';
import {PaymentExceptionService} from './service.mjs';
import {rpc} from './policy.mjs';
import {rpcOperation} from '../../shared-telemetry/entrypoints.mjs';
/** No generic SQL, payment writer, refund, identity-provider or HTTP capability. */
export class PaymentExceptionCases extends WorkerEntrypoint {
  access(input) { return rpcOperation(this,{service:'payment_exceptions',operation:'case_read'},input,()=>rpc(()=>new PaymentExceptionService(this.env).access(input))); }
  operation(input) { return rpcOperation(this,{service:'payment_exceptions',operation:'case_read'},input,()=>rpc(()=>new PaymentExceptionService(this.env).operation(input))); }
  get(input) { return rpcOperation(this,{service:'payment_exceptions',operation:'case_read'},input,()=>rpc(()=>new PaymentExceptionService(this.env).get(input))); }
  list(input) { return rpcOperation(this,{service:'payment_exceptions',operation:'case_read'},input,()=>rpc(()=>new PaymentExceptionService(this.env).list(input))); }
  history(input) { return rpcOperation(this,{service:'payment_exceptions',operation:'case_read'},input,()=>rpc(()=>new PaymentExceptionService(this.env).history(input))); }
  command(input) { return rpcOperation(this,{service:'payment_exceptions',operation:'case_command',mutating:true},input,()=>rpc(()=>new PaymentExceptionService(this.env).command(input))); }
  fetch() { return new Response(null,{status:404,headers:{'cache-control':'no-store'}}); }
}
export default {fetch(){return new Response(null,{status:404,headers:{'cache-control':'no-store'}});}};
