import {WorkerEntrypoint} from 'cloudflare:workers';
import {MembershipCheckoutService} from './checkout-service.mjs';
import {PaymentHandoffService} from './handoff-service.mjs';
const hidden=()=>new Response('Not found',{status:404,headers:{'cache-control':'no-store'}});
export default {fetch:hidden};
// Fixed deployment identities; callers must not pass an authority principal.
export class MembershipCheckout extends WorkerEntrypoint {
  fetch(){return hidden();}
  lookupPreparedOperation(input){return new MembershipCheckoutService(this.env,this.env.CHECKOUT_PRINCIPAL_ID).lookupPreparedOperation(input);}
  prepare(input){return new MembershipCheckoutService(this.env,this.env.CHECKOUT_PRINCIPAL_ID).prepare(input);}
  reserveHandoff(input){return new PaymentHandoffService(this.env,this.env.CHECKOUT_PRINCIPAL_ID).reserveHandoff(input);}
  releaseHandoff(input){return new PaymentHandoffService(this.env,this.env.CHECKOUT_PRINCIPAL_ID).releaseHandoff(input);}
  claimHandoff(input){return new PaymentHandoffService(this.env,this.env.CHECKOUT_PRINCIPAL_ID).claimHandoff(input);}
}
export class MembershipCheckoutReader extends WorkerEntrypoint {
  fetch(){return hidden();}
  read(input){return new MembershipCheckoutService(this.env,this.env.CHECKOUT_READ_PRINCIPAL_ID).read(input);}
  history(input){return new MembershipCheckoutService(this.env,this.env.CHECKOUT_READ_PRINCIPAL_ID).history(input);}
  historicalReceipt(input){return new MembershipCheckoutService(this.env,this.env.CHECKOUT_READ_PRINCIPAL_ID).historicalReceipt(input);}
  offers(input){return new MembershipCheckoutService(this.env,this.env.CHECKOUT_READ_PRINCIPAL_ID).offers(input);}
  membershipStatus(input){return new MembershipCheckoutService(this.env,this.env.CHECKOUT_READ_PRINCIPAL_ID).membershipStatus(input);}
  currentHandoff(input){return new PaymentHandoffService(this.env,this.env.CHECKOUT_READ_PRINCIPAL_ID).currentHandoff(input);}
}
