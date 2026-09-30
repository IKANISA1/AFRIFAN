import {WorkerEntrypoint} from 'cloudflare:workers';
import {AllocationInbox} from './inbox.mjs';
import {rpcOperation} from '../../shared-telemetry/entrypoints.mjs';
const hidden=()=>new Response('Not found',{status:404,headers:{'cache-control':'no-store'}});
export default {fetch:hidden};
export class AllocationEventInbox extends WorkerEntrypoint {
 fetch(){return hidden();}
 accept(input){return rpcOperation(this,{service:'allocation_delivery',operation:'delivery_accept',mutating:true},input,()=>new AllocationInbox(this.env).accept(input));}
}
// This binding exposes private user/order IDs. Bind it ONLY to an authorized operations adapter.
export class AllocationInboxReader extends WorkerEntrypoint {
 fetch(){return hidden();}
 list(input){return rpcOperation(this,{service:'allocation_delivery',operation:'delivery_inspection'},input,()=>new AllocationInbox(this.env).list(input));}
}
