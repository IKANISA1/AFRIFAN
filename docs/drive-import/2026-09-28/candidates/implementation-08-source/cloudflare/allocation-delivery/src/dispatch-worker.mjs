import {WorkerEntrypoint} from 'cloudflare:workers';
import {drain} from './dispatcher.mjs';
const hidden=()=>new Response('Not found',{status:404,headers:{'cache-control':'no-store'}});
export default {
 fetch:hidden,
 async scheduled(_event,env){
  const result=await drain(env);
  if(result.unknown||result.unavailableClubs)throw new Error('allocation_delivery_incomplete');
 }
};
export class AllocationDeliveryRunner extends WorkerEntrypoint {
 fetch(){return hidden();}
 run(){return drain(this.env);}
}
