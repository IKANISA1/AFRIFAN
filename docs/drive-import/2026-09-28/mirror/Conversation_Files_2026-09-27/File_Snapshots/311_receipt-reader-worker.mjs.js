import { WorkerEntrypoint } from 'cloudflare:workers';
import { ReceiptStore } from './receipt-store.mjs';
export class AuthenticationDeliveryReceiptReader extends WorkerEntrypoint {
  async readDeliveryStatus(request) {
    try { return await new ReceiptStore(this.env).read(request); }
    catch { throw new Error('receipt_unavailable'); }
  }
  fetch() { return new Response('Not found',{status:404}); }
}
export default { fetch() { return new Response('Not found',{status:404}); } };
