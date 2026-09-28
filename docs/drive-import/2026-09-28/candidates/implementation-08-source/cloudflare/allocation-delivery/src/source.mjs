import {PaymentAllocationService} from '../../payment-allocation/src/service.mjs';
import {AllocationError,club,uuid,exact,demand,hash,NOW_SQL,envelope,failure} from './policy.mjs';

/** The source of truth is the existing allocation DB. No provider or identity write capability. */
export class DeliverySource extends PaymentAllocationService {
 constructor(env,principalId){
  super(env,principalId);
  demand(env.ALLOCATION_DELIVERY_ENABLED==='true','service_disabled');
  demand(uuid(env.DELIVERY_CONSUMER_ID),'invalid_configuration');
  this.consumerId=env.DELIVERY_CONSUMER_ID;
 }
 async access(clubId,role='dispatch'){
  demand(this.env.ALLOCATION_DELIVERY_ENABLED==='true','service_disabled');
  await this.authority(clubId,'outbox');
  const control=await this.first(`SELECT c.* FROM pa_delivery_control c JOIN pa_delivery_grants g ON g.club_id=c.club_id
   WHERE c.club_id=? AND c.enabled=1 AND c.consumer_id=? AND g.principal_id=? AND g.enabled=1 AND g.role=?`,clubId,this.consumerId,this.principalId,role);
  demand(control,'permission_denied');return control;
 }
 async command(clubId,eventId,action,revision,{requestId=crypto.randomUUID(),leaseId=null,reason='none',receiptId=null}={}){
  const role=action==='redrive'?'review':'dispatch';
  await this.access(clubId,role);
  const value={clubId,eventId,action,revision,requestId,leaseId,reason,receiptId};
  demand(uuid(eventId)&&uuid(requestId)&&Number.isSafeInteger(revision)&&revision>=0,'invalid_request');
  const digest=await hash(value);
  const previous=async()=>{
   const row=await this.first('SELECT * FROM pa_delivery_commands WHERE request_id=?',requestId);
   if(row)demand(row.principal_id===this.principalId&&row.request_sha256===digest,'idempotency_conflict');
   return row;
  };
  if(!await previous()){
   try{
    await this.statement(`INSERT INTO pa_delivery_commands(request_id,principal_id,event_id,club_id,action,expected_revision,
     request_sha256,lease_id,reason,receipt_id,recorded_at_ms) VALUES(?,?,?,?,?,?,?,?,?,?,${NOW_SQL})`,requestId,this.principalId,
     eventId,clubId,action,revision,digest,leaseId,reason,receiptId).run();
   }catch(error){await this.access(clubId,role);if(!await previous())throw error;}
  }
  await this.access(clubId,role);const record=await previous();demand(record,'delivery_unavailable');
  return {schemaVersion:1,operationId:record.request_id,eventId:record.event_id,action:record.action,committed:true,
   resultingRevision:record.expected_revision+1};
 }
 async job(clubId,eventId){return this.first('SELECT * FROM pa_delivery_jobs WHERE event_id=? AND club_id=?',eventId,clubId);}
 async take(input){
  try{
   exact(input,['clubId']);demand(club(input.clubId));await this.access(input.clubId);
   // Adoption is bounded and excludes any previously attempted legacy work. The SQL trigger
   // arbitrates a simultaneous legacy claim versus new enrollment in the same database.
   const available=await this.first(`SELECT o.event_id FROM pa_outbox o JOIN pa_outbox_delivery d ON d.event_id=o.event_id
    LEFT JOIN pa_delivery_jobs j ON j.event_id=o.event_id
    WHERE o.club_id=? AND d.club_id=o.club_id AND d.state='pending' AND d.attempts=0 AND j.event_id IS NULL
    ORDER BY o.recorded_at_ms,o.event_id LIMIT 1`,input.clubId);
   if(available){
    try{await this.command(input.clubId,available.event_id,'enroll',0);}
    catch(error){if(failure(error).code!=='conflict')throw error;}
   }
   const row=await this.first(`SELECT * FROM pa_delivery_jobs WHERE club_id=? AND consumer_id=?
    AND ((state IN ('pending','retry') AND next_at_ms<=${NOW_SQL}) OR (state='leased' AND lease_until_ms<=${NOW_SQL}))
    ORDER BY next_at_ms,event_id LIMIT 1`,input.clubId,this.consumerId);
   if(!row){await this.access(input.clubId);return {schemaVersion:1,clubId:input.clubId,event:null};}
   if(row.state==='leased'){
    try{await this.command(input.clubId,row.event_id,'expire',row.revision,{leaseId:row.lease_id,reason:'lease_expired'});}
    catch(error){if(failure(error).code!=='conflict')throw error;}
    return {schemaVersion:1,clubId:input.clubId,event:null};
   }
   const requestId=crypto.randomUUID();
   try{await this.command(input.clubId,row.event_id,'claim',row.revision,{requestId,leaseId:requestId});}
   catch(error){if(failure(error).code==='conflict')return {schemaVersion:1,clubId:input.clubId,event:null};throw error;}
   const job=await this.job(input.clubId,row.event_id);
   demand(job?.lease_id===requestId&&job.state==='leased','conflict');
   await this.access(input.clubId);
   return {schemaVersion:1,clubId:input.clubId,event:{eventId:job.event_id,leaseId:job.lease_id,leaseUntil:job.lease_until_ms,revision:job.revision}};
  }catch(error){throw failure(error);}
 }
 async readForDispatch(input){
  try{
   exact(input,['clubId','eventId','leaseId']);demand(club(input.clubId)&&uuid(input.eventId)&&uuid(input.leaseId));
   await this.access(input.clubId);
   const row=await this.first(`SELECT j.revision,j.lease_until_ms,o.event_id,o.club_id,o.payload_json,o.recorded_at_ms,
    a.order_id,a.allocation_id,l.user_id,l.business_target_fulfilled,ord.kind,r.receipt_json
    FROM pa_delivery_jobs j JOIN pa_outbox o ON o.event_id=j.event_id JOIN pa_allocations a ON a.allocation_id=o.allocation_id
    JOIN pa_orders ord ON ord.order_id=a.order_id AND ord.club_id=o.club_id
    JOIN pa_ledger l ON l.allocation_id=a.allocation_id AND l.club_id=o.club_id AND l.user_id=ord.user_id
    JOIN pa_receipts r ON r.allocation_id=a.allocation_id
    WHERE j.event_id=? AND j.club_id=? AND j.state='leased' AND j.lease_id=? AND j.lease_principal=?
    AND j.lease_until_ms>${NOW_SQL} AND j.consumer_id=?`,input.eventId,input.clubId,input.leaseId,this.principalId,this.consumerId);
   demand(row,'conflict');
   demand(row.payload_json.length<=8192&&row.payload_json===row.receipt_json,'invalid_event');
   let receipt;try{receipt=JSON.parse(row.payload_json);}catch{throw new AllocationError('invalid_event');}
   demand(receipt.schemaVersion===1&&receipt.allocationId===row.event_id&&receipt.orderId===row.order_id&&receipt.userId===row.user_id
    &&receipt.clubId===row.club_id&&receipt.kind===row.kind&&receipt.allocationPersisted===true
    &&receipt.businessTargetFulfilled===(row.business_target_fulfilled===1)&&receipt.recordedAt===row.recorded_at_ms,'invalid_event');
   const value=envelope({schemaVersion:1,consumerId:this.consumerId,eventId:row.event_id,clubId:row.club_id,orderId:row.order_id,
    userId:row.user_id,kind:row.kind,allocationRecorded:true,businessTargetFulfilled:receipt.businessTargetFulfilled,recordedAt:row.recorded_at_ms});
   const digest=await hash(value);await this.access(input.clubId);
   // A new first-primary query, rather than pretending all reads of one session are primary.
   const current=await this.first(`SELECT revision FROM pa_delivery_jobs WHERE event_id=? AND club_id=? AND state='leased'
    AND lease_id=? AND lease_principal=? AND lease_until_ms>${NOW_SQL}`,input.eventId,input.clubId,input.leaseId,this.principalId);
   demand(current?.revision===row.revision,'conflict');
   return {schemaVersion:1,event:value,envelopeSha256:digest};
  }catch(error){throw failure(error);}
 }
 async finish(input){
  try{
   exact(input,['clubId','eventId','leaseId','expectedRevision','requestId','outcome','reason','receiptId']);
   demand(club(input.clubId)&&uuid(input.eventId)&&uuid(input.leaseId)&&uuid(input.requestId));
   demand(['delivered','retry','dead'].includes(input.outcome));
   return await this.command(input.clubId,input.eventId,input.outcome,input.expectedRevision,
    {requestId:input.requestId,leaseId:input.leaseId,reason:input.reason,receiptId:input.receiptId});
  }catch(error){throw failure(error);}
 }
 async redrive(input){
  try{
   exact(input,['clubId','eventId','expectedRevision','requestId','reason']);demand(club(input.clubId)&&uuid(input.eventId)&&uuid(input.requestId));
   demand(['dependency_restored','configuration_corrected'].includes(input.reason));
   return await this.command(input.clubId,input.eventId,'redrive',input.expectedRevision,{requestId:input.requestId,reason:input.reason});
  }catch(error){throw failure(error);}
 }

