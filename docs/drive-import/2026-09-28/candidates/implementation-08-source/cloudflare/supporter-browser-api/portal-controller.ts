import {BrowserClientError, type BrowserMemberClient, type BrowserSession, type Challenge,
 type MembershipHistoryItem, type CurrentMembership, type CurrentCheckout, type MembershipOffer, type HistoricalReceipt} from './client';

export type PortalPhase = 'checking'|'signed_out'|'code_sent'|'member'|'blocked';
export interface PortalState {
 phase:PortalPhase;busy:boolean;message:string;canCheckout:boolean;pending:boolean;canRetrySignIn:boolean;canRetrySession:boolean;
 membership:CurrentMembership|null;offers:ReadonlyArray<MembershipOffer>;review:MembershipOffer|null;
 history:ReadonlyArray<MembershipHistoryItem>;historyCursor:string|null;historyLoaded:boolean;historyReceipt:HistoricalReceipt|null;
 checkout:CurrentCheckout|null;receipt:HistoricalReceipt|null;
}
export const INITIAL_PORTAL_STATE:Readonly<PortalState>=Object.freeze({phase:'checking',busy:false,message:'Check your session to continue.',
 canCheckout:false,pending:false,canRetrySignIn:false,canRetrySession:false,membership:null,offers:[],review:null,checkout:null,receipt:null,history:[],historyCursor:null,historyLoaded:false,historyReceipt:null});
type Client=Pick<BrowserMemberClient,'start'|'challenge'|'verify'|'restore'|'rotate'|'logout'|'offers'|'membershipStatus'|
 'pendingCheckout'|'prepareCheckout'|'recoverCheckout'|'retryPendingCheckout'|'checkout'|'receipt'|'lastPreparedCheckout'|'history'|'historicalReceipt'>;
const same=(a:BrowserSession|null,b:BrowserSession)=>a?.userId===b.userId&&a.clubId===b.clubId&&a.sessionId===b.sessionId&&a.authenticatedAt===b.authenticatedAt;
const equalOffer=(a:MembershipOffer,b:MembershipOffer)=>a.tier===b.tier&&a.amount===b.amount&&a.country===b.country&&a.currency===b.currency;
const safeMessages:Record<string,string>={
 invalid_code:'The code was not accepted. Check it and try again.',rate_limited:'Too many requests. Wait before trying again.',
 csrf_rejected:'Your session changed. Check your session before continuing.',session_changed:'Your session changed. Check your session before continuing.',
 recovery_store_corrupt:'Recovery records could not be read safely. New checkouts are blocked; contact support without clearing site data.',
 recovery_store_unavailable:'Recovery storage is unavailable. New checkouts are blocked; do not clear site data.',
 pending_checkout:'An earlier checkout remains unresolved. Check its original result before starting another.',
 offer_changed:'The catalog changed. Review the latest tier and amount before preparing checkout.',
 site_update_required:'A site update is required. Apply the available update and reopen this page.',
 inactive:'The page is not active or is offline. Reconnect and check your session.'};

/** Framework-independent UI coordinator. Only explicit event methods write; refresh/restore are reads.
 * Invalidating an in-flight call hides its result, but cannot cancel its remote commit. */
