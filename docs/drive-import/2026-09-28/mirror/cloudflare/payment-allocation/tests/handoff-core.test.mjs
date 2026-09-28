import test from 'node:test';import assert from 'node:assert/strict';
import {handoffFixture,ids,reservePrincipal,recoveryPrincipal} from './handoff-fixture.mjs';
import {ServerHandoffService,reviewHash} from '../src/handoff-service.mjs';
const denied=promise=>assert.rejects(promise);
test('fresh reservation creates one audit/slot, never a payment or entitlement',async t=>{
 const f=await handoffFixture(t),v=await f.reserve.reserve(f.handoffRequest);
 assert.equal(v.firstDelivery,true);assert.equal(v.mayInvokeDialer,true);assert.equal(v.validForMs,5000);
 for(const table of ['pa_handoff_reservations','pa_handoff_slots','pa_handoff_audit'])assert.equal(f.count(table),1);
 for(const table of ['pa_allocations','pa_memberships','pa_ledger','pa_outbox'])assert.equal(f.count(table),0);
 assert.equal((await f.active()).blocked,true);
});
test('empty server slot allows an initial attempt',async t=>{const f=await handoffFixture(t);assert.deepEqual(await f.active(),{schemaVersion:1,clubId:24,blocked:false,handoff:null});});
test('exact retry never grants dialer access twice',async t=>{const f=await handoffFixture(t),a=await f.reserve.reserve(f.handoffRequest),b=await f.reserve.reserve(f.handoffRequest);
 assert.equal(b.handoffId,a.handoffId);assert.equal(b.firstDelivery,false);assert.equal(b.mayInvokeDialer,false);assert.equal(b.validForMs,0);assert.equal(f.count('pa_handoff_audit'),1);});
