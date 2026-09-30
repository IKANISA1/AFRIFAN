/** Framework-independent case UI state. Backend ACL/SQL remain authoritative.
 * Persist only opaque command metadata, never credentials, SMS or free text.
 * Restore/check are reads. All writes require an explicit, foreground action.
 */
const UUID=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/;
const HEX=/^[a-f0-9]{64}$/;
export const CATEGORIES=['late','partial','duplicate','ambiguous','missing_reference','cancelled_order','refund_request'];
export const DISPOSITIONS=['no_financial_change','refer_reconciliation','refer_refund_review'];
export const REASONS=['support_request','evidence_received','needs_investigation','review_complete','insufficient_evidence','external_referral','new_evidence'];
export class CaseUiError extends Error {constructor(code){super(code);this.code=code;}}
function ensure(ok,code){if(!ok)throw new CaseUiError(code);}
const copy=x=>JSON.parse(JSON.stringify(x));
const keys=(x,n)=>x&&typeof x==='object'&&!Array.isArray(x)&&Object.keys(x).sort().join(',')===[...n].sort().join(',');
export function actionsFor(access,record) {
 if(!access?.canRead)return [];
 if(!record)return access.canMake?['open']:[];
 const actions=[];
 if(access.canMake){
  if(record.state==='open')actions.push('triage');
  if(['open','investigating'].includes(record.state))actions.push('propose');
  if(record.state==='reviewed')actions.push('close');
  if(record.state==='closed')actions.push('reopen');
 }
 if(access.canReview&&record.state==='awaiting_review'&&record.proposerSubject!==access.subject)actions.push('approve','reject');
 return actions;
}
export function validateIntent(intent,subject,clubId) {
 ensure(keys(intent,['schemaVersion','subject','clubId','caseId','operationId','expectedRevision','action','detail']), 'invalid_recovery_record');
 ensure(intent.schemaVersion===1&&intent.subject===subject&&UUID.test(subject)&&intent.clubId===clubId&&
  UUID.test(intent.caseId)&&UUID.test(intent.operationId)&&Number.isSafeInteger(intent.expectedRevision)&&intent.expectedRevision>=0&&
  intent.expectedRevision<2147483647,'invalid_recovery_record');
 ensure(['open','triage','propose','approve','reject','close','reopen'].includes(intent.action),'invalid_recovery_record');
 ensure(intent.action==='open'?intent.expectedRevision===0:intent.expectedRevision>0,'invalid_recovery_record');
 const d=intent.detail, names=['reasonCode','evidenceDigest'];
 if(intent.action==='open')names.push('category','orderId','evidenceId');
 if(intent.action==='propose')names.push('disposition');
 ensure(keys(d,names)&&REASONS.includes(d.reasonCode)&&(d.evidenceDigest===null||HEX.test(d.evidenceDigest)),'invalid_recovery_record');
 if(['propose','close'].includes(intent.action))ensure(typeof d.evidenceDigest==='string'&&HEX.test(d.evidenceDigest),'evidence_digest_required');
 if(intent.action==='propose')ensure(DISPOSITIONS.includes(d.disposition),'invalid_disposition');
 if(intent.action==='open'){
  ensure(CATEGORIES.includes(d.category),'invalid_category');
  ensure([d.orderId,d.evidenceId].every(x=>x===null||(typeof x==='string'&&UUID.test(x)))&&(d.orderId!==null||d.evidenceId!==null),'reference_required');
 }
 return intent;
}
export class CaseController {
 constructor({client,clubId,storage,foreground=()=>true,uuid=()=>crypto.randomUUID()}) {
  ensure(Number.isSafeInteger(clubId)&&clubId>0,'invalid_club');
  this.client=client;this.clubId=clubId;this.storage=storage;this.foreground=foreground;this.uuid=uuid;
  this.epoch=0;this.busy=false;this.session=null;this.draft=null;this.pending=null;this.receipt=null;this.record=null;
  this.cases=[];this.nextCaseId=null;this.events=[];this.nextRevision=null;this.stateFilter=null;
  this.rejected=false;this.storageFault=false;this.accessLost=false;
 }
 get key(){ensure(this.session,'access_required');return `africlub:case-intent:v1:${this.session.subject}:${this.clubId}`;}
 invalidateReview(){this.epoch++;this.draft=null;}
 suspend(){this.invalidateReview();this.accessLost=true;this.record=null;this.events=[];this.cases=[];this.receipt=null;}
 async access(){
  const fresh=await this.client.access(this.clubId);
  if(this.session&&fresh.subject!==this.session.subject){this.suspend();this.pending=null;throw new CaseUiError('operator_changed');}
  this.session=fresh;return fresh;
 }
 loadPending(){
  try{
   const raw=this.storage.getItem(this.key);
   if(raw===null){this.pending=null;return;}
   ensure(raw.length<=4096,'invalid_recovery_record');
   this.pending=copy(validateIntent(JSON.parse(raw),this.session.subject,this.clubId));
  }catch{this.storageFault=true;throw new CaseUiError('recovery_storage_unavailable');}
 }
 async boot(){
  ensure(!this.busy,'busy');this.invalidateReview();this.receipt=null;this.record=null;this.events=[];this.cases=[];
  await this.access();this.accessLost=false;this.storageFault=false;this.loadPending();
  await this.list(false);
 }
 async list(next=false){
  ensure(!this.busy,'busy');const epoch=++this.epoch;this.draft=null;
  const page=await this.client.list(this.clubId,{limit:25,...(next&&this.nextCaseId?{afterCaseId:this.nextCaseId}:{}),...(this.stateFilter?{state:this.stateFilter}:{})});
  if(epoch!==this.epoch)return;
  this.cases=next?[...this.cases,...page.cases.filter(c=>!this.cases.some(x=>x.caseId===c.caseId))]:page.cases;this.nextCaseId=page.nextCaseId;
 }
 async select(caseId){
  ensure(!this.busy,'busy');const epoch=++this.epoch;this.draft=null;this.record=null;this.events=[];this.nextRevision=null;
  const record=await this.client.get(this.clubId,caseId);if(epoch!==this.epoch)return;
  const history=await this.client.history(this.clubId,caseId,0,25);if(epoch!==this.epoch)return;
  this.record=record;this.events=history.events;this.nextRevision=history.nextRevision;
 }
 async moreHistory(){
  ensure(!this.busy,'busy');if(!this.record||!this.nextRevision)return;
  const epoch=this.epoch,id=this.record.caseId;
  const page=await this.client.history(this.clubId,id,this.nextRevision,25);
  if(epoch!==this.epoch||this.record?.caseId!==id)return;
  this.events=[...this.events,...page.events.filter(e=>!this.events.some(x=>x.eventId===e.eventId))];this.nextRevision=page.nextRevision;
 }
 stage(action,detail){
  ensure(!this.busy&&!this.pending&&!this.storageFault&&!this.accessLost,'recovery_required');ensure(this.foreground(),'foreground_required');
  const target=action==='open'?null:this.record;
  ensure(actionsFor(this.session,target).includes(action),'action_not_allowed');
  const intent={schemaVersion:1,subject:this.session.subject,clubId:this.clubId,caseId:target?.caseId??this.uuid(),
   operationId:this.uuid(),expectedRevision:target?.revision??0,action,detail:copy(detail)};
  this.draft=copy(validateIntent(intent,this.session.subject,this.clubId));this.receipt=null;this.rejected=false;
  return copy(this.draft);
 }
 save(intent){
  try{
   const current=this.storage.getItem(this.key),raw=JSON.stringify(intent);
   ensure(current===null||current===raw,'another_pending_operation');
   this.storage.setItem(this.key,raw);ensure(this.storage.getItem(this.key)===raw,'storage_write_failed');
  }catch{this.storageFault=true;throw new CaseUiError('recovery_storage_unavailable');}
 }
 clear(intent){
  try{
   ensure(this.storage.getItem(this.key)===JSON.stringify(intent),'recovery_record_changed');
   this.storage.removeItem(this.key);ensure(this.storage.getItem(this.key)===null,'storage_clear_failed');
  }catch{this.storageFault=true;throw new CaseUiError('recovery_storage_unavailable');}
  this.pending=null;
 }
 async send(intent){
  try{
   const r=await this.client.command(intent.clubId,intent.caseId,intent.operationId,intent.expectedRevision,intent.action,intent.detail);
   // The compiled client checks full response correlation. Keep original outcome
   // and latest head separate; a newer head is never called this command's result.
   this.receipt=r;this.record=r.currentCase;this.events=[];this.nextRevision=null;this.clear(intent);this.rejected=false;return r;
  }catch(error){
   this.rejected=!error.outcomeUnknown&&[400,409].includes(error.status)&&
     !['idempotency_conflict','invalid_response'].includes(error.code);
   if([401,403].includes(error.status))this.suspend();
   throw error;
  }
 }
 async confirm(acknowledged){
  ensure(acknowledged===true,'acknowledgement_required');ensure(!this.busy&&this.draft&&!this.pending&&!this.storageFault,'review_required');
  ensure(this.foreground(),'foreground_required');const intent=copy(this.draft),epoch=this.epoch;this.busy=true;
  try{
   const fresh=await this.access();
   const target=intent.action==='open'?null:await this.client.get(this.clubId,intent.caseId);
   ensure(actionsFor(fresh,target).includes(intent.action),'action_not_allowed');
   ensure(!target||target.revision===intent.expectedRevision,'stale_review');
   ensure(epoch===this.epoch&&this.foreground()&&!this.accessLost,'review_invalidated');
   this.save(intent);this.pending=intent;this.draft=null;
   return await this.send(intent);
  }finally{this.busy=false;}
 }
 async recover(){
  ensure(!this.busy,'busy');ensure(this.pending,'no_pending_operation');this.busy=true;const intent=copy(this.pending);
  try{
   await this.access();const r=await this.client.operation(this.clubId,intent.operationId);
   ensure(r.outcome.caseId===intent.caseId&&r.outcome.action===intent.action&&r.outcome.revision===intent.expectedRevision+1&&
    r.outcome.actorSubject===intent.subject,'recovery_outcome_conflict');
   this.receipt=r;this.record=r.currentCase;this.events=[];this.nextRevision=null;this.clear(intent);this.rejected=false;return r;
  }catch(error){if([401,403].includes(error.status))this.suspend();throw error;}
  finally{this.busy=false;}
 }
 async retry(acknowledged){
  ensure(acknowledged===true,'acknowledgement_required');ensure(!this.busy&&this.pending&&!this.storageFault&&!this.accessLost,'recovery_required');
  ensure(this.foreground(),'foreground_required');this.busy=true;const intent=copy(this.pending),epoch=this.epoch;
  try{
   await this.access();ensure(epoch===this.epoch&&this.foreground(),'review_invalidated');
   this.save(intent);return await this.send(intent);
  }finally{this.busy=false;}
 }
 discardRejected(acknowledged){
  ensure(acknowledged===true&&!this.busy&&this.pending&&this.rejected,'rejection_not_confirmed');
  this.clear(this.pending);this.rejected=false;this.draft=null;
 }
}
