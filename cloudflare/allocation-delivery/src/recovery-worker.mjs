import {WorkerEntrypoint} from 'cloudflare:workers';
import {DeliveryRecovery} from './recovery.mjs';
import {rpcOperation} from '../../shared-telemetry/entrypoints.mjs';
const hidden=()=>new Response('Not found',{status:404,headers:{'cache-control':'no-store'}});
export default {fetch:hidden};
// These identities are fixed by separate trusted binding entrypoints, never selected in request bodies.
export class AllocationRecoveryMaker extends WorkerEntrypoint {
 fetch(){return hidden();}
 inspectEvent(input){return rpcOperation(this,{service:'allocation_delivery',operation:'delivery_inspection'},input,()=>new DeliveryRecovery(this.env,this.env.RECOVERY_MAKER_PRINCIPAL_ID,{ctx:this.ctx,observe:false}).inspectEvent(input));}
 prepare(input){return rpcOperation(this,{service:'allocation_delivery',operation:'delivery_prepare',mutating:true},input,()=>new DeliveryRecovery(this.env,this.env.RECOVERY_MAKER_PRINCIPAL_ID,{ctx:this.ctx,observe:false}).prepare(input));}
 decision(input){return rpcOperation(this,{service:'allocation_delivery',operation:'delivery_inspection'},input,()=>new DeliveryRecovery(this.env,this.env.RECOVERY_MAKER_PRINCIPAL_ID,{ctx:this.ctx,observe:false}).decision(input));}
}
export class AllocationRecoveryChecker extends WorkerEntrypoint {
 fetch(){return hidden();}
 inspectEvent(input){return rpcOperation(this,{service:'allocation_delivery',operation:'delivery_inspection'},input,()=>new DeliveryRecovery(this.env,this.env.RECOVERY_CHECKER_PRINCIPAL_ID,{ctx:this.ctx,observe:false}).inspectEvent(input));}
 decision(input){return rpcOperation(this,{service:'allocation_delivery',operation:'delivery_inspection'},input,()=>new DeliveryRecovery(this.env,this.env.RECOVERY_CHECKER_PRINCIPAL_ID,{ctx:this.ctx,observe:false}).decision(input));}
 confirm(input){return rpcOperation(this,{service:'allocation_delivery',operation:'delivery_confirm',mutating:true},input,()=>new DeliveryRecovery(this.env,this.env.RECOVERY_CHECKER_PRINCIPAL_ID,{ctx:this.ctx,observe:false}).confirm(input));}
}
