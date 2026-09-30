import {WorkerEntrypoint} from 'cloudflare:workers';
import {DeliverySource} from './source.mjs';
import {rpcOperation} from '../../shared-telemetry/entrypoints.mjs';
const hidden=()=>new Response('Not found',{status:404,headers:{'cache-control':'no-store'}});
export default {fetch:hidden};
export class AllocationEventSource extends WorkerEntrypoint {
 fetch(){return hidden();}
 take(input){return rpcOperation(this,{service:'allocation_delivery',operation:'delivery_claim',mutating:true},input,()=>new DeliverySource(this.env,this.env.DELIVERY_PRINCIPAL_ID).take(input));}
 readForDispatch(input){return rpcOperation(this,{service:'allocation_delivery',operation:'delivery_read'},input,()=>new DeliverySource(this.env,this.env.DELIVERY_PRINCIPAL_ID).readForDispatch(input));}
 finish(input){return rpcOperation(this,{service:'allocation_delivery',operation:'delivery_acknowledge',mutating:true},input,()=>new DeliverySource(this.env,this.env.DELIVERY_PRINCIPAL_ID).finish(input));}
}
export class AllocationDeliveryReview extends WorkerEntrypoint {
 fetch(){return hidden();}
 health(input){return rpcOperation(this,{service:'allocation_delivery',operation:'queue_health'},input,()=>new DeliverySource(this.env,this.env.DELIVERY_REVIEW_PRINCIPAL_ID,{ctx:this.ctx}).health(input));}
 inspect(input){return rpcOperation(this,{service:'allocation_delivery',operation:'delivery_inspection'},input,()=>new DeliverySource(this.env,this.env.DELIVERY_REVIEW_PRINCIPAL_ID).inspect(input));}
 redrive(input){return rpcOperation(this,{service:'allocation_delivery',operation:'delivery_redrive',mutating:true},input,()=>new DeliverySource(this.env,this.env.DELIVERY_REVIEW_PRINCIPAL_ID).redrive(input));}
}
