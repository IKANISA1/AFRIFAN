import {WorkerEntrypoint} from 'cloudflare:workers';
import {PaymentAllocationService} from './service.mjs';
import {AllocationOutbox} from './outbox.mjs';
// Fixed principal identities come from deployment configuration, not RPC arguments.
// Binding possession is privileged. No public caller can supply an authority token here.
const hidden=()=>new Response('Not found',{status:404,headers:{'cache-control':'no-store'}});
export default {fetch:hidden};
export class PaymentEvidenceIngestor extends WorkerEntrypoint {
 fetch(){return hidden();}
 ingest(input){return new PaymentAllocationService(this.env,this.env.INGEST_PRINCIPAL_ID).ingest(input);}
}
export class PaymentAllocator extends WorkerEntrypoint {
 fetch(){return hidden();}
 allocate(input){return new PaymentAllocationService(this.env,this.env.ALLOCATE_PRINCIPAL_ID).allocate(input);}
}
export class PaymentReceiptReader extends WorkerEntrypoint {
 fetch(){return hidden();}
 readReceipt(input){return new PaymentAllocationService(this.env,this.env.READ_PRINCIPAL_ID).readReceipt(input);}
}
export class PaymentAllocationOutbox extends WorkerEntrypoint {
 fetch(){return hidden();}
 claim(input){return new AllocationOutbox(this.env,this.env.OUTBOX_PRINCIPAL_ID).claim(input);}
 acknowledge(input){return new AllocationOutbox(this.env,this.env.OUTBOX_PRINCIPAL_ID).acknowledge(input);}
}