export class MembershipPortalController {
 private state:Readonly<PortalState>=INITIAL_PORTAL_STATE;
 private listeners=new Set<()=>void>();private epoch=0;private acting=false;private session:BrowserSession|null=null;
 private challenge:Challenge|null=null;private authRetry:(()=>Promise<void>)|null=null;private sessionRetry:(()=>Promise<void>)|null=null;
 constructor(private readonly client:Client,private readonly options:{canCheckout:boolean;key:()=>string;
  active?:()=>boolean;checkCacheBoundary?:()=>Promise<boolean>;notifySessionChange?:()=>void}){}
 getSnapshot=()=>this.state;
 subscribe=(fn:()=>void)=>{this.listeners.add(fn);return ()=>{this.listeners.delete(fn);};};
 private update(p:Partial<PortalState>){this.state=Object.freeze({...this.state,...p});for(const fn of this.listeners)fn();}
 private visible(){if(this.options.active?.()===false)throw new BrowserClientError('inactive');}
 private commit(epoch:number,p:Partial<PortalState>){if(epoch===this.epoch&&this.options.active?.()!==false)this.update(p);}
 private clear(p:Partial<PortalState>={}){this.update({membership:null,offers:[],review:null,checkout:null,receipt:null,history:[],historyCursor:null,historyLoaded:false,historyReceipt:null,pending:false,canCheckout:false,...p});}
 invalidate(message='Session details hidden. Check your session to continue.'){
  this.epoch++;this.clear({phase:'blocked',message}); // Keep durable pending operation metadata and a live request lock.
 }
 private notify(){try{this.options.notifySessionChange?.();}catch{/* Notification cannot repeat a business operation. */}}
 private async run(action:(epoch:number)=>Promise<void>){
  if(this.acting)return;this.acting=true;this.update({busy:true,message:''});const epoch=this.epoch;
  try{this.visible();await action(epoch);}catch(error){
   const e=error instanceof BrowserClientError?error:new BrowserClientError('service_unavailable');
   const msg=e.outcomeUnknown?'The request outcome is unknown. Check the original result; do not make another payment.':safeMessages[e.code]??'Service unavailable. No payment or membership change is assumed.';
   if(epoch===this.epoch){
    if(e.status===401){this.session=null;this.sessionRetry=null;this.authRetry=null;this.clear({phase:'signed_out',canRetrySession:false,canRetrySignIn:false,message:'Sign in again. Any unresolved checkout is retained.'});}
    else if(e.status===403||e.code==='session_changed'||e.code==='csrf_rejected'){this.clear({phase:'blocked',message:msg});}
    else this.commit(epoch,{message:msg,review:null,...(this.state.phase==='checking'?{phase:'blocked' as const}:{}),...(e.code.startsWith('recovery_store_')?{canCheckout:false}:{}),canRetrySignIn:this.authRetry!==null,canRetrySession:this.sessionRetry!==null});
   }
  }finally{this.acting=false;this.update({busy:false,canRetrySession:this.sessionRetry!==null,canRetrySignIn:this.authRetry!==null});}
 }
 private async load(epoch:number,s:BrowserSession){
  const [membership,catalogState]=await Promise.all([this.client.membershipStatus(),this.client.offers().then(catalog=>({catalog,enabled:true})).catch(error=>{
   // An explicitly disabled creation feature does not disable owned historical reads.
   // Authentication, authorization and malformed responses still fail normally.
   if(error instanceof BrowserClientError&&error.code==='browser_disabled'&&error.status===503)
    return {catalog:{offers:[] as MembershipOffer[]},enabled:false};
   throw error;
  })]);
  const catalog=catalogState.catalog;
  let pending=false,checkout:CurrentCheckout|null=null,storageReady=this.options.canCheckout&&catalogState.enabled,storageMessage=catalogState.enabled?'':'New checkouts are disabled. Membership and historical receipts remain read-only.';
  try{
   const saved=this.options.canCheckout?await this.client.pendingCheckout():null;pending=!!saved;
   const last=!saved&&this.options.canCheckout&&catalogState.enabled?await this.client.lastPreparedCheckout():null;
   checkout=last?await this.client.checkout(last.orderId):null;
  }catch(e){
   if(e instanceof BrowserClientError&&e.code.startsWith('recovery_store_')){storageReady=false;storageMessage=safeMessages[e.code]??safeMessages.recovery_store_unavailable;}
   else throw e;
  }
  if(epoch!==this.epoch)return;this.session=s;
  this.commit(epoch,{phase:'member',membership,offers:catalog.offers,checkout,receipt:null,review:null,
   pending,canCheckout:storageReady,canRetrySignIn:false,canRetrySession:this.sessionRetry!==null,
   history:[],historyCursor:null,historyLoaded:false,historyReceipt:null,
   message:storageMessage|| (pending?'An earlier checkout needs a result check.':!this.options.canCheckout?'This browser can read membership, but secure checkout recovery is unavailable.':'')});
 }
 refresh=()=>this.run(async epoch=>{
  this.clear({phase:'checking'});
  if(this.options.checkCacheBoundary&&!(await this.options.checkCacheBoundary())){this.commit(epoch,{phase:'blocked'});throw new BrowserClientError('site_update_required');}
  const s=await this.client.restore();this.authRetry=null;this.challenge=null;await this.load(epoch,s);
 });
 requestCode=(phone:string)=>this.run(async epoch=>{
  if(this.authRetry)throw new BrowserClientError('operation_in_progress');
  if(this.state.phase!=='signed_out'&&this.state.phase!=='code_sent')throw new BrowserClientError('invalid_request');
  await this.client.start();const key=this.options.key();
  const send=async()=>{const c=await this.client.challenge(phone,key);this.challenge=c;this.authRetry=null;
   this.commit(epoch,{phase:'code_sent',canRetrySignIn:false,message:'Code requested. Delivery is not yet confirmed.'});};
  this.authRetry=send;await send();
 });
 verifyCode=(code:string)=>this.run(async epoch=>{
  if(this.authRetry||!this.challenge)throw new BrowserClientError('invalid_request');
  const challengeId=this.challenge.challengeId,key=this.options.key();
  const verify=async()=>{
   try{const s=await this.client.verify(challengeId,code,key);this.authRetry=null;this.challenge=null;this.notify();await this.load(epoch,s);}
   catch(e){if(e instanceof BrowserClientError&&!e.outcomeUnknown)this.authRetry=null;throw e;}
  };this.authRetry=verify;await verify();
 });
 retrySignIn=()=>this.run(async()=>{if(!this.authRetry)throw new BrowserClientError('invalid_request');await this.authRetry();});
 selectTier(tier:string){
  if(this.acting||this.sessionRetry||this.state.phase!=='member'||this.state.pending||!this.state.canCheckout)return;
  this.visible();const offer=this.state.offers.find(x=>x.tier===tier);
  if(offer)this.update({review:{...offer},message:'Confirm preparation only. This does not send money.'});
 }
 cancelReview(){if(!this.acting)this.update({review:null});}
 private async currentSession(){if(this.sessionRetry)throw new BrowserClientError('session_changed');const s=await this.client.restore();if(!same(this.session,s))throw new BrowserClientError('session_changed');this.session=s;return s;}
 confirmCheckout=()=>this.run(async epoch=>{
  const review=this.state.review;if(!review||this.state.pending||!this.state.canCheckout)throw new BrowserClientError('invalid_request');
  await this.currentSession();const catalog=await this.client.offers();
  const current=catalog.offers.find(x=>x.tier===review.tier);
  if(!current||!equalOffer(review,current)){this.commit(epoch,{offers:catalog.offers,review:null});throw new BrowserClientError('offer_changed');}
  this.visible();if(epoch!==this.epoch)throw new BrowserClientError('inactive');
  // The reviewed catalog can change after the last read. The resulting order is displayed, never paid automatically.
  this.commit(epoch,{review:null,checkout:null,receipt:null,pending:true});
  const p=await this.client.prepareCheckout(review.tier,this.options.key());
  const checkout=await this.client.checkout(p.orderId);
  this.commit(epoch,{checkout,pending:false,message:'Checkout prepared. Read its current state below before any separate payment.'});
 });
 recoverCheckout=()=>this.run(async epoch=>{
  await this.currentSession();const result=await this.client.recoverCheckout();
  const last=result?.result??await this.client.lastPreparedCheckout();
  const checkout=last?await this.client.checkout(last.orderId):null;
  this.commit(epoch,{checkout,receipt:null,pending:result!==null&&!result.found,
   message:result&&!result.found?'Not observed yet. This does not prove failure. Only an explicit retry of the same request is permitted.':''});
 });
 retryCheckout=()=>this.run(async epoch=>{
  if(!this.state.pending||!this.state.canCheckout)throw new BrowserClientError('invalid_request');
  await this.currentSession();this.visible();if(epoch!==this.epoch)throw new BrowserClientError('inactive');
  const p=await this.client.retryPendingCheckout();const checkout=await this.client.checkout(p.orderId);
  this.commit(epoch,{checkout,pending:false,message:'Original checkout request recovered. No payment is confirmed.'});
 });
 /** Explicit, read-only pages replace previous items, bounding private memory to 20 rows. */
 loadHistory=(older=false)=>this.run(async epoch=>{
  const cursor=older?this.state.historyCursor:null;
  if(older&&!cursor)throw new BrowserClientError('invalid_request');
  await this.currentSession();
  const page=await this.client.history(cursor);
  this.commit(epoch,{history:page.items,historyCursor:page.nextCursor,historyLoaded:true,historyReceipt:null,
   message:'Historical allocations only. Current membership and external settlement must be checked separately.'});
 });
 readHistoryReceipt=(orderId:string)=>this.run(async epoch=>{
  const selected=this.state.history.find(x=>x.orderId===orderId);if(!selected)throw new BrowserClientError('invalid_request');
  this.commit(epoch,{historyReceipt:null});await this.currentSession();
  const receipt=await this.client.historicalReceipt(orderId);
  if(receipt.allocationId!==selected.allocationId||receipt.amount!==selected.amount||receipt.currency!==selected.currency||receipt.recordedAt!==selected.recordedAt)
   throw new BrowserClientError('invalid_response');
  this.commit(epoch,{historyReceipt:receipt});
 });
 closeHistoryReceipt(){if(!this.acting)this.update({historyReceipt:null});}
 refreshCheckout=()=>this.run(async epoch=>{
  const id=this.state.checkout?.orderId;if(!id)throw new BrowserClientError('invalid_request');
  await this.currentSession();const [checkout,membership]=await Promise.all([this.client.checkout(id),this.client.membershipStatus()]);
  this.commit(epoch,{checkout,membership,receipt:null});
 });
 readReceipt=()=>this.run(async epoch=>{
  const id=this.state.checkout?.orderId;if(!id)throw new BrowserClientError('invalid_request');
  await this.currentSession();const receipt=await this.client.receipt(id);this.commit(epoch,{receipt});
 });
 rotate=()=>this.run(async epoch=>{
  await this.currentSession();const key=this.options.key();
  const execute=async()=>{const s=await this.client.rotate(key);this.sessionRetry=null;this.notify();await this.load(epoch,s);};
  this.sessionRetry=execute;await execute();
 });
 retrySession=()=>this.run(async()=>{if(!this.sessionRetry)throw new BrowserClientError('invalid_request');await this.sessionRetry();});
 tick(now:number){
  if(this.state.phase!=='member'||!Number.isSafeInteger(now))return;
  if(this.session&&this.session.expiresAt<=now){this.invalidate('Your browser session expired. Sign in again to refresh membership.');return;}
  const m=this.state.membership;
  if(m?.isActive&&m.membership?.expiresAt!==null&&m?.membership&&m.membership.expiresAt<=now)
   this.update({membership:{...m,isActive:false,currentStatus:'expired'}});
  const c=this.state.checkout;
  if(c?.status==='pending_current'&&c.expiresAt<=now)this.update({checkout:{...c,status:'expired',paymentInstruction:null}});
 }

 logout=()=>this.run(async epoch=>{
  if(this.sessionRetry)throw new BrowserClientError('session_changed');
  const key=this.options.key();
  // Hide private presentation before dispatch, even when logout fails. Never clear recovery records.
  this.clear({phase:'blocked'});
  const execute=async()=>{await this.client.logout(key);this.sessionRetry=null;this.session=null;this.challenge=null;this.authRetry=null;this.notify();
   this.commit(epoch,{phase:'signed_out',canRetrySignIn:false,canRetrySession:false,message:'Signed out. Unresolved checkout metadata is retained for its owner.'});};
  this.sessionRetry=execute;await execute();
 });
}
