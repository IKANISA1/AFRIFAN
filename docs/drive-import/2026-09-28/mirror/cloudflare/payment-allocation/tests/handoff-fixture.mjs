import {readFileSync} from 'node:fs';
import {checkoutFixture,ids,NOW} from './checkout-fixture.mjs';
import {NOW_SQL} from '../src/policy.mjs';
import {ServerHandoffService,reviewHash} from '../src/handoff-service.mjs';
export {ids,NOW};
export const reservePrincipal='10000000-0000-4000-8000-000000000010';
export const recoveryPrincipal='10000000-0000-4000-8000-000000000011';
export function installHandoff(f){
 f.db.sql.exec(readFileSync(new URL('../migrations/0003_server_handoff_recovery.sql',import.meta.url),'utf8').replaceAll(NOW_SQL,'test_now_ms()'));
 f.env.SERVER_HANDOFF_ENABLED='true';
 f.db.sql.exec("UPDATE pa_handoff_settings SET enabled=1,legacy_attempts_reconciled=1,evidence_ref='SYNTHETIC-NOT-APPROVAL';");
 for(const [principal,cap] of [[reservePrincipal,'reserve'],[recoveryPrincipal,'read']]){
  f.db.sql.prepare('INSERT INTO pa_principals VALUES(?,1,1,?)').run(principal,NOW+7*86400000);
  for(const club of [24,25]) f.db.sql.prepare('INSERT INTO pa_handoff_grants VALUES(?,?,?,1,1)').run(principal,club,cap);
 }
 const reserve=new ServerHandoffService(f.env,reservePrincipal),recovery=new ServerHandoffService(f.env,recoveryPrincipal);
 return {reserve,recovery};
}
export async function handoffFixture(t){
 const f=checkoutFixture();t.after(()=>f.close());Object.assign(f,installHandoff(f));
 const originalRequest=f.request(),checkout=await f.checkout.prepare(originalRequest),snapshot=checkout.checkout;
 const request={clubId:24,userId:ids.user,sessionId:crypto.randomUUID(),requestId:crypto.randomUUID(),orderId:snapshot.orderId,reviewHash:await reviewHash(snapshot)};
 const allocate=async(id=snapshot.orderId)=>{const o=f.db.sql.prepare('SELECT * FROM pa_orders WHERE order_id=?').get(id),e=f.evidence(o);e.parsed.rawId=e.raw.id;await f.ingestion.ingest(e);return f.allocator.allocate(f.allocation(e,o));};
 return {...f,originalRequest,prepared:checkout,snapshot,handoffRequest:request,active:()=>f.recovery.active({clubId:24,userId:ids.user}),allocate};
}
