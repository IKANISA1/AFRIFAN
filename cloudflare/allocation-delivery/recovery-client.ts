/** Trusted server-side review client; never give these private bindings to a browser. */
export interface RecoveryBinding {decision(input:unknown):Promise<unknown>;prepare?(input:unknown):Promise<unknown>;confirm?(input:unknown):Promise<unknown>;}
export interface PrepareRequest {clubId:number;eventId:string;expectedRevision:number;decisionId:string;operationId:string;reason:'dependency_restored'|'configuration_corrected';evidenceSha256:string;evidenceRef:string;}
/** eventId is local binding context; it is excluded from the five-field confirmation wire request. */
export interface ConfirmRequest {clubId:number;eventId:string;decisionId:string;operationId:string;expectedRevision:number;evidenceSha256:string;}
export interface Decision {schemaVersion:1;decisionId:string;operationId:string;clubId:number;eventId:string;expectedRevision:number;reason:PrepareRequest['reason'];
 evidenceSha256:string;evidenceRef:string;createdAt:number;expiresAt:number;state:'prepared'|'confirmed';makerSelf:boolean;checkerSelf:boolean;resultingRevision:number|null;}
export interface Receipt {schemaVersion:1;decisionId:string;operationId:string;eventId:string;action:'redrive';committed:true;resultingRevision:number;}
export interface JournalEntry {schemaVersion:1;purpose:'allocation-recovery';clubId:number;role:'maker'|'checker';kind:'prepare'|'confirm';
 request:PrepareRequest|ConfirmRequest;phase:'staged'|'attempted'|'acknowledged';receipt:Decision|Receipt|null;}
