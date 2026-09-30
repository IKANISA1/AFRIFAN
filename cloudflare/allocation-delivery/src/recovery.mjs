import {DeliverySource} from './source.mjs';
import {club,uuid,sha,exact,demand,hash,NOW_SQL,failure} from './policy.mjs';
import {traceOperation} from '../../shared-telemetry/telemetry.mjs';
/** Explicit, trusted-binding-only review. A prepared decision never drains or sends an event. */
export class DeliveryRecovery extends DeliverySource {
 constructor(env,principalId,{ctx,observe=true}={}){super(env,principalId,{ctx});this.observe=observe;demand(env.ALLOCATION_RECOVERY_ENABLED==='true','service_disabled');}
 async recoveryAccess(clubId){
  demand(this.env.ALLOCATION_RECOVERY_ENABLED==='true','service_disabled');await this.access(clubId,'review');
  const control=await this.first('SELECT * FROM pa_recovery_control WHERE singleton=1 AND enabled=1');
  demand(control&&Number.isInteger(control.decision_ms)&&control.decision_ms>=1000&&control.decision_ms<=300000,'permission_denied');return control;
 }
 view(row){return {schemaVersion:1,decisionId:row.decision_id,operationId:row.operation_id,clubId:row.club_id,eventId:row.event_id,
  expectedRevision:row.expected_revision,reason:row.reason,evidenceSha256:row.evidence_sha256,evidenceRef:row.evidence_ref,
  createdAt:row.created_at_ms,expiresAt:row.expires_at_ms,state:row.state,makerSelf:row.maker_id===this.principalId,checkerSelf:row.checker_id===this.principalId,
  resultingRevision:row.state==='confirmed'?row.expected_revision+1:null};}
 async inspectEvent(input){
  try{exact(input,['clubId','eventId']);demand(club(input.clubId)&&uuid(input.eventId));await this.recoveryAccess(input.clubId);
   const row=await this.job(input.clubId,input.eventId);demand(row,'not_found');
   const observed=await this.first(`SELECT ${NOW_SQL} observed_at_ms`);await this.recoveryAccess(input.clubId);
   return {schemaVersion:1,clubId:input.clubId,eventId:row.event_id,revision:row.revision,state:row.state,attempts:row.attempts,
    cycleAttempts:row.cycle_attempts,reason:row.reason,observedAt:observed.observed_at_ms,
    meaning:'operations inbox delivery; no financial or provider resend effect'};
  }catch(error){throw failure(error);}
 }
 async prepare(input){
  const work=()=>this.prepareDecision(input);return this.observe?traceOperation(this.env,{service:'allocation_delivery',operation:'delivery_prepare',clubId:Number.isSafeInteger(input?.clubId)?input.clubId:null},work,{ctx:this.context}):work();
 }
 async prepareDecision(input){
  try{
   exact(input,['clubId','eventId','expectedRevision','decisionId','operationId','reason','evidenceSha256','evidenceRef']);
   demand(club(input.clubId)&&uuid(input.eventId)&&uuid(input.decisionId)&&uuid(input.operationId)&&input.decisionId!==input.operationId&&
    Number.isSafeInteger(input.expectedRevision)&&input.expectedRevision>0&&sha(input.evidenceSha256)&&
    typeof input.evidenceRef==='string'&&/^[A-Z][A-Z0-9_-]{3,63}$/.test(input.evidenceRef)&&
    ['dependency_restored','configuration_corrected'].includes(input.reason),'invalid_request');
   const control=await this.recoveryAccess(input.clubId),digest=await hash(input);
   const prior=async()=>{
    const row=await this.first('SELECT * FROM pa_recovery_decisions WHERE decision_id=?',input.decisionId);
    if(row)demand(row.maker_id===this.principalId&&row.request_sha256===digest,'idempotency_conflict');return row;
   };
   if(!await prior()){
    // Keep the original command key and exact legacy command digest, without exposing the dispatch envelope.
    const commandDigest=await hash({clubId:input.clubId,eventId:input.eventId,action:'redrive',revision:input.expectedRevision,
     requestId:input.operationId,leaseId:null,reason:input.reason,receiptId:null});
    try{await this.statement(`INSERT INTO pa_recovery_decisions(decision_id,operation_id,maker_id,club_id,event_id,expected_revision,
     reason,evidence_sha256,evidence_ref,request_sha256,command_sha256,created_at_ms,expires_at_ms,state)
     VALUES(?,?,?,?,?,?,?,?,?,?,?,${NOW_SQL},${NOW_SQL}+?,'prepared')`,input.decisionId,input.operationId,this.principalId,
     input.clubId,input.eventId,input.expectedRevision,input.reason,input.evidenceSha256,input.evidenceRef,digest,commandDigest,control.decision_ms).run();}
    catch(error){await this.recoveryAccess(input.clubId);if(!await prior())throw error;}
   }
   await this.recoveryAccess(input.clubId);const row=await prior();demand(row,'delivery_unavailable');return this.view(row);
  }catch(error){throw failure(error);}
 }
 async decision(input){
  try{exact(input,['clubId','decisionId']);demand(club(input.clubId)&&uuid(input.decisionId));await this.recoveryAccess(input.clubId);
   const row=await this.first('SELECT * FROM pa_recovery_decisions WHERE decision_id=? AND club_id=?',input.decisionId,input.clubId);
   demand(row,'not_found');await this.recoveryAccess(input.clubId);return this.view(row);
  }catch(error){throw failure(error);}
 }
 async confirm(input){
  const work=()=>this.confirmDecision(input);return this.observe?traceOperation(this.env,{service:'allocation_delivery',operation:'delivery_confirm',clubId:Number.isSafeInteger(input?.clubId)?input.clubId:null},work,{ctx:this.context}):work();
 }
 async confirmDecision(input){
  try{
   exact(input,['clubId','decisionId','operationId','expectedRevision','evidenceSha256']);
   demand(club(input.clubId)&&uuid(input.decisionId)&&uuid(input.operationId)&&sha(input.evidenceSha256)&&
    Number.isSafeInteger(input.expectedRevision)&&input.expectedRevision>0,'invalid_request');await this.recoveryAccess(input.clubId);
   const read=async()=>{
    const row=await this.first('SELECT * FROM pa_recovery_decisions WHERE decision_id=? AND club_id=?',input.decisionId,input.clubId);
    demand(row&&row.operation_id===input.operationId&&row.expected_revision===input.expectedRevision&&row.evidence_sha256===input.evidenceSha256,'conflict');
    demand(row.maker_id!==this.principalId,'permission_denied');
    if(row.state==='confirmed')demand(row.checker_id===this.principalId,'idempotency_conflict');return row;
   };
   let row=await read();
   if(row.state!=='confirmed'){
    try{await this.statement(`UPDATE pa_recovery_decisions SET state='confirmed',checker_id=?,confirmed_at_ms=${NOW_SQL}
     WHERE decision_id=? AND state='prepared'`,this.principalId,input.decisionId).run();}
    catch(error){await this.recoveryAccess(input.clubId);row=await read();if(row.state!=='confirmed')throw error;}
   }
   await this.recoveryAccess(input.clubId);row=await read();demand(row.state==='confirmed','delivery_unavailable');
   const command=await this.first('SELECT * FROM pa_delivery_commands WHERE request_id=?',input.operationId);
   demand(command&&command.principal_id===this.principalId&&command.action==='redrive'&&command.event_id===row.event_id&&
    command.club_id===row.club_id&&command.expected_revision===row.expected_revision&&command.request_sha256===row.command_sha256,'delivery_unavailable');
   return {schemaVersion:1,decisionId:row.decision_id,operationId:row.operation_id,eventId:row.event_id,action:'redrive',
    committed:true,resultingRevision:row.expected_revision+1};
  }catch(error){throw failure(error);}
 }
}
