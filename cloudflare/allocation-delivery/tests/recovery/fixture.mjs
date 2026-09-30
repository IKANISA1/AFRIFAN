import {readFileSync} from 'node:fs';
import {fixture,claimed,ids,TestD1,sourceEnv,CONSUMER,NOW} from '../fixture.mjs';
import {DeliveryRecovery} from '../../src/recovery.mjs';
import {NOW_SQL} from '../../src/policy.mjs';
export {TestD1,sourceEnv,ids,CONSUMER,NOW};
export const MAKER=ids.other,CHECKER='10000000-0000-4000-8000-000000000006',CHECKER2='10000000-0000-4000-8000-000000000007';
export async function recoveryFixture(){
 const f=await fixture();
 f.db.sql.exec(readFileSync(new URL('../../migrations_source/0007_approved_recovery.sql',import.meta.url),'utf8').replaceAll(NOW_SQL,'test_now_ms()'));
 f.db.sql.exec("UPDATE pa_recovery_control SET enabled=1,approval_ref='SYNTHETIC_NOT_APPROVAL'");
 for(const principal of [CHECKER,CHECKER2]){
  f.db.sql.prepare('INSERT INTO pa_principals VALUES(?,1,1,?)').run(principal,f.db.time+86400000);
  for(const clubId of [24,25]){
   f.db.sql.prepare("INSERT INTO pa_grants VALUES(?,?,'outbox',1,1)").run(principal,clubId);
   f.db.sql.prepare("INSERT INTO pa_delivery_grants VALUES(?,?,'review',1)").run(principal,clubId);
  }
 }
 const {claim}=await claimed(f);
 await f.source.finish({clubId:24,eventId:claim.eventId,leaseId:claim.leaseId,expectedRevision:claim.revision,requestId:crypto.randomUUID(),
  outcome:'dead',reason:'invalid_receipt',receiptId:null});
 const env={...f.env,ALLOCATION_RECOVERY_ENABLED:'true'};
 const request={clubId:24,eventId:claim.eventId,expectedRevision:claim.revision+1,decisionId:crypto.randomUUID(),operationId:crypto.randomUUID(),
  reason:'dependency_restored',evidenceSha256:'ab'.repeat(32),evidenceRef:'SYNTHETIC_TEST_REPAIR'};
 const confirm={clubId:request.clubId,decisionId:request.decisionId,operationId:request.operationId,expectedRevision:request.expectedRevision,evidenceSha256:request.evidenceSha256};
 return {...f,recoveryEnv:env,maker:new DeliveryRecovery(env,MAKER),checker:new DeliveryRecovery(env,CHECKER),checker2:new DeliveryRecovery(env,CHECKER2),request,confirm};
}