/** The host must provide durable atomic CAS with retained history, scoped to the authenticated operator, club and role. */
export interface RecoveryJournal {load():Promise<{version:number;value:unknown}>;compareAndSwap(version:number,value:JournalEntry):Promise<boolean>;}
export class RecoveryClientError extends Error {constructor(public readonly code:string){super(code);this.name='RecoveryClientError';}}
const uuid=(x:unknown):x is string=>typeof x==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(x);
const integer=(x:unknown):x is number=>typeof x==='number'&&Number.isSafeInteger(x)&&x>=0;
const sha=(x:unknown)=>typeof x==='string'&&/^[0-9a-f]{64}$/.test(x);
function demand(x:unknown,code='invalid_response'):asserts x{if(!x)throw new RecoveryClientError(code);}
function object(x:unknown):asserts x is Record<string,unknown>{demand(x!==null&&typeof x==='object'&&!Array.isArray(x));}
function keys(x:Record<string,unknown>,list:string[]){demand(Object.keys(x).length===list.length&&list.every(k=>Object.hasOwn(x,k)));}
function validateRequest(value:unknown,kind:'prepare'|'confirm',clubId:number){
 object(value);keys(value,kind==='prepare'?['clubId','eventId','expectedRevision','decisionId','operationId','reason','evidenceSha256','evidenceRef']:
  ['clubId','eventId','decisionId','operationId','expectedRevision','evidenceSha256']);
 demand(value.clubId===clubId&&uuid(value.eventId)&&uuid(value.decisionId)&&uuid(value.operationId)&&value.decisionId!==value.operationId&&integer(value.expectedRevision)&&value.expectedRevision>0&&sha(value.evidenceSha256));
 if(kind==='prepare')demand(uuid(value.eventId)&&typeof value.reason==='string'&&['dependency_restored','configuration_corrected'].includes(value.reason)&&
  typeof value.evidenceRef==='string'&&/^[A-Z][A-Z0-9_-]{3,63}$/.test(value.evidenceRef));
}
function decision(value:unknown,request:ConfirmRequest|PrepareRequest,role:'maker'|'checker'):Decision{
 object(value);keys(value,['schemaVersion','decisionId','operationId','clubId','eventId','expectedRevision','reason','evidenceSha256','evidenceRef','createdAt','expiresAt','state','makerSelf','checkerSelf','resultingRevision']);
 demand(value.schemaVersion===1&&value.decisionId===request.decisionId&&value.operationId===request.operationId&&value.clubId===request.clubId&&
  value.expectedRevision===request.expectedRevision&&value.evidenceSha256===request.evidenceSha256&&uuid(value.eventId)&&
  integer(value.createdAt)&&integer(value.expiresAt)&&value.expiresAt>value.createdAt&&value.expiresAt-value.createdAt<=300000&&
  typeof value.makerSelf==='boolean'&&typeof value.checkerSelf==='boolean'&&typeof value.reason==='string'&&
  ['dependency_restored','configuration_corrected'].includes(value.reason)&&typeof value.evidenceRef==='string'&&/^[A-Z][A-Z0-9_-]{3,63}$/.test(value.evidenceRef));
 demand((value.state==='prepared'&&value.resultingRevision===null&&value.checkerSelf===false)||
  (value.state==='confirmed'&&value.resultingRevision===request.expectedRevision+1&&value.checkerSelf===!value.makerSelf));
 // For another checker a confirmed decision is deliberately not attributable to this client.
 if(role==='maker')demand(value.makerSelf===true);
 demand(value.eventId===request.eventId);
 if('reason' in request)demand(value.reason===request.reason&&value.evidenceRef===request.evidenceRef);
 return value as unknown as Decision;
}
function receipt(value:unknown,request:ConfirmRequest):Receipt{
 object(value);keys(value,['schemaVersion','decisionId','operationId','eventId','action','committed','resultingRevision']);
 demand(value.schemaVersion===1&&value.decisionId===request.decisionId&&value.operationId===request.operationId&&value.eventId===request.eventId&&
  value.action==='redrive'&&value.committed===true&&value.resultingRevision===request.expectedRevision+1);return value as unknown as Receipt;
}
const same=(a:unknown,b:unknown)=>JSON.stringify(a)===JSON.stringify(b);
/** Construction, loading and reconciliation do no remote writes. Every send is an explicit method call. */
export class DeliveryRecoveryClient {
 private epoch=0;private busy=false;
 constructor(private binding:RecoveryBinding,private journal:RecoveryJournal,private clubId:number,private role:'maker'|'checker',private timeoutMs=4000){
  demand(integer(clubId)&&clubId>0&&['maker','checker'].includes(role)&&integer(timeoutMs)&&timeoutMs>=100&&timeoutMs<=4000,'invalid_configuration');
 }
 invalidate(){this.epoch++;}
 private async bounded<T>(work:()=>Promise<T>,code:string):Promise<T>{let timer:ReturnType<typeof setTimeout>|undefined;
  try{return await Promise.race([Promise.resolve().then(work),new Promise<T>((_,reject)=>{timer=setTimeout(()=>reject(new RecoveryClientError(code)),this.timeoutMs);})]);}
  finally{clearTimeout(timer);}}
 private async load(){
  let read:{version:number;value:unknown};try{read=await this.bounded(()=>this.journal.load(),'journal_unavailable');}catch{throw new RecoveryClientError('journal_unavailable');}
  demand(integer(read.version),'journal_unavailable');
  if(read.value!==null){try{
   object(read.value);keys(read.value,['schemaVersion','purpose','clubId','role','kind','request','phase','receipt']);
   const kind=this.role==='maker'?'prepare':'confirm';demand(read.value.schemaVersion===1&&read.value.purpose==='allocation-recovery'&&
    read.value.clubId===this.clubId&&read.value.role===this.role&&read.value.kind===kind&&typeof read.value.phase==='string'&&
    ['staged','attempted','acknowledged'].includes(read.value.phase));validateRequest(read.value.request,kind,this.clubId);
   if(read.value.phase==='acknowledged'){
    if(kind==='prepare')decision(read.value.receipt,read.value.request as unknown as PrepareRequest,this.role);
    else receipt(read.value.receipt,read.value.request as unknown as ConfirmRequest);
   }else demand(read.value.receipt===null);
  }catch{throw new RecoveryClientError('journal_unavailable');}}
  return {version:read.version,value:read.value as JournalEntry|null};
 }
 private async store(version:number,value:JournalEntry){
  let stored=false;try{stored=await this.bounded(()=>this.journal.compareAndSwap(version,structuredClone(value)),'journal_unavailable');}catch{throw new RecoveryClientError('journal_unavailable');}
  demand(stored,'journal_conflict');const next=await this.load();demand(next.version===version+1&&same(next.value,value),'journal_unavailable');return next;
 }
 async pending(){return (await this.load()).value;}
 async stage(input:PrepareRequest|ConfirmRequest){
  demand(!this.busy,'operation_busy');const epoch=this.epoch,kind=this.role==='maker'?'prepare':'confirm';
  try{validateRequest(input,kind,this.clubId);}catch{throw new RecoveryClientError('invalid_request');}
  this.busy=true;try{
   const current=await this.load();demand(epoch===this.epoch,'scope_invalidated');
   if(current.value){
    if(same(current.value.request,input))return current.value;
    demand(current.value.phase==='acknowledged','unresolved_operation');
   }
   // Journal write plus readback precedes ANY binding mutation.
   const value:JournalEntry={schemaVersion:1,purpose:'allocation-recovery',clubId:this.clubId,role:this.role,kind,request:structuredClone(input),phase:'staged',receipt:null};
   const next=await this.store(current.version,value);demand(epoch===this.epoch,'scope_invalidated');return next.value;
  }finally{this.busy=false;}
 }
 async sendOriginal(){
  demand(!this.busy,'operation_busy');this.busy=true;const epoch=this.epoch;
  try{
   const current=await this.load();demand(epoch===this.epoch,'scope_invalidated');demand(current.value,'no_pending_operation');
   if(current.value.phase==='acknowledged')return current.value.receipt;
   const attempted:JournalEntry={...current.value,phase:'attempted',receipt:null};const written=await this.store(current.version,attempted);
   demand(epoch===this.epoch,'scope_invalidated');let response:Decision|Receipt;
   try{
    if(attempted.kind==='prepare'){
     demand(typeof this.binding.prepare==='function','invalid_configuration');response=decision(await this.bounded(()=>this.binding.prepare!(structuredClone(attempted.request)),'write_outcome_unknown'),attempted.request as PrepareRequest,this.role);
    }else{
     demand(typeof this.binding.confirm==='function','invalid_configuration');const {eventId,...wire}=attempted.request as ConfirmRequest;
     response=receipt(await this.bounded(()=>this.binding.confirm!(structuredClone(wire)),'write_outcome_unknown'),attempted.request as ConfirmRequest);
    }
    demand(epoch===this.epoch,'write_outcome_unknown');
    await this.store(written.version,{...attempted,phase:'acknowledged',receipt:response});return response;
   }catch{throw new RecoveryClientError('write_outcome_unknown');}
  }finally{this.busy=false;}
 }
 async reconcileReadOnly(){
  demand(!this.busy,'operation_busy');this.busy=true;const epoch=this.epoch;
  try{
   const current=await this.load();demand(epoch===this.epoch,'scope_invalidated');demand(current.value,'no_pending_operation');
   const request=current.value.request;
   const remote=decision(await this.bounded(()=>this.binding.decision({clubId:this.clubId,decisionId:request.decisionId}),'read_unavailable'),request,this.role);
   demand(epoch===this.epoch,'scope_invalidated');
   if(current.value.kind==='prepare')await this.store(current.version,{...current.value,phase:'acknowledged',receipt:remote});
   else if(remote.state==='confirmed'&&remote.checkerSelf)await this.store(current.version,{...current.value,phase:'acknowledged',receipt:{schemaVersion:1,decisionId:remote.decisionId,
    operationId:remote.operationId,eventId:remote.eventId,action:'redrive',committed:true,resultingRevision:remote.expectedRevision+1}});
   return remote;
  }finally{this.busy=false;}
 }
}
