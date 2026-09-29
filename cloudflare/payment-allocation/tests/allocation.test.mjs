import test from 'node:test';
import assert from 'node:assert/strict';
import {fixture,ready,ids} from './fixture.mjs';
const run=(name,fn)=>test(name,async t=>{const f=fixture();t.after(()=>f.close());await fn(f);});
run('one membership allocation creates matching immutable ledger, receipt, membership and outbox',async f=>{
 const input=await ready(f),r=await f.allocator.allocate(input);assert.equal(r.businessTargetFulfilled,true);assert.equal(r.amount,10000);
 for(const table of ['pa_allocations','pa_ledger','pa_receipts','pa_external_claims','pa_memberships','pa_outbox','pa_outbox_delivery'])assert.equal(f.count(table),1,table);
 assert.equal(f.db.sql.prepare('SELECT state FROM pa_orders').get().state,'fulfilled');
 assert.equal(f.db.sql.prepare('SELECT points FROM pa_memberships').get().points,0);
 assert.deepEqual(await f.reader.readReceipt({clubId:24,orderId:f.order.order_id}),r);
});
run('ingestion alone cannot mark a pending order or activate membership',async f=>{await ready(f);assert.equal(f.count('pa_memberships'),0);assert.equal(f.count('pa_ledger'),0);assert.equal(f.db.sql.prepare('SELECT state FROM pa_orders').get().state,'pending');});
run('identical request retry replays exactly one receipt and entitlement',async f=>{const i=await ready(f),a=await f.allocator.allocate(i);assert.deepEqual(await f.allocator.allocate(i),a);assert.equal(f.count('pa_commands'),2);});
run('same binding with a different request key still cannot renew twice',async f=>{const i=await ready(f),a=await f.allocator.allocate(i);assert.deepEqual(await f.allocator.allocate({...i,requestId:crypto.randomUUID()}),a);assert.equal(f.count('pa_allocations'),1);});
run('a reused request key cannot select a different order',async f=>{const i=await ready(f);await f.allocator.allocate(i);const other=f.createOrder();await assert.rejects(f.allocator.allocate({...i,orderId:other.order_id}),{code:'idempotency_conflict'});});
run('completed receipt survives current receiver changes and expiry',async f=>{const i=await ready(f),r=await f.allocator.allocate(i);f.db.sql.exec("UPDATE pa_receivers SET active=0,recipient='999999'");f.advance(2*86400000);assert.deepEqual(await f.allocator.allocate(i),r);});
run('receipt is a historical snapshot rather than a rewritten current membership',async f=>{const i=await ready(f),r=await f.allocator.allocate(i);f.db.sql.exec("UPDATE pa_memberships SET status='suspended'");assert.deepEqual(await f.reader.readReceipt({clubId:24,orderId:f.order.order_id}),r);});
run('suspended membership stays suspended and retains points, ID, code and number',async f=>{const m=f.membership({status:'suspended'});const i=await ready(f),r=await f.allocator.allocate(i);const next=f.db.sql.prepare('SELECT * FROM pa_memberships').get();assert.equal(r.membership.status,'suspended');for(const k of ['membership_id','member_code','membership_number','points','partner_id'])assert.equal(next[k],m[k]);assert.equal(next.payment_status,'verified');});
run('same-tier renewal extends a still-valid entitlement from its expiry',async f=>{const m=f.membership();const i=await ready(f),r=await f.allocator.allocate(i);const expected=new Date(m.expires_at_ms);expected.setUTCFullYear(expected.getUTCFullYear()+1);assert.equal(r.membership.expiresAt,expected.getTime());});
run('expired same-tier membership renews from transaction time',async f=>{f.membership({status:'expired',expires_at_ms:f.db.time-1});const r=await f.allocator.allocate(await ready(f));assert.equal(r.membership.expiresAt,Date.UTC(2027,8,26,14,0,0,123));});
run('tier change begins one new year, not an extension of the old tier',async f=>{f.membership({tier:'silver',expires_at_ms:f.db.time+90*86400000});const r=await f.allocator.allocate(await ready(f));assert.equal(r.membership.expiresAt,Date.UTC(2027,8,26,14,0,0,123));assert.equal(r.membership.tier,'gold');});
run('calendar-year renewal clamps leap day and preserves milliseconds',async f=>{
 const leap=Date.UTC(2028,1,29,11,22,33,456);f.membership({expires_at_ms:leap});const r=await f.allocator.allocate(await ready(f));assert.equal(r.membership.expiresAt,Date.UTC(2029,1,28,11,22,33,456));
});
run('contribution allocation remains business-pending without fake rewards or totals',async f=>{
 const order=f.createOrder({kind:'contribution',tier:null,initiative_id:crypto.randomUUID(),expires_at_ms:null});
 const e=f.evidence(order);e.parsed.rawId=e.raw.id;await f.ingestion.ingest(e);const r=await f.allocator.allocate(f.allocation(e,order));
 assert.equal(r.businessTargetFulfilled,false);assert.equal(r.membership,null);assert.equal(f.count('pa_memberships'),0);
 assert.equal(f.db.sql.prepare('SELECT business_target_fulfilled FROM pa_ledger').get().business_target_fulfilled,0);
 assert.equal(JSON.parse(f.db.sql.prepare('SELECT payload_json FROM pa_outbox').get().payload_json).businessTargetFulfilled,false);
});
for(const [name,change] of [
 ['amount',e=>e.parsed.amount++],['currency',e=>e.parsed.currency='USD'],['recipient',e=>e.parsed.recipient='999999'],['provider',e=>e.raw.provider='other_provider'],
 ['country',e=>{e.raw.country='ZM';e.parsed.country='ZM';}]
])run(`new allocation rejects ${name} mismatch without any posted effect`,async f=>{change(f.input);const i=await ready(f);await assert.rejects(f.allocator.allocate(i),{code:'binding_conflict'});assert.equal(f.count('pa_allocations'),0);assert.equal(f.count('pa_external_claims'),0);});
run('wrong user evidence cannot pay another users order',async f=>{
 const user=crypto.randomUUID();f.db.sql.prepare('INSERT INTO pa_subjects VALUES(?,24,1,1)').run(user);f.input.raw.userId=user;f.input.parsed.userId=user;
 await assert.rejects(f.allocator.allocate(await ready(f)),{code:'binding_conflict'});
});
run('wrong club is denied even when service has grants for both clubs',async f=>{const i=await ready(f);await assert.rejects(f.allocator.allocate({...i,clubId:25}),{code:'binding_conflict'});});
for(const [name,sql] of [
 ['disabled receiver','UPDATE pa_receivers SET active=0'],['changed receiver','UPDATE pa_receivers SET recipient=\'333333\''],
 ['disabled subject','UPDATE pa_subjects SET enabled=0'],['cancelled order',"UPDATE pa_orders SET state='cancelled'"]
])run(`${name} prevents a new allocation`,async f=>{const i=await ready(f);f.db.sql.exec(sql);await assert.rejects(f.allocator.allocate(i),{code:'binding_conflict'});assert.equal(f.count('pa_memberships'),0);});
run('expiry is tested at the write boundary after a simulated wait',async f=>{const i=await ready(f);f.db.beforeBatch=()=>{f.db.time=f.order.expires_at_ms;};await assert.rejects(f.allocator.allocate(i),{code:'binding_conflict'});assert.equal(f.count('pa_ledger'),0);});
run('a historical provider transaction cannot be spent again',async f=>{const i=await ready(f);f.db.sql.prepare("INSERT INTO pa_external_claims VALUES(?,?,'historical','SOURCE-LEDGER',?)").run('mtn_rwanda',f.input.parsed.providerReference,'c3'.repeat(32));await assert.rejects(f.allocator.allocate(i),{code:'transaction_already_used'});assert.equal(f.count('pa_ledger'),0);});
run('different evidence IDs for the same provider transaction cannot fund two orders',async f=>{
 const i=await ready(f);await f.allocator.allocate(i);const o=f.createOrder();const e=f.evidence(o);e.parsed.rawId=e.raw.id;e.parsed.providerReference=f.input.parsed.providerReference;
 await f.ingestion.ingest(e);await assert.rejects(f.allocator.allocate(f.allocation(e,o)),{code:'transaction_already_used'});assert.equal(f.count('pa_allocations'),1);
});
run('global transaction uniqueness also holds across two clubs',async f=>{
 await f.allocator.allocate(await ready(f));const receiver=crypto.randomUUID();f.db.sql.prepare('INSERT INTO pa_receivers VALUES(?,25,?,?,?,?,?,1,1)').run(receiver,ids.partner,'mtn_rwanda','RW','RWF','654321');
 const o=f.createOrder({club_id:25,receiver_id:receiver,recipient:'654321'});const e=f.evidence(o);e.parsed.rawId=e.raw.id;e.parsed.providerReference=f.input.parsed.providerReference;
 await f.ingestion.ingest(e);await assert.rejects(f.allocator.allocate(f.allocation(e,o)),{code:'transaction_already_used'});assert.equal(f.count('pa_allocations'),1);
});
run('direct fulfilled-state write without receipt is refused',async f=>{assert.throws(()=>f.db.sql.exec("UPDATE pa_orders SET state='fulfilled'"),/pa_receipt_required/);});
run('economic order snapshots cannot be edited in place',async f=>{assert.throws(()=>f.db.sql.exec('UPDATE pa_orders SET amount=1'),/pa_immutable_order/);});
for(const table of ['pa_allocations','pa_ledger','pa_receipts','pa_external_claims','pa_outbox'])run(`${table} cannot be updated or deleted after posting`,async f=>{
 await f.allocator.allocate(await ready(f));const first=f.db.sql.prepare(`PRAGMA table_info(${table})`).all()[0].name;
 assert.throws(()=>f.db.sql.exec(`UPDATE ${table} SET ${first}=${first}`),/pa_immutable_evidence/);assert.throws(()=>f.db.sql.exec(`DELETE FROM ${table}`),/pa_immutable_evidence/);
});