 async health(input){
  try{
   exact(input,['clubId']);demand(club(input.clubId));await this.access(input.clubId,'review');
   const counts={};let capped=false;
   for(const state of ['pending','leased','retry','dead','delivered']){
    const row=await this.first(`SELECT count(*) n FROM (SELECT event_id FROM pa_delivery_jobs
     WHERE club_id=? AND consumer_id=? AND state=? LIMIT 1001)`,input.clubId,this.consumerId,state);
    counts[state]=Math.min(row.n,1000);capped||=row.n>1000;
   }
   const legacy=await this.first(`SELECT count(*) n FROM (SELECT d.event_id FROM pa_outbox_delivery d
    LEFT JOIN pa_delivery_jobs j ON j.event_id=d.event_id WHERE d.club_id=? AND d.attempts>0 AND j.event_id IS NULL LIMIT 1001)`,input.clubId);
   capped||=legacy.n>1000;
   const observed=await this.first(`SELECT ${NOW_SQL} observed_at_ms`);
   await this.access(input.clubId,'review');
   return {schemaVersion:1,clubId:input.clubId,observedAt:observed.observed_at_ms,counts,
    unmanagedLegacyAttempted:Math.min(legacy.n,1000),capped,snapshot:false,
    meaning:'operations inbox records, not financial settlement or handset delivery'};
  }catch(error){throw failure(error);}
 }
 async inspect(input){
  try{
   exact(input,['clubId','state','afterEventId','limit']);
   demand(club(input.clubId)&&['pending','leased','retry','dead','delivered'].includes(input.state)
    &&(input.afterEventId===null||uuid(input.afterEventId))&&Number.isInteger(input.limit)&&input.limit>=1&&input.limit<=50);
   await this.access(input.clubId,'review');
   const rows=await this.db.withSession('first-primary').prepare(`SELECT event_id,revision,state,attempts,cycle_attempts,reason,lease_until_ms
    FROM pa_delivery_jobs WHERE club_id=? AND consumer_id=? AND state=? AND event_id>? ORDER BY event_id LIMIT ?`)
    .bind(input.clubId,this.consumerId,input.state,input.afterEventId??'',input.limit+1).all();
   const more=rows.results.length>input.limit,items=rows.results.slice(0,input.limit).map(r=>({eventId:r.event_id,revision:r.revision,state:r.state,
    attempts:r.attempts,cycleAttempts:r.cycle_attempts,reason:r.reason,leaseUntil:r.lease_until_ms}));
   await this.access(input.clubId,'review');
   return {schemaVersion:1,clubId:input.clubId,items,nextAfterEventId:more?items.at(-1).eventId:null,
    meaning:'operations inbox delivery; not settlement or device notification',snapshot:false};
  }catch(error){throw failure(error);}
 }
}
