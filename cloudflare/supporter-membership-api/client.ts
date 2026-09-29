/** Native HTTP reference adapter; not a browser cookie client or installed Flutter transport.
 * An OS-protected credential supplier and durable process-safe store are required.
 * No payment, USSD invocation, automatic POST retry or background renewal occurs here. */
export type CurrentMembership={schemaVersion:1;clubId:number;userId:string;observedAt:number;currentStatus:'not_member'|'active'|'suspended'|'expired'|'pending'|'incomplete';isActive:boolean;historical:false;membership:null|{membershipId:string;tier:string;recordedStatus:'active'|'suspended'|'expired';paymentStatus:'pending'|'verified';renewedAt:number|null;expiresAt:number|null}};
export type Session={schemaVersion:1;userId:string;clubId:number;sessionId:string};
export type Prepared={schemaVersion:1;requestId:string;clubId:number;orderId:string;tier:string;reused:boolean;paymentVerified:false;membershipActivated:false};
export type Instruction={amount:number;currency:string;country:string;provider:string;recipient:string;ussdCode:string};
export type Status={schemaVersion:1;clubId:number;orderId:string;tier:string;status:'pending_current'|'expired'|'cancelled'|'allocated'|'configuration_changed';paymentEvidenceAllocated:boolean;observedAt:number;expiresAt:number;paymentInstruction:Instruction|null};
export type Receipt={schemaVersion:1;clubId:number;orderId:string;allocationId:string;amount:number;currency:string;recordedAt:number;allocationPersisted:true;businessTargetFulfilled:true;membershipAtAllocation:{id:string;tier:string;status:'active'|'suspended'|'expired';paymentStatus:'verified';expiresAt:number};historical:true};
export type JournalState={schemaVersion:1;mayOpenDialer:boolean;handoff:null|{handoffId:string;orderId:string;clubId:number;phase:'reserved'|'claimed'|'allocated'|'released';createdAt:number;claimedAt:number|null;orderExpiresAt:number;paymentEvidenceAllocated:boolean;observedAt:number}};
export class MembershipApiError extends Error {
  constructor(public readonly code:string, public readonly outcome:'not_sent'|'rejected'|'unknown'='not_sent'){super(code);this.name='MembershipApiError';}
}
const uuid=(v:unknown):v is string=>typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(v);
const tier=(v:unknown):v is string=>typeof v==='string'&&/^[a-z0-9][a-z0-9_-]{0,31}$/.test(v);
const time=(v:unknown):v is number=>typeof v==='number'&&Number.isSafeInteger(v)&&v>=0&&v<=253402300799999;
const oneOf=(v:unknown,values:readonly string[]):v is string=>typeof v==='string'&&values.includes(v);
const amount=(v:unknown):v is number=>typeof v==='number'&&Number.isSafeInteger(v)&&v>0&&v<=2147483647;
function need(v:unknown,code='invalid_membership_contract'):asserts v {if(!v)throw new MembershipApiError(code);}
function fields(v:unknown,k:string[]):asserts v is Record<string,unknown>{need(v!==null&&typeof v==='object'&&!Array.isArray(v)&&Object.keys(v).length===k.length&&k.every(x=>Object.hasOwn(v,x)));}
function session(v:unknown,clubId:number):asserts v is Session{fields(v,['schemaVersion','userId','clubId','sessionId']);need(v.schemaVersion===1&&v.clubId===clubId&&uuid(v.userId)&&uuid(v.sessionId));}
function prepared(v:unknown,clubId:number,key:string,t:string):asserts v is Prepared{
 fields(v,['schemaVersion','requestId','clubId','orderId','tier','reused','paymentVerified','membershipActivated']);
 need(v.schemaVersion===1&&v.requestId===key&&v.clubId===clubId&&uuid(v.orderId)&&v.tier===t&&typeof v.reused==='boolean'&&v.paymentVerified===false&&v.membershipActivated===false);
}
function instruction(v:unknown):asserts v is Instruction{fields(v,['amount','currency','country','provider','recipient','ussdCode']);
 need(amount(v.amount)&&typeof v.currency==='string'&&/^[A-Z]{3}$/.test(v.currency)&&typeof v.country==='string'&&/^[A-Z]{2}$/.test(v.country)&&
 typeof v.provider==='string'&&/^[a-z][a-z0-9_-]{0,63}$/.test(v.provider)&&typeof v.recipient==='string'&&/^[0-9]{3,32}$/.test(v.recipient)&&
 typeof v.ussdCode==='string'&&v.ussdCode.length<=128&&/^\*[0-9*]+#$/.test(v.ussdCode));}
function status(v:unknown,clubId:number,id:string):asserts v is Status{
 fields(v,['schemaVersion','clubId','orderId','tier','status','paymentEvidenceAllocated','observedAt','expiresAt','paymentInstruction']);
 need(v.schemaVersion===1&&v.clubId===clubId&&v.orderId===id&&tier(v.tier)&&oneOf(v.status,['pending_current','expired','cancelled','allocated','configuration_changed'])&&time(v.observedAt)&&time(v.expiresAt));
 need(v.paymentEvidenceAllocated===(v.status==='allocated'));
 if(v.status==='pending_current'){instruction(v.paymentInstruction);need(v.observedAt<v.expiresAt);}else need(v.paymentInstruction===null);
}
function receipt(v:unknown,clubId:number,id:string):asserts v is Receipt{
 fields(v,['schemaVersion','clubId','orderId','allocationId','amount','currency','recordedAt','allocationPersisted','businessTargetFulfilled','membershipAtAllocation','historical']);
 need(v.schemaVersion===1&&v.clubId===clubId&&v.orderId===id&&uuid(v.allocationId)&&amount(v.amount)&&typeof v.currency==='string'&&/^[A-Z]{3}$/.test(v.currency)&&time(v.recordedAt)&&v.allocationPersisted===true&&v.businessTargetFulfilled===true&&v.historical===true);
 const m=v.membershipAtAllocation;fields(m,['id','tier','status','paymentStatus','expiresAt']);need(uuid(m.id)&&tier(m.tier)&&oneOf(m.status,['active','suspended','expired'])&&m.paymentStatus==='verified'&&time(m.expiresAt)&&m.expiresAt>v.recordedAt);
}
function journal(v:unknown,clubId:number,operation:'current'|'reserve'|'claim'|'release',expected?:string):asserts v is JournalState{
 fields(v,['schemaVersion','handoff','mayOpenDialer']);need(v.schemaVersion===1&&typeof v.mayOpenDialer==='boolean');
 const h=v.handoff;if(h===null){need(operation==='current'&&!v.mayOpenDialer);return;}
 fields(h,['handoffId','orderId','clubId','phase','createdAt','claimedAt','orderExpiresAt','paymentEvidenceAllocated','observedAt']);
 need(uuid(h.handoffId)&&uuid(h.orderId)&&h.clubId===clubId&&oneOf(h.phase,['reserved','claimed','allocated','released']));
 need(time(h.createdAt)&&time(h.observedAt)&&time(h.orderExpiresAt)&&h.createdAt<=h.observedAt&&h.orderExpiresAt>h.createdAt);
 need(h.claimedAt===null||(time(h.claimedAt)&&h.claimedAt>=h.createdAt&&h.claimedAt<=h.observedAt));
 need(typeof h.paymentEvidenceAllocated==='boolean'&&h.paymentEvidenceAllocated===(h.phase==='allocated'));
 need(!['reserved','released'].includes(h.phase as string)||h.claimedAt===null);need(h.phase!=='claimed'||h.claimedAt!==null);
 if(operation==='reserve')need(h.orderId===expected);if(operation==='claim'||operation==='release')need(h.handoffId===expected);
 if(v.mayOpenDialer)need(operation==='claim'&&h.phase==='claimed'&&h.orderExpiresAt>h.observedAt+15000);
}
async function jsonBytes(response:Response):Promise<unknown>{
 need((response.headers.get('content-type')??'').split(';')[0].trim()==='application/json');
 const length=response.headers.get('content-length');need(length===null||(/^[0-9]+$/.test(length)&&Number(length)<=16384));
 const reader=response.body?.getReader();need(reader);let total=0;const chunks:Uint8Array[]=[];
 try{while(true){const {done,value}=await reader.read();if(done)break;total+=value.length;need(total<=16384);chunks.push(value);}
 const bytes=new Uint8Array(total);let n=0;for(const c of chunks){bytes.set(c,n);n+=c.length;}return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));}
 finally{reader.cancel().catch(()=>{});try{reader.releaseLock();}catch{}}
}
const publicErrors=new Set(['unauthenticated','permission_denied','rate_limited','service_disabled','service_unavailable','identity_unavailable','not_found','receipt_not_available','session_changed','invalid_request','staging_only','invalid_configuration','invalid_origin','native_transport_required','ingress_unverified','unsupported_media_type','payload_too_large','upstream_timeout','upstream_contract_invalid','method_not_allowed','handoff_disabled','handoff_unavailable']);
export class MembershipApiClient{
 constructor(private readonly base:string,public readonly clubId:number,private readonly credentials:()=>Promise<string>,private readonly fetcher:typeof fetch=fetch,private readonly timeoutMs=15000){
  const u=new URL(base);need(base===u.origin&&u.protocol==='https:'&&!u.username&&!u.password,'invalid_origin');need(Number.isSafeInteger(clubId)&&clubId>0&&Number.isInteger(timeoutMs)&&timeoutMs>0&&timeoutMs<=30000);
 }
 private async call(method:'GET'|'POST',suffix:string,expected:Session|null,body?:{tier:string}|{orderId:string}|{handoffId:string},key?:string,historyCursorValue?:string|null):Promise<unknown>{
  const unknownCode=suffix.startsWith('membership/handoffs/')?'handoff_outcome_unknown':'checkout_outcome_unknown';
  let accessToken:string;try{accessToken=await this.credentials();}catch{throw new MembershipApiError('credentials_unavailable');}
  need(typeof accessToken==='string'&&/^[0-9a-f-]{36}\.[A-Za-z0-9_-]{43}$/.test(accessToken),'credentials_unavailable');
  if(expected){session(expected,this.clubId);need(accessToken.split('.')[0]===expected.sessionId,'session_changed');}
  const controller=new AbortController();let timer:ReturnType<typeof setTimeout>|undefined;let started=false;
  try{
   const response=await Promise.race([(async()=>{
    started=true;
    const r=await this.fetcher(`${this.base}/v1/supporter/clubs/${this.clubId}/${suffix}`,{method,redirect:'error',credentials:'omit',cache:'no-store',signal:controller.signal,
      headers:{...(historyCursorValue?{'x-africlub-history-cursor':historyCursorValue}:{}),authorization:`Bearer ${accessToken}`,'x-africlub-client':'native-v1',...(expected?{'x-africlub-session':expected.sessionId}:{}),...(body?{'content-type':'application/json','idempotency-key':key!}:{})},...(body?{body:JSON.stringify(body)}:{})});
    const value=await jsonBytes(r);
    if(r.status!==200){
      if(method==='POST'&&r.status===503){
        const v=value as Record<string,unknown>;
        if(v?.error===unknownCode){fields(v,['schemaVersion','error','outcome','requestId']);need(v.schemaVersion===1&&v.outcome==='unknown'&&v.requestId===key);throw new MembershipApiError(unknownCode,'unknown');}
      }
      fields(value,['schemaVersion','error']);need(value.schemaVersion===1&&typeof value.error==='string'&&publicErrors.has(value.error)&&[400,401,403,404,405,409,413,415,429,503].includes(r.status));
      throw new MembershipApiError(value.error,'rejected');
    }
    return value;
   })(),new Promise<never>((_,reject)=>{timer=setTimeout(()=>{controller.abort();reject(new MembershipApiError(method==='POST'?unknownCode:'read_unavailable',method==='POST'?'unknown':'not_sent'));},this.timeoutMs);})]);
   return response;
  }catch(e){
   if(e instanceof MembershipApiError&&e.outcome!=='not_sent')throw e;
   throw new MembershipApiError(method==='POST'&&started?unknownCode:'read_unavailable',method==='POST'&&started?'unknown':'not_sent');
  }finally{clearTimeout(timer);controller.abort();}
 }
 async handoffCurrent(actor:Session):Promise<JournalState>{session(actor,this.clubId);const v=await this.call('GET','membership/handoffs/current',actor);journal(v,this.clubId,'current');return v;}
 async reserveHandoff(actor:Session,orderId:string,requestId:string):Promise<JournalState>{
  session(actor,this.clubId);need(uuid(orderId)&&uuid(requestId),'invalid_request');const v=await this.call('POST','membership/handoffs/reservations',actor,{orderId},requestId);
  try{journal(v,this.clubId,'reserve',orderId);return v;}catch{throw new MembershipApiError('handoff_outcome_unknown','unknown');}
 }
 async releaseHandoff(actor:Session,handoffId:string,requestId:string):Promise<JournalState>{
  session(actor,this.clubId);need(uuid(handoffId)&&uuid(requestId),'invalid_request');
  const v=await this.call('POST','membership/handoffs/releases',actor,{handoffId},requestId);
  try{journal(v,this.clubId,'release',handoffId);need(v.handoff!==null&&['released','allocated'].includes(v.handoff.phase)&&v.handoff.claimedAt===null&&!v.mayOpenDialer,'invalid_membership_contract');return v;}
  catch{throw new MembershipApiError('handoff_outcome_unknown','unknown');}
 }
 async claimHandoff(actor:Session,handoffId:string,requestId:string):Promise<JournalState>{
  session(actor,this.clubId);need(uuid(handoffId)&&uuid(requestId),'invalid_request');const v=await this.call('POST','membership/handoffs/claims',actor,{handoffId},requestId);
  try{journal(v,this.clubId,'claim',handoffId);return v;}catch{throw new MembershipApiError('handoff_outcome_unknown','unknown');}
 }
 async history(actor:Session,cursor:string|null=null):Promise<MembershipHistoryPage>{
  session(actor,this.clubId);historyCursor(cursor,actor);const value=await this.call('GET','membership/history',actor,undefined,undefined,cursor);
  return parseMemberHistory(value,actor,cursor);
 }
 async historicalReceipt(actor:Session,orderId:string):Promise<Receipt>{
  session(actor,this.clubId);need(uuid(orderId),'invalid_request');const value=await this.call('GET',`membership/history/${orderId}`,actor);
  return parseMemberHistoryReceipt(value,actor,orderId);
 }
 async membershipStatus(actor:Session):Promise<CurrentMembership>{
  session(actor,this.clubId);const v=await this.call('GET','membership/status',actor);
  fields(v,['schemaVersion','clubId','userId','observedAt','currentStatus','isActive','membership','historical']);
  need(v.schemaVersion===1&&v.clubId===this.clubId&&v.userId===actor.userId&&time(v.observedAt)&&v.historical===false&&
   oneOf(v.currentStatus,['not_member','active','suspended','expired','pending','incomplete'])&&v.isActive===(v.currentStatus==='active'));
  if(v.membership===null)need(v.currentStatus==='not_member');
  else {
   const m=v.membership;fields(m,['membershipId','tier','recordedStatus','paymentStatus','renewedAt','expiresAt']);
   need(uuid(m.membershipId)&&tier(m.tier)&&oneOf(m.recordedStatus,['active','suspended','expired'])&&
    oneOf(m.paymentStatus,['pending','verified'])&&(m.renewedAt===null||time(m.renewedAt))&&(m.expiresAt===null||time(m.expiresAt)));
   const expected=m.recordedStatus==='suspended'?'suspended':m.recordedStatus==='expired'||(m.expiresAt!==null&&Number(m.expiresAt)<=Number(v.observedAt))?'expired':m.paymentStatus!=='verified'?'pending':m.renewedAt===null||m.expiresAt===null||Number(m.renewedAt)>Number(v.observedAt)||Number(m.expiresAt)<=Number(m.renewedAt)?'incomplete':'active';
   need(v.currentStatus===expected||(expected==='active'&&v.currentStatus==='expired'));
  }
  return v as unknown as CurrentMembership;
 }
 async session():Promise<Session>{const v=await this.call('GET','session',null);session(v,this.clubId);return v;}
 async prepare(actor:Session,requestId:string,value:string):Promise<Prepared>{
  session(actor,this.clubId);need(uuid(requestId)&&tier(value),'invalid_request');
  const v=await this.call('POST','membership/checkouts',actor,{tier:value},requestId);
  try{prepared(v,this.clubId,requestId,value);return v;}catch{throw new MembershipApiError('checkout_outcome_unknown','unknown');}
 }
 async read(actor:Session,orderId:string):Promise<Status>{session(actor,this.clubId);need(uuid(orderId),'invalid_request');const v=await this.call('GET',`membership/checkouts/${orderId}`,actor);status(v,this.clubId,orderId);return v;}
 async receipt(actor:Session,orderId:string):Promise<Receipt>{session(actor,this.clubId);need(uuid(orderId),'invalid_request');const v=await this.call('GET',`membership/checkouts/${orderId}/receipt`,actor);receipt(v,this.clubId,orderId);return v;}
}
export type PendingCheckout={version:1;userId:string;clubId:number;requestId:string;tier:string;phase:'pending'|'prepared';orderId:string|null};
export interface RecoveryStore{
 /** Must serialize ALL processes/isolates using this account+club recovery key. */
 runExclusive<T>(scope:string,work:()=>Promise<T>):Promise<T>;
 load(scope:string):Promise<string|null>;
 /** Must durably write atomically and return false on a concurrent change. */
 compareAndSet(scope:string,expected:string|null,value:string):Promise<boolean>;
}
function decode(saved:string|null,actor:Session):PendingCheckout|null{
 if(saved===null)return null;let v:unknown;try{v=JSON.parse(saved);}catch{throw new MembershipApiError('recovery_store_invalid');}
 fields(v,['version','userId','clubId','requestId','tier','phase','orderId']);
 need(v.version===1&&v.userId===actor.userId&&v.clubId===actor.clubId&&uuid(v.requestId)&&tier(v.tier)&&oneOf(v.phase,['pending','prepared'])&&
   (v.phase==='pending'?v.orderId===null:uuid(v.orderId)),'recovery_store_invalid');return v as unknown as PendingCheckout;
}
/** Every mutation requires an explicit caller action. restore() never sends POST. */
export class CheckoutCoordinator{
 constructor(private readonly api:MembershipApiClient,private readonly store:RecoveryStore){need(store&&typeof store.runExclusive==='function'&&typeof store.load==='function'&&typeof store.compareAndSet==='function','recovery_store_unavailable');}
 private scope(s:Session){return `africlub-membership-v1:${s.clubId}:${s.userId}`;}
 private async save(scope:string,expected:string|null,value:PendingCheckout){const text=JSON.stringify(value);need(await this.store.compareAndSet(scope,expected,text),'recovery_store_conflict');need(await this.store.load(scope)===text,'recovery_store_unavailable');return text;}
 async restore():Promise<PendingCheckout|null>{const a=await this.api.session(),scope=this.scope(a);return this.store.runExclusive(scope,async()=>decode(await this.store.load(scope),a));}
 async begin(tierValue:string):Promise<Prepared>{
  need(tier(tierValue),'invalid_request');const a=await this.api.session(),scope=this.scope(a);
  return this.store.runExclusive(scope,async()=>{const old=await this.store.load(scope),p=decode(old,a);need(p?.phase!=='pending','unresolved_checkout');
    const next:PendingCheckout={version:1,userId:a.userId,clubId:a.clubId,requestId:crypto.randomUUID(),tier:tierValue,phase:'pending',orderId:null};
    const persisted=await this.save(scope,old,next);return this.send(a,scope,next,persisted);
  });
 }
 async resume():Promise<Prepared>{const a=await this.api.session(),scope=this.scope(a);return this.store.runExclusive(scope,async()=>{
   const saved=await this.store.load(scope),p=decode(saved,a);need(p?.phase==='pending','no_pending_checkout');return this.send(a,scope,p,saved!);
 });}
 private async send(a:Session,scope:string,p:PendingCheckout,saved:string):Promise<Prepared>{
  const result=await this.api.prepare(a,p.requestId,p.tier);
  await this.save(scope,saved,{...p,phase:'prepared',orderId:result.orderId});return result;
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
function parseMemberHistoryReceipt(v:unknown,actor:{clubId:number;userId:string},orderId:string):Receipt{
 historyFields(v,['schemaVersion','clubId','userId','observedAt','receipt']);need(v.schemaVersion===1&&v.clubId===actor.clubId&&v.userId===actor.userId&&historyTime(v.observedAt),'invalid_response');
 const r=v.receipt;historyFields(r,['schemaVersion','clubId','orderId','allocationId','amount','currency','recordedAt','allocationPersisted','businessTargetFulfilled','membershipAtAllocation','historical']);
 need(r.schemaVersion===1&&r.clubId===actor.clubId&&r.orderId===orderId&&historyUuid(r.allocationId)&&historyTime(r.recordedAt)&&r.recordedAt<=v.observedAt&&typeof r.amount==='number'&&Number.isInteger(r.amount)&&r.amount>0&&r.amount<=2147483647&&typeof r.currency==='string'&&r.currency.length===3&&/^[A-Z]{3}$/.test(r.currency)&&r.allocationPersisted===true&&r.businessTargetFulfilled===true&&r.historical===true,'invalid_response');
 const m=r.membershipAtAllocation;historyFields(m,['id','tier','status','paymentStatus','expiresAt']);
 need(historyUuid(m.id)&&tier(m.tier)&&oneOf(m.status,['active','suspended','expired'])&&m.paymentStatus==='verified'&&historyTime(m.expiresAt)&&m.expiresAt>r.recordedAt,'invalid_response');
 return r as unknown as Receipt;
}
