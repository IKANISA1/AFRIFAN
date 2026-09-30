import {WorkerEntrypoint} from 'cloudflare:workers';
import {MembershipCheckoutService} from './checkout-service.mjs';
import {PaymentHandoffService} from './handoff-service.mjs';
import {rpcOperation} from '../../shared-telemetry/entrypoints.mjs';
const hidden=()=>new Response('Not found',{status:404,headers:{'cache-control':'no-store'}});
export default {fetch:hidden};
// Fixed deployment identities; callers must not pass an authority principal.
export class MembershipCheckout extends WorkerEntrypoint {
  fetch(){return hidden();}
  lookupPreparedOperation(input){return rpcOperation(this,{service:'payment_allocation',operation:'checkout_read'},input,()=>new MembershipCheckoutService(this.env,this.env.CHECKOUT_PRINCIPAL_ID).lookupPreparedOperation(input));}
  prepare(input){return rpcOperation(this,{service:'payment_allocation',operation:'checkout_create',mutating:true},input,()=>new MembershipCheckoutService(this.env,this.env.CHECKOUT_PRINCIPAL_ID).prepare(input));}
  reserveHandoff(input){return rpcOperation(this,{service:'payment_allocation',operation:'handoff_reserve',mutating:true},input,()=>new PaymentHandoffService(this.env,this.env.CHECKOUT_PRINCIPAL_ID).reserveHandoff(input));}
  releaseHandoff(input){return rpcOperation(this,{service:'payment_allocation',operation:'handoff_release',mutating:true},input,()=>new PaymentHandoffService(this.env,this.env.CHECKOUT_PRINCIPAL_ID).releaseHandoff(input));}
  claimHandoff(input){return rpcOperation(this,{service:'payment_allocation',operation:'handoff_claim',mutating:true},input,()=>new PaymentHandoffService(this.env,this.env.CHECKOUT_PRINCIPAL_ID).claimHandoff(input));}
}
export class MembershipCheckoutReader extends WorkerEntrypoint {
  fetch(){return hidden();}
  read(input){return rpcOperation(this,{service:'payment_allocation',operation:'membership_read'},input,()=>new MembershipCheckoutService(this.env,this.env.CHECKOUT_READ_PRINCIPAL_ID).read(input));}
  history(input){return rpcOperation(this,{service:'payment_allocation',operation:'membership_history'},input,()=>new MembershipCheckoutService(this.env,this.env.CHECKOUT_READ_PRINCIPAL_ID).history(input));}
  historicalReceipt(input){return rpcOperation(this,{service:'payment_allocation',operation:'payment_receipt'},input,()=>new MembershipCheckoutService(this.env,this.env.CHECKOUT_READ_PRINCIPAL_ID).historicalReceipt(input));}
  offers(input){return rpcOperation(this,{service:'payment_allocation',operation:'checkout_offers'},input,()=>new MembershipCheckoutService(this.env,this.env.CHECKOUT_READ_PRINCIPAL_ID).offers(input));}
  membershipStatus(input){return rpcOperation(this,{service:'payment_allocation',operation:'membership_read'},input,()=>new MembershipCheckoutService(this.env,this.env.CHECKOUT_READ_PRINCIPAL_ID).membershipStatus(input));}
  currentHandoff(input){return rpcOperation(this,{service:'payment_allocation',operation:'handoff_read'},input,()=>new PaymentHandoffService(this.env,this.env.CHECKOUT_READ_PRINCIPAL_ID).currentHandoff(input));}
}
