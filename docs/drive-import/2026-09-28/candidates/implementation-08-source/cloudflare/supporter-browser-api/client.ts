export interface MembershipOffer {tier:string;amount:number;currency:string;country:string}
export interface MembershipOffers {schemaVersion:1;clubId:number;observedAt:number;offers:MembershipOffer[];preparationOnly:true}
export interface HistoricalReceipt {schemaVersion:1;clubId:number;orderId:string;allocationId:string;amount:number;currency:string;
 recordedAt:number;allocationPersisted:true;businessTargetFulfilled:true;historical:true;
 membershipAtAllocation:{id:string;tier:string;status:'active'|'suspended'|'expired';paymentStatus:'verified';expiresAt:number}}
/** Browser-only client. HttpOnly cookies remain browser-managed; no native bearer fallback.
 * All state-changing methods are explicit. Constructors/restoration never issue writes.
 */
export type Transport = (input: string, init: RequestInit) => Promise<Response>;
export interface RecoveryStore {
 getItem(key: string): string | null;
 setItem(key: string, value: string): void;
 removeItem(key: string): void;
 withLock<T>(key: string, action: () => Promise<T>): Promise<T>;
}
export interface BrowserSession {
 schemaVersion: 1; clubId: number; userId: string; sessionId: string;
 authenticatedAt: number; expiresAt: number; absoluteExpiresAt: number;
 role: 'supporter'; phoneVerified: true; csrfToken: string;
}
export interface Bootstrap {schemaVersion: 1;clubId: number;csrfToken: string;expiresAt: number;}
export interface Challenge {schemaVersion: 1;clubId: number;challengeId: string;expiresAt: number;delivery: 'queued_or_pending';}
export interface PreparedCheckout {
 schemaVersion: 1;clubId: number;requestId: string;orderId: string;tier: string;reused: boolean;
 paymentVerified: false;membershipActivated: false;
}
export interface CurrentMembership {
 schemaVersion: 1;clubId: number;userId: string;observedAt: number;historical: false;
 currentStatus: 'not_member' | 'active' | 'suspended' | 'expired' | 'pending' | 'incomplete';isActive: boolean;
 membership: null | {membershipId: string;tier: string;recordedStatus: 'active'|'suspended'|'expired';
  paymentStatus: 'pending'|'verified';renewedAt: number|null;expiresAt: number|null;};
}
export interface CheckoutLookup {
 schemaVersion: 1;clubId: number;requestId: string;observedAt: number;found: boolean;
 mayRetryWithNewKey: false;result: PreparedCheckout|null;
}
export interface CurrentCheckout {
 schemaVersion: 1;clubId: number;orderId: string;tier: string;
 status: 'pending_current'|'expired'|'cancelled'|'allocated'|'configuration_changed';
 paymentEvidenceAllocated: boolean;observedAt: number;expiresAt: number;
 paymentInstruction: null|{amount: number;currency: string;country: string;provider: string;recipient: string;ussdCode: string;};
}
type Pending = {version:1;origin:string;clubId:number;userId:string;requestId:string;tier:string;savedAt:number;};
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const TIER=/^[a-z0-9][a-z0-9_-]{0,31}$/;
const HEX=/^[0-9a-f]{64}$/;
const stamp=(v:unknown):v is number=>Number.isSafeInteger(v)&&Number(v)>=0&&Number(v)<=253402300799999;
const obj=(v:unknown):v is Record<string,unknown>=>!!v&&typeof v==='object'&&!Array.isArray(v);
const fields=(v:unknown,names:string[]):v is Record<string,unknown>=>obj(v)&&names.length===Object.keys(v).length&&names.every(n=>Object.hasOwn(v,n));
const uuid=(v:unknown):v is string=>typeof v==='string'&&UUID.test(v);
const tier=(v:unknown):v is string=>typeof v==='string'&&TIER.test(v);
export class BrowserClientError extends Error {
 constructor(public code:string,public status=0,public outcomeUnknown=false,public requestId:string|null=null){super(code);}
}
function need(value:unknown,code='invalid_request'):asserts value {if(!value)throw new BrowserClientError(code);}
/** Use with an approved same-origin operational-metadata store and Web Locks.
 * Stored records contain operation IDs and actor scope, never phone/code/credentials.
 */
