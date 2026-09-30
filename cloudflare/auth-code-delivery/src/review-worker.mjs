import {WorkerEntrypoint} from 'cloudflare:workers';
import {AuthenticationDispatchReview} from './review.mjs';
const hidden=()=>new Response('Not found',{status:404,headers:{'cache-control':'no-store'}});
export default {fetch:hidden};
export class AuthenticationDispatchReviewReader extends WorkerEntrypoint {
 fetch(){return hidden();}
 async health(input){try{return await new AuthenticationDispatchReview(this.env,{ctx:this.ctx}).health(input);}catch{throw new Error('dispatch_review_unavailable');}}
 async inspect(input){try{return await new AuthenticationDispatchReview(this.env,{ctx:this.ctx}).inspect(input);}catch{throw new Error('dispatch_review_unavailable');}}
}
