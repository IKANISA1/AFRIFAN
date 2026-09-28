import {WorkerEntrypoint} from 'cloudflare:workers';
import {AuthenticationCodeDeliveryService} from './service.mjs';
export class AuthenticationCodeDelivery extends WorkerEntrypoint {
  async deliver(input) {
    try{return await new AuthenticationCodeDeliveryService(this.env).deliver(input);}
    catch{throw new Error('delivery_unavailable');}
  }
  async deliverWithReceipt(input) {
    try{return await new AuthenticationCodeDeliveryService(this.env).deliverWithReceipt(input);}
    catch{throw new Error('delivery_unavailable');}
  }
  async fetch(){return new Response('Not found',{status:404,headers:{'cache-control':'no-store'}});}
}
export default {async fetch(){return new Response('Not found',{status:404,headers:{'cache-control':'no-store'}});}};
