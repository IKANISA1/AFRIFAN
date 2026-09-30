import { handleReceipt } from './receipt-http.mjs';
import { ReceiptStore } from './receipt-store.mjs';
import {httpOperation} from '../../shared-telemetry/entrypoints.mjs';
import {traceOperation} from '../../shared-telemetry/telemetry.mjs';
export default {
  fetch(request,env,ctx) { return httpOperation(env,{service:'receipt_delivery',operation:'delivery_receipt'},request,()=>handleReceipt(request,env),ctx); },
  async scheduled(_event,env,ctx) {
    if(env.RECEIPT_RECONCILE_ENABLED!=='true')return;
    // Bounded reconciliation only: no provider calls, message sends or account mutations.
    ctx.waitUntil(traceOperation(env,{service:'receipt_delivery',operation:'delivery_receipt'},()=>new ReceiptStore(env).reconcile(),
      {ctx,mutating:true,selectOutcome:result=>result.linked===0?'no_work':'completed'}));
  },
};
