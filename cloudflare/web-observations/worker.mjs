import {WorkerEntrypoint} from 'cloudflare:workers';
import {PrivateWebObservationStore,runWebObservationRetention} from './sink.mjs';
const hidden=()=>new Response('Not found',{status:404,headers:{'cache-control':'no-store'}});
export default {fetch:hidden,async scheduled(_controller,env){await runWebObservationRetention(env);}};
export class PrivateWebObservations extends WorkerEntrypoint {
 fetch(){return hidden();} record(input){return new PrivateWebObservationStore(this.env).record(input);}
}
export class PrivateWebObservationsRetention extends WorkerEntrypoint {
 fetch(){return hidden();} expire(input){return new PrivateWebObservationStore(this.env).expire(input);}
}
