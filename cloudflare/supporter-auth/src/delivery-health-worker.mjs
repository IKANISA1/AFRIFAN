import {WorkerEntrypoint} from 'cloudflare:workers';
import {readDeliveryHealth} from './delivery-health.mjs';
const hidden = () => new Response('Not found', {status: 404, headers: {'cache-control': 'no-store'}});
export default {fetch: hidden};
export class OtpQueueHealthReader extends WorkerEntrypoint {
  fetch() {return hidden();}
  read(input = {}) {return readDeliveryHealth(this.env, input);}
}
