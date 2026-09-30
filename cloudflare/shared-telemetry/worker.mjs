import {WorkerEntrypoint} from 'cloudflare:workers';import {PrivateMetricsStore} from './sink.mjs';
const hidden=()=>new Response('Not found',{status:404,headers:{'cache-control':'no-store'}});
export default {fetch:hidden};
export class PrivateServiceMetrics extends WorkerEntrypoint {fetch(){return hidden();}record(input){return new PrivateMetricsStore(this.env).record(input);}}
export class PrivateMetricsTraceReader extends WorkerEntrypoint {fetch(){return hidden();}readTrace(input){return new PrivateMetricsStore(this.env).readTrace(input);}}
export class PrivateMetricsRetention extends WorkerEntrypoint {fetch(){return hidden();}expire(input){return new PrivateMetricsStore(this.env).expire(input);}}
