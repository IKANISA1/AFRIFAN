import {envelope,exact,uuid,club,demand,hash,NOW_SQL,failure} from './policy.mjs';
/** Concrete idempotent effect: one durable operational inbox record per source event. */
export class AllocationInbox {
 constructor(env){
  this.env=env;this.db=env.INBOX_DB;
  demand(env.INBOX_ENABLED==='true','service_disabled');
  demand(env.DELIVERY_ENVIRONMENT==='isolated-staging','staging_only');
  demand(uuid(env.DELIVERY_CONSUMER_ID)&&this.db?.prepare&&this.db?.withSession,'invalid_configuration');
 }
 async first(sql,...args){return this.db.withSession('first-primary').prepare(sql).bind(...args).first();}
 async access(clubId){
  demand(this.env.INBOX_ENABLED==='true','service_disabled');
  demand(await this.first(`SELECT 1 ok FROM adi_control c JOIN adi_clubs cl ON cl.club_id=?
   WHERE c.singleton=1 AND c.purpose='africlub-allocation-inbox' AND c.enabled=1 AND cl.enabled=1 AND c.consumer_id=? AND length(c.approval_ref)>0`,
   clubId,this.env.DELIVERY_CONSUMER_ID),'permission_denied');
 }
 async accept(input){
  try{
   const value=envelope(input);demand(value.consumerId===this.env.DELIVERY_CONSUMER_ID,'permission_denied');await this.access(value.clubId);
   const digest=await hash(value),encoded=JSON.stringify(value);
   const existing=async()=>{
    const row=await this.first('SELECT * FROM adi_events WHERE event_id=?',value.eventId);
    if(row)demand(row.consumer_id===value.consumerId&&row.club_id===value.clubId&&row.envelope_sha256===digest,'idempotency_conflict');
    return row;
   };
   if(!await existing()){
    try{await this.db.prepare(`INSERT INTO adi_events(event_id,consumer_id,club_id,envelope_sha256,envelope_json,stored_at_ms)
     VALUES(?,?,?,?,?,${NOW_SQL})`).bind(value.eventId,value.consumerId,value.clubId,digest,encoded).run();}
    catch(error){await this.access(value.clubId);if(!await existing())throw error;}
   }
   await this.access(value.clubId);demand(await existing(),'delivery_unavailable');
   return {schemaVersion:1,consumerId:value.consumerId,eventId:value.eventId,receiptId:value.eventId,envelopeSha256:digest,
    stored:true,effect:'operations_inbox_record'};
  }catch(error){throw failure(error);}
 }
 async list(input){
  try{
   exact(input,['clubId','afterEventId','limit']);
   demand(club(input.clubId)&&(input.afterEventId===null||uuid(input.afterEventId))&&Number.isInteger(input.limit)&&input.limit>=1&&input.limit<=50);
   await this.access(input.clubId);
   const result=await this.db.withSession('first-primary').prepare(`SELECT event_id,envelope_json FROM adi_events
    WHERE club_id=? AND consumer_id=? AND event_id>? ORDER BY event_id LIMIT ?`).bind(input.clubId,this.env.DELIVERY_CONSUMER_ID,input.afterEventId??'',input.limit+1).all();
   const more=result.results.length>input.limit;
   const items=result.results.slice(0,input.limit).map(row=>envelope(JSON.parse(row.envelope_json)));
   demand(items.every(x=>x.clubId===input.clubId&&x.consumerId===this.env.DELIVERY_CONSUMER_ID),'invalid_event');
   await this.access(input.clubId);
   return {schemaVersion:1,clubId:input.clubId,items,nextAfterEventId:more?items.at(-1).eventId:null,snapshot:false};
  }catch(error){throw failure(error);}
 }
}