test('new session can recover original key but cannot relaunch',async t=>{const f=await handoffFixture(t);await f.reserve.reserve(f.handoffRequest);const v=await f.reserve.reserve({...f.handoffRequest,sessionId:crypto.randomUUID()});assert.equal(v.mayInvokeDialer,false);});
test('changed same key conflicts',async t=>{const f=await handoffFixture(t);await f.reserve.reserve(f.handoffRequest);await denied(f.reserve.reserve({...f.handoffRequest,reviewHash:'f'.repeat(64)}));});
test('new key on a reserved order stays blocked',async t=>{const f=await handoffFixture(t);await f.reserve.reserve(f.handoffRequest);await denied(f.reserve.reserve({...f.handoffRequest,requestId:crypto.randomUUID()}));assert.equal(f.count('pa_handoff_reservations'),1);});
test('expired order and grant do not clear pending state',async t=>{const f=await handoffFixture(t);await f.reserve.reserve(f.handoffRequest);f.advance(86400001);assert.equal((await f.active()).blocked,true);assert.equal((await f.reserve.reserve(f.handoffRequest)).mayInvokeDialer,false);});
test('privileged order cancellation is not proof of no payment',async t=>{const f=await handoffFixture(t);await f.reserve.reserve(f.handoffRequest);f.db.sql.prepare("UPDATE pa_orders SET state='cancelled' WHERE order_id=?").run(f.snapshot.orderId);assert.equal((await f.active()).blocked,true);});
test('offer change after reservation does not clear the blocker',async t=>{const f=await handoffFixture(t);await f.reserve.reserve(f.handoffRequest);f.db.sql.exec('UPDATE pa_checkout_packages SET price=price+1');assert.equal((await f.active()).blocked,true);});
test('new checkout cannot cancel a reserved payment',async t=>{const f=await handoffFixture(t);await f.reserve.reserve(f.handoffRequest);await denied(f.checkout.prepare(f.request()));assert.equal(f.orderFor(f.prepared).state,'pending');});
test('original checkout recovery is still read-only and works',async t=>{const f=await handoffFixture(t);await f.reserve.reserve(f.handoffRequest);const old=await f.checkout.prepare(f.originalRequest);assert.equal(old.checkout.orderId,f.snapshot.orderId);assert.equal(f.count('pa_checkout_requests'),1);});
test('disabling handoff does not let checkout bypass existing reservations',async t=>{const f=await handoffFixture(t);await f.reserve.reserve(f.handoffRequest);f.db.sql.exec('UPDATE pa_handoff_settings SET enabled=0');await denied(f.checkout.prepare(f.request()));});
test('authoritative allocation resolves the blocker and permits a later order',async t=>{
 const f=await handoffFixture(t);const first=await f.reserve.reserve(f.handoffRequest);await f.allocate();assert.equal((await f.active()).blocked,false);
 const c=await f.checkout.prepare(f.request());const second=await f.reserve.reserve({...f.handoffRequest,orderId:c.checkout.orderId,requestId:crypto.randomUUID(),reviewHash:await reviewHash(c.checkout)});
 assert.notEqual(first.handoffId,second.handoffId);assert.equal(second.mayInvokeDialer,true);assert.equal(f.count('pa_memberships'),1);assert.equal(f.count('pa_handoff_reservations'),2);
});
test('suspended member stays suspended after resolving allocated payment',async t=>{const f=await handoffFixture(t);f.membership({status:'suspended'});await f.reserve.reserve(f.handoffRequest);await f.allocate();assert.equal((await f.active()).blocked,false);assert.equal(f.db.sql.prepare('SELECT status FROM pa_memberships').get().status,'suspended');});
test('lost insert acknowledgement recovers evidence without grant',async t=>{const f=await handoffFixture(t);f.db.loseBatch=true;const v=await f.reserve.reserve(f.handoffRequest);assert.equal(v.firstDelivery,false);assert.equal(v.mayInvokeDialer,false);assert.equal(f.count('pa_handoff_reservations'),1);});
test('invalid acknowledgement does not become launch authority',async t=>{const f=await handoffFixture(t),batch=f.db.batch.bind(f.db);f.db.batch=async s=>{await batch(s);return [{success:true,meta:{changes:0}}];};assert.equal((await f.reserve.reserve(f.handoffRequest)).mayInvokeDialer,false);});
test('commit delayed beyond launch window retains non-launchable record',async t=>{const f=await handoffFixture(t);f.db.afterCommit=()=>f.advance(5001);const v=await f.reserve.reserve(f.handoffRequest);assert.equal(v.firstDelivery,true);assert.equal(v.mayInvokeDialer,false);assert.equal(v.validForMs,0);});
test('allocation immediately after reservation prevents dialer grant',async t=>{const f=await handoffFixture(t);const batch=f.db.batch.bind(f.db);let once=true;f.db.batch=async s=>{const r=await batch(s);if(once){once=false;await f.allocate();}return r;};assert.equal((await f.reserve.reserve(f.handoffRequest)).mayInvokeDialer,false);});
for(const column of ['orderId','userId','sessionId','requestId'])test('reject malformed '+column,async t=>{const f=await handoffFixture(t);await denied(f.reserve.reserve({...f.handoffRequest,[column]:'../invalid'}));assert.equal(f.count('pa_handoff_reservations'),0);});
for(const field of ['actor','amount','provider','recipient','mayInvokeDialer'])test('reject injected '+field,async t=>{const f=await handoffFixture(t);await denied(f.reserve.reserve({...f.handoffRequest,[field]:true}));assert.equal(f.count('pa_handoff_reservations'),0);});
for(const value of [null,'',-1,0,1.5,'24'])test('invalid club '+JSON.stringify(value),async t=>{const f=await handoffFixture(t);await denied(f.reserve.reserve({...f.handoffRequest,clubId:value}));});
for(const value of ['0'.repeat(63),'g'.repeat(64),'A'.repeat(64),null])test('invalid review digest '+String(value).slice(0,8),async t=>{const f=await handoffFixture(t);await denied(f.reserve.reserve({...f.handoffRequest,reviewHash:value}));});
test('wrong user cannot reserve or discover another active order',async t=>{const f=await handoffFixture(t),other=crypto.randomUUID();f.db.sql.prepare('INSERT INTO pa_subjects(user_id,club_id,enabled) VALUES(?,24,1)').run(other);await f.reserve.reserve(f.handoffRequest);assert.equal((await f.recovery.active({clubId:24,userId:other})).handoff,null);await denied(f.reserve.reserve({...f.handoffRequest,userId:other,requestId:crypto.randomUUID()}));});
test('wrong club cannot borrow an order',async t=>{const f=await handoffFixture(t);await denied(f.reserve.reserve({...f.handoffRequest,clubId:25}));});
test('read principal cannot reserve',async t=>{const f=await handoffFixture(t);await denied(new ServerHandoffService(f.env,recoveryPrincipal).reserve(f.handoffRequest));});
test('reserve principal cannot use recovery read',async t=>{const f=await handoffFixture(t);await denied(f.reserve.active({clubId:24,userId:ids.user}));});
for(const sql of [
 'UPDATE pa_handoff_settings SET enabled=0',
 'UPDATE pa_handoff_settings SET legacy_attempts_reconciled=0',
 "UPDATE pa_handoff_settings SET evidence_ref=''",
 'UPDATE pa_checkout_settings SET enabled=0',
 "UPDATE pa_settings SET writer_mode='disabled'",
 'UPDATE pa_subjects SET enabled=0 WHERE club_id=24',
 'UPDATE pa_clubs SET enabled=0 WHERE club_id=24',
 `UPDATE pa_principals SET enabled=0 WHERE principal_id='${reservePrincipal}'`,
 `UPDATE pa_principals SET expires_at_ms=0 WHERE principal_id='${reservePrincipal}'`,
 "UPDATE pa_handoff_grants SET enabled=0 WHERE club_id=24 AND capability='reserve'"
])test('control rejects '+sql,async t=>{const f=await handoffFixture(t);if(sql.includes('expires_at_ms=0'))f.db.sql.exec(sql.replace('expires_at_ms=0','expires_at_ms=1'));else f.db.sql.exec(sql);await denied(f.reserve.reserve(f.handoffRequest));assert.equal(f.count('pa_handoff_reservations'),0);});
for(const sql of [
 "UPDATE pa_handoff_grants SET enabled=0 WHERE club_id=24 AND capability='reserve'",
 'UPDATE pa_subjects SET enabled=0 WHERE club_id=24',
 'UPDATE pa_clubs SET enabled=0 WHERE club_id=24',
 'UPDATE pa_handoff_settings SET enabled=0',
 'UPDATE pa_checkout_settings SET enabled=0',
 'UPDATE pa_checkout_packages SET annual_price=annual_price+1'
])test('commit-time race '+sql,async t=>{const f=await handoffFixture(t);f.db.beforeBatch=()=>f.db.sql.exec(sql);await denied(f.reserve.reserve(f.handoffRequest));assert.equal(f.count('pa_handoff_reservations'),0);});
test('revoke then reenable grant cannot revive pending authority revision',async t=>{const f=await handoffFixture(t);f.db.beforeBatch=()=>f.db.sql.exec("UPDATE pa_handoff_grants SET enabled=0 WHERE club_id=24 AND capability='reserve';UPDATE pa_handoff_grants SET enabled=1 WHERE club_id=24 AND capability='reserve';");await denied(f.reserve.reserve(f.handoffRequest));});
for(const table of ['pa_handoff_slots','pa_handoff_audit'])test('trigger failure at '+table+' rolls back reservation',async t=>{const f=await handoffFixture(t);f.db.sql.exec(`CREATE TRIGGER fail_effect BEFORE INSERT ON ${table} BEGIN SELECT RAISE(ABORT,'synthetic_fault'); END;`);await denied(f.reserve.reserve(f.handoffRequest));for(const x of ['pa_handoff_slots','pa_handoff_audit','pa_handoff_reservations'])assert.equal(f.count(x),0);});
test('batch failure writes no marker',async t=>{const f=await handoffFixture(t);f.db.failAt=0;await denied(f.reserve.reserve(f.handoffRequest));assert.equal(f.count('pa_handoff_reservations'),0);});
test('authority changed by an effect trigger rolls back everything',async t=>{const f=await handoffFixture(t);f.db.sql.exec("CREATE TRIGGER mutate_after_audit AFTER INSERT ON pa_handoff_audit BEGIN UPDATE pa_handoff_grants SET enabled=0 WHERE club_id=24 AND capability='reserve'; END;");await denied(f.reserve.reserve(f.handoffRequest));assert.equal(f.count('pa_handoff_reservations'),0);assert.equal(f.db.sql.prepare("SELECT enabled FROM pa_handoff_grants WHERE principal_id=? AND club_id=24").get(reservePrincipal).enabled,1);});
for(const table of ['pa_handoff_reservations','pa_handoff_slots','pa_handoff_audit'])test('cannot delete '+table,async t=>{const f=await handoffFixture(t);await f.reserve.reserve(f.handoffRequest);assert.throws(()=>f.db.sql.exec(`DELETE FROM ${table}`));});
for(const table of ['pa_handoff_reservations','pa_handoff_audit'])test('cannot edit '+table,async t=>{const f=await handoffFixture(t);await f.reserve.reserve(f.handoffRequest);assert.throws(()=>f.db.sql.exec(`UPDATE ${table} SET handoff_id='rewritten'`));});
test('corrupt/missing live authority blocks replay disclosure',async t=>{const f=await handoffFixture(t);await f.reserve.reserve(f.handoffRequest);f.db.sql.exec('UPDATE pa_subjects SET enabled=0 WHERE club_id=24');await denied(f.reserve.reserve(f.handoffRequest));});
test('read output has no token session identity or payment instructions',async t=>{const f=await handoffFixture(t);await f.reserve.reserve(f.handoffRequest);const text=JSON.stringify(await f.active());for(const x of ['userId','sessionId','ussd','recipient','amount',ids.user,f.handoffRequest.sessionId])assert.ok(!text.includes(x));});
test('reserve rejects a stale quote without creating a claim',async t=>{const f=await handoffFixture(t);await denied(f.reserve.reserve({...f.handoffRequest,reviewHash:'e'.repeat(64)}));assert.equal(f.count('pa_handoff_reservations'),0);});
test('already allocated order cannot be reserved',async t=>{const f=await handoffFixture(t);await f.allocate();await denied(f.reserve.reserve(f.handoffRequest));});
test('last nineteen seconds cannot begin a handoff',async t=>{const f=await handoffFixture(t);f.advance(86400000-19999);await denied(f.reserve.reserve(f.handoffRequest));});
test('read does not mutate recovery tables',async t=>{const f=await handoffFixture(t);await f.reserve.reserve(f.handoffRequest);const changes=f.db.sql.prepare('SELECT total_changes() n').get().n;await f.active();await f.active();assert.equal(f.db.sql.prepare('SELECT total_changes() n').get().n,changes);});

test('backward database time does not extend the original first launch grant',async t=>{const f=await handoffFixture(t);f.db.afterCommit=()=>f.advance(-1000);const result=await f.reserve.reserve(f.handoffRequest);assert.equal(result.mayInvokeDialer,false);assert.equal(result.validForMs,0);});
