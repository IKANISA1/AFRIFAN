import {WorkerEntrypoint} from 'cloudflare:workers';
import {MembershipCheckoutService} from './checkout-service.mjs';
const hidden=()=>new Response('Not found',{status:404,headers:{'cache-control':'no-store'}});
export default {fetch:hidden};
// Fixed deployment identities; callers must not pass an authority principal.
export class MembershipCheckout extends WorkerEntrypoint {
  fetch(){return hidden();}
  prepare(input){return new MembershipCheckoutService(this.env,this.env.CHECKOUT_PRINCIPAL_ID).prepare(input);}
}
export class MembershipCheckoutReader extends WorkerEntrypoint {
  fetch(){return hidden();}
  read(input){return new MembershipCheckoutService(this.env,this.env.CHECKOUT_READ_PRINCIPAL_ID).read(input);}
}
