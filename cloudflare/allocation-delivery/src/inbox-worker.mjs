import {WorkerEntrypoint} from 'cloudflare:workers';
import {AllocationInbox} from './inbox.mjs';
const hidden=()=>new Response('Not found',{status:404,headers:{'cache-control':'no-store'}});
export default {fetch:hidden};
export class AllocationEventInbox extends WorkerEntrypoint {
 fetch(){return hidden();}
 accept(input){return new AllocationInbox(this.env).accept(input);}
}
// This binding exposes private user/order IDs. Bind it ONLY to an authorized operations adapter.
export class AllocationInboxReader extends WorkerEntrypoint {
 fetch(){return hidden();}
 list(input){return new AllocationInbox(this.env).list(input);}
}
