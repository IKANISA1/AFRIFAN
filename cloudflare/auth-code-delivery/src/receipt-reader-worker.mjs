import { WorkerEntrypoint } from 'cloudflare:workers';
import { ReceiptStore } from './receipt-store.mjs';
import {rpcOperation} from '../../shared-telemetry/entrypoints.mjs';
export class AuthenticationDeliveryReceiptReader extends WorkerEntrypoint {
  async readDeliveryStatus(request) {
    return rpcOperation(this,{service:'receipt_delivery',operation:'delivery_receipt'},request,async()=>{
    try { return await new ReceiptStore(this.env).read(request); }
    catch { throw new Error('receipt_unavailable'); }
    });
  }
  fetch() { return new Response('Not found',{status:404}); }
}
export default { fetch() { return new Response('Not found',{status:404}); } };
