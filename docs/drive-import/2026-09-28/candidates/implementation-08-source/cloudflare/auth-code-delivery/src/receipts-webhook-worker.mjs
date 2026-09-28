import { handleReceipt } from './receipt-http.mjs';
import { ReceiptStore } from './receipt-store.mjs';
export default {
  fetch(request,env) { return handleReceipt(request,env); },
  async scheduled(_event,env,ctx) {
    if(env.RECEIPT_RECONCILE_ENABLED!=='true')return;
    // Bounded reconciliation only: no provider calls, message sends or account mutations.
    ctx.waitUntil(new ReceiptStore(env).reconcile());
  },
};
