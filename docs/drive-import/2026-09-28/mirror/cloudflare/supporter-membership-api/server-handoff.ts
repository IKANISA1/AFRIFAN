import {MembershipApiClient, type Session, type RecoveryStore} from './client.js';
import {PaymentHandoffCoordinator, PaymentHandoffError, type NativeDialer, type PaymentReview, type HandoffSafetyGuard} from './payment-handoff.js';

function canonical(value:unknown):string {
 if(Array.isArray(value))return `[${value.map(canonical).join(',')}]`;
 if(value!==null&&typeof value==='object')return `{${Object.keys(value).sort().map(k=>`${JSON.stringify(k)}:${canonical((value as Record<string,unknown>)[k])}`).join(',')}}`;
 return JSON.stringify(value);
}
export async function handoffReviewHash(q:PaymentReview):Promise<string>{
 const bytes=new TextEncoder().encode(canonical({purpose:'africlub-handoff-review-v1',clubId:q.clubId,orderId:q.orderId,tier:q.tier,expiresAt:q.expiresAt,...q.instruction}));
 return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),x=>x.toString(16).padStart(2,'0')).join('');
}
export class RequiredServerHandoffGuard implements HandoffSafetyGuard {
 constructor(private readonly api:MembershipApiClient){}
 async recover(actor:Session){return this.api.activeHandoff(actor);}
 async beforeReview(actor:Session):Promise<void>{
  const value=await this.api.activeHandoff(actor);
  if(value.blocked)throw new PaymentHandoffError('unresolved_server_handoff','unknown');
 }
 async reserve(actor:Session,q:PaymentReview,attemptId:string):Promise<number>{
  const value=await this.api.reserveHandoff(actor,attemptId,q.orderId,await handoffReviewHash(q));
  if(!value.firstDelivery||!value.mayInvokeDialer||value.validForMs<=0)
    throw new PaymentHandoffError('server_handoff_not_granted','unknown');
  return value.validForMs;
 }
}
/** New composition only: required server guard + existing local encrypted-store protocol.
 * No fallback to the legacy local-only path when remote recovery is unavailable. */
export function serverBackedHandoff(api:MembershipApiClient,store:RecoveryStore,dialer:NativeDialer,
 options:{enabled?:boolean;monotonicNow?:()=>number;timeoutMs?:number}={}):PaymentHandoffCoordinator{
 return new PaymentHandoffCoordinator(api,store,dialer,options.monotonicNow,options.timeoutMs??10000,
   options.enabled===true,new RequiredServerHandoffGuard(api));
}
