import {PaymentAllocationService} from './service.mjs';
import {NOW_SQL,exact,demand,club,uuid,safeError} from './policy.mjs';
/** No network send here. Consumers deduplicate by eventId before applying effects. */
export class AllocationOutbox extends PaymentAllocationService {
  async claim(input) {
    try {
      exact(input,['clubId','limit']); demand(club(input.clubId)&&Number.isInteger(input.limit)&&input.limit>=1&&input.limit<=20);
      await this.authority(input.clubId,'outbox'); const leaseId=crypto.randomUUID();
      await this.statement(`UPDATE pa_outbox_delivery SET state='leased',lease_id=?,lease_principal=?,lease_until_ms=${NOW_SQL}+60000,attempts=attempts+1
        WHERE event_id IN (SELECT event_id FROM pa_outbox_delivery WHERE club_id=? AND (state='pending' OR (state='leased' AND lease_until_ms<=${NOW_SQL}))
          ORDER BY event_id LIMIT ?)`,leaseId,this.principalId,input.clubId,input.limit).run();
      await this.authority(input.clubId,'outbox');
      const result=await this.db.withSession('first-primary').prepare(`SELECT d.event_id,d.lease_id,d.lease_until_ms,o.event_type,o.payload_json
        FROM pa_outbox_delivery d JOIN pa_outbox o ON o.event_id=d.event_id
        WHERE d.club_id=? AND d.lease_id=? AND d.lease_principal=? AND d.state='leased' ORDER BY d.event_id LIMIT 20`)
        .bind(input.clubId,leaseId,this.principalId).all();
      return {schemaVersion:1,clubId:input.clubId,events:result.results.map(row=>({eventId:row.event_id,leaseId:row.lease_id,leaseUntil:row.lease_until_ms,eventType:row.event_type,payload:JSON.parse(row.payload_json)}))};
    }catch(error){throw safeError(error);}
  }
  async acknowledge(input) {
    try {
      exact(input,['clubId','eventId','leaseId']); demand(club(input.clubId)&&uuid(input.eventId)&&uuid(input.leaseId));
      await this.authority(input.clubId,'outbox');
      const read=()=>this.first('SELECT * FROM pa_outbox_delivery WHERE event_id=? AND club_id=?',input.eventId,input.clubId);
      const before=await read(); demand(before,'not_found');
      if(before.state==='delivered'){
        demand(before.acknowledged_lease===input.leaseId&&before.lease_principal===this.principalId,'outbox_conflict');
        await this.authority(input.clubId,'outbox'); return {schemaVersion:1,eventId:input.eventId,acknowledged:true};
      }
      try {
        const changed=await this.statement(`UPDATE pa_outbox_delivery SET state='delivered',acknowledged_lease=lease_id,lease_id=NULL,lease_until_ms=NULL,delivered_at_ms=${NOW_SQL}
          WHERE event_id=? AND club_id=? AND state='leased' AND lease_id=? AND lease_principal=? AND lease_until_ms>${NOW_SQL}`,
          input.eventId,input.clubId,input.leaseId,this.principalId).run();
        demand(changed.meta?.changes===1,'outbox_conflict');
      }catch(error){
        await this.authority(input.clubId,'outbox'); const after=await read();
        if(!(after?.state==='delivered'&&after.acknowledged_lease===input.leaseId&&after.lease_principal===this.principalId))throw error;
      }
      await this.authority(input.clubId,'outbox'); return {schemaVersion:1,eventId:input.eventId,acknowledged:true};
    }catch(error){throw safeError(error);}
  }
}
