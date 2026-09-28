import {WorkerEntrypoint} from 'cloudflare:workers';
import {DeliverySource} from './source.mjs';
const hidden=()=>new Response('Not found',{status:404,headers:{'cache-control':'no-store'}});
export default {fetch:hidden};
export class AllocationEventSource extends WorkerEntrypoint {
 fetch(){return hidden();}
 take(input){return new DeliverySource(this.env,this.env.DELIVERY_PRINCIPAL_ID).take(input);}
 readForDispatch(input){return new DeliverySource(this.env,this.env.DELIVERY_PRINCIPAL_ID).readForDispatch(input);}
 finish(input){return new DeliverySource(this.env,this.env.DELIVERY_PRINCIPAL_ID).finish(input);}
}
export class AllocationDeliveryReview extends WorkerEntrypoint {
 fetch(){return hidden();}
 health(input){return new DeliverySource(this.env,this.env.DELIVERY_REVIEW_PRINCIPAL_ID).health(input);}
 inspect(input){return new DeliverySource(this.env,this.env.DELIVERY_REVIEW_PRINCIPAL_ID).inspect(input);}
 redrive(input){return new DeliverySource(this.env,this.env.DELIVERY_REVIEW_PRINCIPAL_ID).redrive(input);}
}
