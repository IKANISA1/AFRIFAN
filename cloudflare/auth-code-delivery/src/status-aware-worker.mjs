import { WorkerEntrypoint } from 'cloudflare:workers';
import { StatusAwareDeliveryService } from './status-aware-service.mjs';
export class AuthenticationCodeDelivery extends WorkerEntrypoint {
  async deliver(input) {
    try { return await new StatusAwareDeliveryService(this.env,{ctx:this.ctx}).deliver(input); }
    catch { throw new Error('delivery_unavailable'); }
  }
  async deliverWithReceipt(input) {
    try { return await new StatusAwareDeliveryService(this.env,{ctx:this.ctx}).deliverWithReceipt(input); }
    catch { throw new Error('delivery_unavailable'); }
  }
  fetch() { return new Response('Not found',{status:404}); }
}
export default { fetch() { return new Response('Not found',{status:404}); } };