export function createBrowserRecoveryStore(storage:Pick<Storage,'getItem'|'setItem'|'removeItem'>,locks:LockManager):RecoveryStore {
 need(storage&&locks&&typeof locks.request==='function','recovery_store_required');
 return {getItem:k=>storage.getItem(k),setItem:(k,v)=>storage.setItem(k,v),removeItem:k=>storage.removeItem(k),
  withLock:<T>(k:string,fn:()=>Promise<T>)=>locks.request(k,{mode:'exclusive'},fn)};
}
export class BrowserMemberClient {
 private current:BrowserSession|null=null;
 private bootstrap:Bootstrap|null=null;
 private busy=false;
 private transport:Transport;
 private clock:()=>number;
 private timeoutMs:number;
 private store?:RecoveryStore;
 private rememberLast=false;
 constructor(readonly origin:string,readonly clubId:number,options:{fetch?:Transport;clock?:()=>number;timeoutMs?:number;recoveryStore?:RecoveryStore;rememberLastCheckout?:boolean}={}){
  let url:URL;try{url=new URL(origin);}catch{throw new BrowserClientError('invalid_origin');}
  need(url.protocol==='https:'&&url.origin===origin&&!url.username&&!url.password,'invalid_origin');
  need(Number.isSafeInteger(clubId)&&clubId>0);
  this.transport=options.fetch??((u,i)=>fetch(u,i));this.clock=options.clock??Date.now;
  this.timeoutMs=options.timeoutMs??10000;need(Number.isInteger(this.timeoutMs)&&this.timeoutMs>0&&this.timeoutMs<=30000);
  this.store=options.recoveryStore;this.rememberLast=options.rememberLastCheckout===true;
 }
 private async single<T>(action:()=>Promise<T>):Promise<T>{
  need(!this.busy,'operation_in_progress');this.busy=true;
  try{return await action();}finally{this.busy=false;}
 }
 private async request(path:string,{input,key,csrf,actor,historyCursor}:{input?:unknown;key?:string;csrf?:string;actor?:BrowserSession;historyCursor?:string|null}={}):Promise<unknown>{
  if(key)need(uuid(key));const write=input!==undefined;
  const headers:Record<string,string>={'x-africlub-browser-intent':'browser-v1'};
  if(write)headers['content-type']='application/json';if(key)headers['idempotency-key']=key;
  if(historyCursor)headers['x-africlub-history-cursor']=historyCursor;
  if(csrf)headers['x-africlub-csrf']=csrf;if(actor)headers['x-africlub-browser-session']=actor.sessionId;
  const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),this.timeoutMs);
  try{
   const r=await this.transport(this.origin+'/v1/browser/'+path,{method:write?'POST':'GET',headers,
    credentials:'same-origin',redirect:'error',cache:'no-store',signal:controller.signal,
    ...(write?{body:JSON.stringify(input)}:{})});
   need((r.headers.get('content-type')??'').includes('application/json'),'invalid_response');
   const reader=r.body?.getReader();need(reader,'invalid_response');let total=0;const chunks:Uint8Array[]=[];
   try{for(;;){const {value,done}=await reader.read();if(done)break;total+=value.length;need(total<=65536,'invalid_response');chunks.push(value);}}
   finally{void reader.cancel().catch(()=>{});}
   const bytes=new Uint8Array(total);let offset=0;for(const a of chunks){bytes.set(a,offset);offset+=a.length;}
   let data:unknown;try{data=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));}catch{throw new BrowserClientError('invalid_response');}
   if(!r.ok){
    const code=obj(data)&&typeof data.error==='string'&&/^[a-z_]{1,64}$/.test(data.error)?data.error:'request_failed';
    throw new BrowserClientError(code,r.status,write&&(r.status>=500||path==='membership/checkouts'||(obj(data)&&data.outcome==='unknown')),key??null);
   }
   return data;
  }catch(e){
   if(e instanceof BrowserClientError){if(write&&e.code==='invalid_response')throw new BrowserClientError(e.code,e.status,true,key??null);throw e;}
   throw new BrowserClientError('transport_unavailable',0,write,key??null);
  }finally{clearTimeout(timer);}
 }
 private session(v:unknown):BrowserSession {
  need(fields(v,['schemaVersion','clubId','userId','sessionId','authenticatedAt','expiresAt','absoluteExpiresAt','role','phoneVerified','csrfToken'])&&
   v.schemaVersion===1&&v.clubId===this.clubId&&uuid(v.userId)&&uuid(v.sessionId)&&v.role==='supporter'&&v.phoneVerified===true&&
   stamp(v.authenticatedAt)&&v.authenticatedAt<=this.clock()&&stamp(v.expiresAt)&&v.expiresAt>this.clock()&&
   stamp(v.absoluteExpiresAt)&&v.absoluteExpiresAt>=v.expiresAt&&typeof v.csrfToken==='string'&&HEX.test(v.csrfToken),'invalid_response');
  return Object.freeze({...v}) as unknown as BrowserSession;
 }
 private boot(v:unknown):Bootstrap {
  need(fields(v,['schemaVersion','clubId','csrfToken','expiresAt'])&&v.schemaVersion===1&&v.clubId===this.clubId&&
   typeof v.csrfToken==='string'&&HEX.test(v.csrfToken)&&stamp(v.expiresAt)&&v.expiresAt>this.clock()&&v.expiresAt<=this.clock()+600000,'invalid_response');
  return Object.freeze({...v}) as unknown as Bootstrap;
 }
 private actor():BrowserSession {need(this.current&&this.current.expiresAt>this.clock(),'session_required');return this.current;}
 private sameActor(a:BrowserSession){need(this.current?.userId===a.userId&&this.current?.sessionId===a.sessionId,'session_changed');}
 private prepared(v:unknown,key:string,expectedTier?:string):PreparedCheckout {
  need(fields(v,['schemaVersion','clubId','requestId','orderId','tier','reused','paymentVerified','membershipActivated'])&&
   v.schemaVersion===1&&v.clubId===this.clubId&&v.requestId===key&&uuid(v.orderId)&&tier(v.tier)&&
   (expectedTier===undefined||v.tier===expectedTier)&&typeof v.reused==='boolean'&&v.paymentVerified===false&&v.membershipActivated===false,'invalid_response');
  return Object.freeze({...v}) as unknown as PreparedCheckout;
 }
 private async validatedWrite<T>(key:string,fn:()=>Promise<T>):Promise<T>{
  try{return await fn();}catch(e){if(e instanceof BrowserClientError&&['invalid_response','session_changed'].includes(e.code))
   throw new BrowserClientError(e.code,e.status,true,key);throw e;}
 }
 async start():Promise<Bootstrap>{return this.single(async()=>{const b=this.boot(await this.request('session/start',{input:{}}));this.bootstrap=b;return b;});}
 async restoreBootstrap():Promise<Bootstrap>{const b=this.boot(await this.request('session/bootstrap'));this.bootstrap=b;return b;}
 async challenge(phone:string,requestId:string):Promise<Challenge>{
  need(typeof phone==='string'&&/^\+[1-9][0-9]{7,14}$/.test(phone)&&uuid(requestId));
  need(this.bootstrap&&this.bootstrap.expiresAt>this.clock(),'bootstrap_required');const csrf=this.bootstrap.csrfToken;
  return this.single(()=>this.validatedWrite(requestId,async()=>{
   const v=await this.request('session/challenge',{input:{phone},key:requestId,csrf});
   need(fields(v,['schemaVersion','clubId','challengeId','expiresAt','delivery'])&&v.schemaVersion===1&&v.clubId===this.clubId&&
    uuid(v.challengeId)&&stamp(v.expiresAt)&&v.expiresAt>this.clock()&&v.delivery==='queued_or_pending','invalid_response');
   return Object.freeze({...v}) as unknown as Challenge;
  }));
 }
 async verify(challengeId:string,code:string,requestId:string):Promise<BrowserSession>{
  need(uuid(challengeId)&&uuid(requestId)&&/^[0-9]{6}$/.test(code));need(this.bootstrap,'bootstrap_required');const csrf=this.bootstrap.csrfToken;
  return this.single(()=>this.validatedWrite(requestId,async()=>{const s=this.session(await this.request('session/verify',{
   input:{challengeId,code},key:requestId,csrf}));this.current=s;return s;}));
 }
 async restore():Promise<BrowserSession>{
  try{const s=this.session(await this.request('session'));this.current=s;return s;}
  catch(e){this.current=null;throw e;}
 }
 async rotate(requestId:string):Promise<BrowserSession>{
  need(uuid(requestId));const actor=this.actor();
  return this.single(()=>this.validatedWrite(requestId,async()=>{const s=this.session(await this.request('session/rotate',{
   input:{},key:requestId,csrf:actor.csrfToken}));need(s.userId===actor.userId&&s.sessionId===actor.sessionId,'invalid_response');this.current=s;return s;}));
 }
 async logout(requestId:string):Promise<void>{
  need(uuid(requestId));const actor=this.actor();
  return this.single(()=>this.validatedWrite(requestId,async()=>{const v=await this.request('session/logout',{input:{},key:requestId,csrf:actor.csrfToken});
   need(fields(v,['schemaVersion','loggedOut','scope'])&&v.schemaVersion===1&&v.loggedOut===true&&v.scope==='current','invalid_response');
   this.current=null;this.bootstrap=null; // Unresolved checkout metadata is NOT silently deleted.
  }));
 }
 async history(cursor:string|null=null):Promise<MembershipHistoryPage>{
  const actor=this.actor();historyCursor(cursor,actor);const value=await this.request('membership/history',{actor,historyCursor:cursor});this.sameActor(actor);
  const page=parseMemberHistory(value,actor,cursor);need(page.observedAt>=this.clock()-10000&&page.observedAt<=this.clock()+1000,'invalid_response');return page;
 }
 async historicalReceipt(orderId:string):Promise<HistoricalReceipt>{
  need(uuid(orderId));const actor=this.actor(),value=await this.request(`membership/history/${orderId}`,{actor});this.sameActor(actor);
  const result=parseMemberHistoryReceipt(value,actor,orderId);const observed=(value as {observedAt:number}).observedAt;
  need(observed>=this.clock()-10000&&observed<=this.clock()+1000,'invalid_response');return result;
 }
 async membershipStatus():Promise<CurrentMembership>{
  const a=this.actor(),v=await this.request('membership/status',{actor:a});this.sameActor(a);
  need(fields(v,['schemaVersion','clubId','userId','observedAt','currentStatus','isActive','membership','historical'])&&
   v.schemaVersion===1&&v.clubId===a.clubId&&v.userId===a.userId&&v.historical===false&&stamp(v.observedAt)&&
   v.observedAt>=this.clock()-10000&&v.observedAt<=this.clock()+1000&&
   ['not_member','active','suspended','expired','pending','incomplete'].includes(String(v.currentStatus))&&
   v.isActive===(v.currentStatus==='active'),'invalid_response');
  if(v.membership===null)need(v.currentStatus==='not_member','invalid_response');
  else{
   const m=v.membership;need(fields(m,['membershipId','tier','recordedStatus','paymentStatus','renewedAt','expiresAt'])&&uuid(m.membershipId)&&tier(m.tier)&&
    ['active','suspended','expired'].includes(String(m.recordedStatus))&&['pending','verified'].includes(String(m.paymentStatus))&&
    (m.renewedAt===null||stamp(m.renewedAt))&&(m.expiresAt===null||stamp(m.expiresAt)),'invalid_response');
   const state=m.recordedStatus==='suspended'?'suspended':m.recordedStatus==='expired'||(typeof m.expiresAt==='number'&&m.expiresAt<=this.clock())?'expired':
    m.paymentStatus!=='verified'?'pending':m.renewedAt===null||m.expiresAt===null||Number(m.renewedAt)>Number(v.observedAt)||Number(m.expiresAt)<=Number(m.renewedAt)?'incomplete':'active';
   // Locally expire an observation that was active on the server just before response transit.
   need(v.currentStatus===state||(v.currentStatus==='active'&&state==='expired'),'invalid_response');
   v.currentStatus=state;v.isActive=state==='active';
  }
  return v as unknown as CurrentMembership;
 }
 private storageKey(a:BrowserSession){return `africlub-browser-checkout:v1:${this.origin}:${a.clubId}:${a.userId}`;}
 private pending(a:BrowserSession):Pending|null {
  need(this.store,'recovery_store_required');let raw:string|null;
  try{raw=this.store.getItem(this.storageKey(a));}catch{throw new BrowserClientError('recovery_store_unavailable');}
  if(raw===null)return null;need(typeof raw==='string'&&raw.length<=2048,'recovery_store_corrupt');
  let v:unknown;try{v=JSON.parse(raw);}catch{throw new BrowserClientError('recovery_store_corrupt');}
  need(fields(v,['version','origin','clubId','userId','requestId','tier','savedAt'])&&v.version===1&&v.origin===this.origin&&
   v.clubId===a.clubId&&v.userId===a.userId&&uuid(v.requestId)&&tier(v.tier)&&stamp(v.savedAt),'recovery_store_corrupt');
  return v as unknown as Pending;
 }
 private lastKey(a:BrowserSession){return `africlub-browser-checkout-last:v1:${this.origin}:${a.clubId}:${a.userId}`;}
 private remember(a:BrowserSession,v:PreparedCheckout){
  if(!this.rememberLast)return;need(this.store,'recovery_store_required');
  const text=JSON.stringify({version:1,origin:this.origin,clubId:a.clubId,userId:a.userId,requestId:v.requestId,orderId:v.orderId,tier:v.tier});
  this.store.setItem(this.lastKey(a),text);need(this.store.getItem(this.lastKey(a))===text,'recovery_store_unavailable');
 }
 /** Optional UI handover: metadata persisted BEFORE the uncertain-operation record clears. */
 async lastPreparedCheckout():Promise<{orderId:string;tier:string}|null>{
  if(!this.rememberLast)return null;const a=this.actor();need(this.store,'recovery_store_required');
  let raw:string|null;try{raw=this.store.getItem(this.lastKey(a));}catch{throw new BrowserClientError('recovery_store_unavailable');}
  if(raw===null)return null;need(typeof raw==='string'&&raw.length<=2048,'recovery_store_corrupt');
  let v:unknown;try{v=JSON.parse(raw);}catch{throw new BrowserClientError('recovery_store_corrupt');}
  need(fields(v,['version','origin','clubId','userId','requestId','orderId','tier'])&&v.version===1&&v.origin===this.origin&&
   v.clubId===a.clubId&&v.userId===a.userId&&uuid(v.requestId)&&uuid(v.orderId)&&tier(v.tier),'recovery_store_corrupt');
  return {orderId:v.orderId,tier:v.tier};
 }
 async pendingCheckout():Promise<Readonly<Pending>|null>{const p=this.pending(this.actor());return p?Object.freeze({...p}):null;}
 async prepareCheckout(value:string,requestId:string):Promise<PreparedCheckout>{
  need(tier(value)&&uuid(requestId));need(this.store,'recovery_store_required');const a=this.actor(),store=this.store;
  return this.single(()=>store.withLock(this.storageKey(a),()=>this.validatedWrite(requestId,async()=>{
   this.sameActor(a);const old=this.pending(a);need(!old||(old.requestId===requestId&&old.tier===value),'pending_checkout');
   const p:Pending=old??{version:1,origin:this.origin,clubId:a.clubId,userId:a.userId,requestId,tier:value,savedAt:this.clock()};
   try{const serialized=JSON.stringify(p);store.setItem(this.storageKey(a),serialized);need(store.getItem(this.storageKey(a))===serialized,'recovery_store_unavailable');}
   catch{throw new BrowserClientError('recovery_store_unavailable');}
   const v=this.prepared(await this.request('membership/checkouts',{input:{tier:value},key:requestId,csrf:a.csrfToken,actor:a}),requestId,value);
   this.sameActor(a);
   try{this.remember(a,v);store.removeItem(this.storageKey(a));need(store.getItem(this.storageKey(a))===null,'recovery_store_unavailable');}
   catch{throw new BrowserClientError('recovery_store_unavailable',0,true,requestId);}
   return v;
  })));
 }
 async lookupCheckout(requestId:string):Promise<CheckoutLookup>{
  need(uuid(requestId));const a=this.actor(),v=await this.request('membership/operations/'+requestId,{actor:a});this.sameActor(a);
  need(fields(v,['schemaVersion','clubId','requestId','observedAt','found','mayRetryWithNewKey','result'])&&v.schemaVersion===1&&v.clubId===a.clubId&&
   v.requestId===requestId&&stamp(v.observedAt)&&v.observedAt>=this.clock()-10000&&v.observedAt<=this.clock()+1000&&
   typeof v.found==='boolean'&&v.mayRetryWithNewKey===false,'invalid_response');
  if(v.found)v.result=this.prepared(v.result,requestId);else need(v.result===null,'invalid_response');
  return v as unknown as CheckoutLookup;
 }
 async recoverCheckout():Promise<CheckoutLookup|null>{
  const a=this.actor();need(this.store,'recovery_store_required');const store=this.store;
  return store.withLock(this.storageKey(a),async()=>{
   const p=this.pending(a);if(!p)return null;const result=await this.lookupCheckout(p.requestId);
   if(result.found){need(result.result?.tier===p.tier,'invalid_response');this.sameActor(a);
    try{this.remember(a,result.result!);store.removeItem(this.storageKey(a));need(store.getItem(this.storageKey(a))===null,'recovery_store_unavailable');}
    catch{throw new BrowserClientError('recovery_store_unavailable');}}
   return result; // not observed leaves the original pending operation locked.
  });
 }
 async retryPendingCheckout():Promise<PreparedCheckout>{
  const p=this.pending(this.actor());need(p,'no_pending_checkout');return this.prepareCheckout(p.tier,p.requestId);
 }
 async checkout(orderId:string):Promise<CurrentCheckout>{
  need(uuid(orderId));const a=this.actor(),v=await this.request('membership/checkouts/'+orderId,{actor:a});this.sameActor(a);
  need(fields(v,['schemaVersion','clubId','orderId','tier','status','paymentEvidenceAllocated','observedAt','expiresAt','paymentInstruction'])&&
   v.schemaVersion===1&&v.clubId===a.clubId&&v.orderId===orderId&&tier(v.tier)&&stamp(v.observedAt)&&stamp(v.expiresAt)&&
   v.observedAt>=this.clock()-10000&&v.observedAt<=this.clock()+1000&&
   ['pending_current','expired','cancelled','allocated','configuration_changed'].includes(String(v.status))&&
   v.paymentEvidenceAllocated===(v.status==='allocated'),'invalid_response');
  if(v.status==='pending_current'){
   const p=v.paymentInstruction;need(fields(p,['amount','currency','country','provider','recipient','ussdCode'])&&
    Number.isSafeInteger(p.amount)&&Number(p.amount)>0&&typeof p.currency==='string'&&/^[A-Z]{3}$/.test(p.currency)&&
    typeof p.country==='string'&&/^[A-Z]{2}$/.test(p.country)&&typeof p.provider==='string'&&/^[a-z][a-z0-9_]{0,63}$/.test(p.provider)&&
    typeof p.recipient==='string'&&/^\+?[0-9]{3,15}$/.test(p.recipient)&&typeof p.ussdCode==='string'&&/^\*[0-9*]+#$/.test(p.ussdCode),'invalid_response');
   if(v.expiresAt<=this.clock()){v.status='expired';v.paymentInstruction=null;}
  }else need(v.paymentInstruction===null,'invalid_response');
  return v as unknown as CurrentCheckout;
 }
 async offers():Promise<MembershipOffers>{
  const a=this.actor(),v=await this.request('membership/offers',{actor:a});this.sameActor(a);
  need(fields(v,['schemaVersion','clubId','observedAt','offers','preparationOnly'])&&v.schemaVersion===1&&v.clubId===a.clubId&&
   v.preparationOnly===true&&stamp(v.observedAt)&&v.observedAt>=this.clock()-10000&&v.observedAt<=this.clock()+1000&&
   Array.isArray(v.offers)&&v.offers.length<=32,'invalid_response');
  const seen=new Set<string>();
  for(const o of v.offers as unknown[]){
   need(fields(o,['tier','amount','currency','country'])&&tier(o.tier)&&!seen.has(o.tier)&&Number.isSafeInteger(o.amount)&&
    Number(o.amount)>0&&Number(o.amount)<=2147483647&&typeof o.currency==='string'&&/^[A-Z]{3}$/.test(o.currency)&&
    typeof o.country==='string'&&/^[A-Z]{2}$/.test(o.country),'invalid_response');seen.add(o.tier);
  }
  return v as unknown as MembershipOffers;
 }
 async receipt(orderId:string):Promise<HistoricalReceipt>{
  need(uuid(orderId));const a=this.actor(),v=await this.request('membership/checkouts/'+orderId+'/receipt',{actor:a});this.sameActor(a);
  need(fields(v,['schemaVersion','clubId','orderId','allocationId','amount','currency','recordedAt','allocationPersisted',
   'businessTargetFulfilled','membershipAtAllocation','historical'])&&v.schemaVersion===1&&v.clubId===a.clubId&&v.orderId===orderId&&
   uuid(v.allocationId)&&Number.isSafeInteger(v.amount)&&Number(v.amount)>0&&Number(v.amount)<=2147483647&&
   typeof v.currency==='string'&&/^[A-Z]{3}$/.test(v.currency)&&stamp(v.recordedAt)&&v.recordedAt<=this.clock()+1000&&
   v.allocationPersisted===true&&v.businessTargetFulfilled===true&&v.historical===true,'invalid_response');
  const m=v.membershipAtAllocation;
  need(fields(m,['id','tier','status','paymentStatus','expiresAt'])&&uuid(m.id)&&tier(m.tier)&&
   ['active','suspended','expired'].includes(String(m.status))&&m.paymentStatus==='verified'&&stamp(m.expiresAt)&&
   m.expiresAt>Number(v.recordedAt),'invalid_response');
  return v as unknown as HistoricalReceipt;
 }

}

