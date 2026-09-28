/** Trusted-server RPC adapter only. Do not expose this binding or chosen userId
 * directly to a browser/supporter. It neither stores credentials nor dials USSD. */
export type PrepareRequest={requestId:string;clubId:number;userId:string;tier:string};
export type ReadRequest={clubId:number;userId:string;orderId:string};
export type CheckoutSnapshot={schemaVersion:1;orderId:string;intentId:string;userId:string;clubId:number;packageId:string;
 tier:string;amount:number;currency:string;country:string;provider:string;recipient:string;ussdCode:string;
 createdAt:number;expiresAt:number;paymentVerified:false;membershipActivated:false};
export type PreparedCheckout={schemaVersion:1;requestId:string;reused:boolean;checkout:CheckoutSnapshot};
export type CheckoutStatus={schemaVersion:1;checkout:CheckoutSnapshot;status:'pending_current'|'expired'|'cancelled'|'allocated'|'configuration_changed';
 mayPresentPaymentInstruction:boolean;paymentEvidenceAllocated:boolean;observedAt:number};
export type Preparer={prepare:(value:PrepareRequest)=>Promise<unknown>};
export type Reader={read:(value:ReadRequest)=>Promise<unknown>};
export class CheckoutOutcomeUnknown extends Error {constructor(){super('checkout_outcome_unknown');}}
const uuid=(v:unknown):v is string=>typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(v);
const object=(v:unknown):v is Record<string,unknown>=>v!==null&&typeof v==='object'&&!Array.isArray(v);
function need(v:unknown):asserts v {if(!v)throw Error('invalid_checkout_contract');}
function fields(v:unknown,keys:string[]):asserts v is Record<string,unknown>{need(object(v)&&Object.keys(v).length===keys.length&&keys.every(k=>Object.hasOwn(v,k)));}
function snapshot(v:unknown,clubId:number,userId:string):asserts v is CheckoutSnapshot{
 fields(v,['schemaVersion','orderId','intentId','userId','clubId','packageId','tier','amount','currency','country','provider','recipient','ussdCode','createdAt','expiresAt','paymentVerified','membershipActivated']);
 need(v.schemaVersion===1&&uuid(v.orderId)&&uuid(v.intentId)&&uuid(v.packageId)&&v.clubId===clubId&&v.userId===userId);
 need(typeof v.tier==='string'&&/^[a-z0-9][a-z0-9_-]{0,31}$/.test(v.tier)&&Number.isSafeInteger(v.amount)&&(v.amount as number)>0&&(v.amount as number)<=2147483647);
 need(typeof v.currency==='string'&&/^[A-Z]{3}$/.test(v.currency)&&typeof v.country==='string'&&/^[A-Z]{2}$/.test(v.country));
 need(typeof v.provider==='string'&&/^[a-z][a-z0-9_-]{0,63}$/.test(v.provider)&&typeof v.recipient==='string'&&/^[0-9]{3,32}$/.test(v.recipient));
 need(typeof v.ussdCode==='string'&&v.ussdCode.length<=128&&/^\*[0-9*]+#$/.test(v.ussdCode));
 need(Number.isSafeInteger(v.createdAt)&&(v.createdAt as number)>=0&&Number.isSafeInteger(v.expiresAt)&&(v.expiresAt as number)-(v.createdAt as number)===86400000);
 need(v.paymentVerified===false&&v.membershipActivated===false);
}
export class MembershipCheckoutClient{
 constructor(private readonly preparer:Preparer,private readonly reader:Reader,private readonly deadlineMs=5000){need(Number.isInteger(deadlineMs)&&deadlineMs>0&&deadlineMs<=15000);}
 async prepare(v:PrepareRequest):Promise<PreparedCheckout>{
  fields(v,['requestId','clubId','userId','tier']);need(uuid(v.requestId)&&uuid(v.userId)&&Number.isSafeInteger(v.clubId)&&v.clubId>0&&typeof v.tier==='string'&&/^[a-z0-9][a-z0-9_-]{0,31}$/.test(v.tier));
  let timer:ReturnType<typeof setTimeout>|undefined;
  try{
   const r=await Promise.race([this.preparer.prepare({...v}),new Promise<never>((_,reject)=>{timer=setTimeout(()=>reject(new CheckoutOutcomeUnknown()),this.deadlineMs);})]);
   fields(r,['schemaVersion','requestId','reused','checkout']);need(r.schemaVersion===1&&r.requestId===v.requestId&&typeof r.reused==='boolean');snapshot(r.checkout,v.clubId,v.userId);need(r.checkout.tier===v.tier);
   return r as unknown as PreparedCheckout;
  }catch(error){
   // Once a write was invoked, an unrecognized error or malformed response may
   // follow a committed checkout. Preserve the original request key for recovery.
   const code=object(error)?error.code:null;
   if(typeof code==='string'&&['idempotency_conflict','checkout_permission_denied','checkout_rate_limited','checkout_offer_changed','checkout_disabled','staging_only','invalid_request','invalid_payment_route'].includes(code))throw error;
   throw new CheckoutOutcomeUnknown();
  }finally{clearTimeout(timer);}
 }
 async read(v:ReadRequest):Promise<CheckoutStatus>{
  fields(v,['clubId','userId','orderId']);need(uuid(v.userId)&&uuid(v.orderId)&&Number.isSafeInteger(v.clubId)&&v.clubId>0);
  let timer:ReturnType<typeof setTimeout>|undefined;
  let r:unknown;
  try{r=await Promise.race([this.reader.read({...v}),new Promise<never>((_,reject)=>{
   timer=setTimeout(()=>reject(new Error('checkout_read_unavailable')),this.deadlineMs);
  })]);}finally{clearTimeout(timer);}
  fields(r,['schemaVersion','checkout','status','mayPresentPaymentInstruction','paymentEvidenceAllocated','observedAt']);
  need(r.schemaVersion===1);snapshot(r.checkout,v.clubId,v.userId);need(r.checkout.orderId===v.orderId);
  need(['pending_current','expired','cancelled','allocated','configuration_changed'].includes(String(r.status)));
  need(r.mayPresentPaymentInstruction===(r.status==='pending_current')&&r.paymentEvidenceAllocated===(r.status==='allocated')&&Number.isSafeInteger(r.observedAt)&&(r.observedAt as number)>=0);
  if(r.status==='pending_current')need((r.observedAt as number)<r.checkout.expiresAt);
  return r as unknown as CheckoutStatus;
 }
}