export type MembershipHistoryItem={orderId:string;allocationId:string;recordedAt:number;amount:number;currency:string};
export type MembershipHistoryPage={schemaVersion:1;clubId:number;userId:string;observedAt:number;scope:'membership_allocations';historical:true;snapshot:false;items:MembershipHistoryItem[];nextCursor:string|null};
function historyUuid(v:unknown):v is string{return typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.exec(v)?.[0]===v;}
function historyFields(v:unknown,keys:string[]):asserts v is Record<string,unknown>{need(v!==null&&typeof v==='object'&&!Array.isArray(v)&&Object.keys(v).length===keys.length&&keys.every(k=>Object.hasOwn(v,k)),'invalid_response');}
function historyTime(v:unknown):v is number{return typeof v==='number'&&Number.isSafeInteger(v)&&v>=0&&v<=253370764799999;}
function historyCursor(v:string|null,actor:{clubId:number;userId:string}):{recordedAt:number;allocationId:string}|null{
 if(v===null)return null;need(typeof v==='string'&&v.length<=160,'invalid_request');const p=v.split(':');
 need(p.length===5&&p[0]==='mh1'&&p[1]===String(actor.clubId)&&p[2]===actor.userId&&/^(0|[1-9][0-9]{0,14})$/.test(p[3])&&historyTime(Number(p[3]))&&historyUuid(p[4]),'invalid_request');
 return {recordedAt:Number(p[3]),allocationId:p[4]};
}
function parseMemberHistory(v:unknown,actor:{clubId:number;userId:string},cursor:string|null):MembershipHistoryPage{
 historyFields(v,['schemaVersion','clubId','userId','observedAt','scope','historical','snapshot','items','nextCursor']);
 need(v.schemaVersion===1&&v.clubId===actor.clubId&&v.userId===actor.userId&&historyTime(v.observedAt)&&v.scope==='membership_allocations'&&v.historical===true&&v.snapshot===false&&Array.isArray(v.items)&&v.items.length<=20,'invalid_response');
 let previous=historyCursor(cursor,actor);const orders=new Set<string>(),ids=new Set<string>();
 for(const row of v.items){historyFields(row,['orderId','allocationId','recordedAt','amount','currency']);
  need(historyUuid(row.orderId)&&historyUuid(row.allocationId)&&historyTime(row.recordedAt)&&row.recordedAt<=v.observedAt&&typeof row.amount==='number'&&Number.isInteger(row.amount)&&row.amount>0&&row.amount<=2147483647&&typeof row.currency==='string'&&row.currency.length===3&&/^[A-Z]{3}$/.test(row.currency),'invalid_response');
  need(!orders.has(row.orderId)&&!ids.has(row.allocationId)&&(!previous||row.recordedAt<previous.recordedAt||(row.recordedAt===previous.recordedAt&&row.allocationId<previous.allocationId)),'invalid_response');
  previous={recordedAt:row.recordedAt,allocationId:row.allocationId};orders.add(row.orderId);ids.add(row.allocationId);
 }
 need(v.nextCursor===null||(v.items.length===20&&previous&&v.nextCursor===`mh1:${actor.clubId}:${actor.userId}:${previous.recordedAt}:${previous.allocationId}`),'invalid_response');
 return v as unknown as MembershipHistoryPage;
}
function parseMemberHistoryReceipt(v:unknown,actor:{clubId:number;userId:string},orderId:string):HistoricalReceipt{
 historyFields(v,['schemaVersion','clubId','userId','observedAt','receipt']);need(v.schemaVersion===1&&v.clubId===actor.clubId&&v.userId===actor.userId&&historyTime(v.observedAt),'invalid_response');
 const r=v.receipt;historyFields(r,['schemaVersion','clubId','orderId','allocationId','amount','currency','recordedAt','allocationPersisted','businessTargetFulfilled','membershipAtAllocation','historical']);
 need(r.schemaVersion===1&&r.clubId===actor.clubId&&r.orderId===orderId&&historyUuid(r.allocationId)&&historyTime(r.recordedAt)&&r.recordedAt<=v.observedAt&&typeof r.amount==='number'&&Number.isInteger(r.amount)&&r.amount>0&&r.amount<=2147483647&&typeof r.currency==='string'&&r.currency.length===3&&/^[A-Z]{3}$/.test(r.currency)&&r.allocationPersisted===true&&r.businessTargetFulfilled===true&&r.historical===true,'invalid_response');
 const m=r.membershipAtAllocation;historyFields(m,['id','tier','status','paymentStatus','expiresAt']);
 need(historyUuid(m.id)&&tier(m.tier)&&['active','suspended','expired'].includes(String(m.status))&&m.paymentStatus==='verified'&&historyTime(m.expiresAt)&&m.expiresAt>r.recordedAt,'invalid_response');
 return r as unknown as HistoricalReceipt;
}
