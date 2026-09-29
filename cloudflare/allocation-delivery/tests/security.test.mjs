import test from 'node:test';import assert from 'node:assert/strict';
import {fixture,claimed,ids,CONSUMER} from './fixture.mjs';
import {DeliverySource} from '../src/source.mjs';import {AllocationInbox} from '../src/inbox.mjs';import {drain} from '../src/dispatcher.mjs';
const deny=(fn,code)=>assert.rejects(fn,e=>e.code===code);
async function use(t,fn){const f=await fixture();t.after(()=>f.close());await fn(f);}
for(const [name,change] of [
 ['principal',f=>f.db.sql.prepare('UPDATE pa_principals SET enabled=0 WHERE principal_id=?').run(ids.outbox)],
 ['grant',f=>f.db.sql.prepare("UPDATE pa_grants SET enabled=0 WHERE principal_id=? AND capability='outbox'").run(ids.outbox)],
 ['role',f=>f.db.sql.exec("UPDATE pa_delivery_grants SET enabled=0 WHERE role='dispatch'")],
 ['club',f=>f.db.sql.exec('UPDATE pa_clubs SET enabled=0 WHERE club_id=24')],
 ['control',f=>f.db.sql.exec('UPDATE pa_delivery_control SET enabled=0 WHERE club_id=24')],
 ['expiry',f=>f.db.sql.prepare('UPDATE pa_principals SET expires_at_ms=? WHERE principal_id=?').run(f.db.time,ids.outbox)],
 ['reconciliation',f=>f.db.sql.exec('UPDATE pa_settings SET historical_claims_verified=0')]
])test(`source denies revoked ${name} and creates no job`,t=>use(t,async f=>{change(f);await deny(()=>f.source.take({clubId:24}),'permission_denied');assert.equal(f.count('pa_delivery_jobs'),0);}));
test('revocation after JavaScript read is checked inside command trigger',t=>use(t,async f=>{
 f.db.beforeRun=()=>f.db.sql.exec("UPDATE pa_delivery_grants SET enabled=0 WHERE role='dispatch'");
 await deny(()=>f.source.take({clubId:24}),'permission_denied');assert.equal(f.count('pa_delivery_commands'),0);
}));
for(const [name,change] of [
 ['runtime flag',f=>{f.sinkEnv.INBOX_ENABLED='false';}],
 ['consumer control',f=>f.sinkDb.sql.exec('UPDATE adi_control SET enabled=0')],
 ['club control',f=>f.sinkDb.sql.exec('UPDATE adi_clubs SET enabled=0 WHERE club_id=24')]
])test(`receiver denies ${name}`,t=>use(t,async f=>{const {event}=await claimed(f);change(f);await assert.rejects(()=>f.sink.accept(event));assert.equal(f.sinkDb.sql.prepare('SELECT count(*) n FROM adi_events').get().n,0);}));
test('receiver mutation-time revocation rejects insert',t=>use(t,async f=>{
 const {event}=await claimed(f);f.sinkDb.beforeRun=()=>f.sinkDb.sql.exec('UPDATE adi_control SET enabled=0');
 await deny(()=>f.sink.accept(event),'permission_denied');assert.equal(f.sinkDb.sql.prepare('SELECT count(*) n FROM adi_events').get().n,0);
}));
test('receiver rechecks authorization after durable insert; no false accepted response',t=>use(t,async f=>{
 const {event}=await claimed(f);f.sinkDb.afterRun=()=>f.sinkDb.sql.exec('UPDATE adi_control SET enabled=0');
 await deny(()=>f.sink.accept(event),'permission_denied');assert.equal(f.sinkDb.sql.prepare('SELECT count(*) n FROM adi_events').get().n,1);
}));
test('receiver exact replay has identical receipt; altered payload cannot replace record',t=>use(t,async f=>{
 const {event}=await claimed(f),result=await f.sink.accept(event);assert.deepEqual(await f.sink.accept(event),result);
 await deny(()=>f.sink.accept({...event,userId:crypto.randomUUID()}),'idempotency_conflict');
 await deny(()=>f.sink.accept({...event,clubId:25}),'idempotency_conflict');
 await deny(()=>f.sink.accept({...event,consumerId:crypto.randomUUID()}),'permission_denied');
}));
for(const patch of [{phone:'+250700000000'},{rawSms:'do not retain'},{schemaVersion:2},{allocationRecorded:false},{businessTargetFulfilled:false},{recordedAt:NaN},{eventId:'not-uuid'}])
 test(`receiver rejects malformed envelope ${Object.keys(patch)[0]}`,t=>use(t,async f=>{const {event}=await claimed(f);await assert.rejects(()=>f.sink.accept({...event,...patch}));}));
for(const input of [{clubId:0},{clubId:'24'},{clubId:24,userId:ids.user},{clubId:NaN}])test(`source rejects bad request ${JSON.stringify(input)}`,t=>use(t,async f=>{await deny(()=>f.source.take(input),'invalid_request');assert.equal(f.count('pa_delivery_jobs'),0);}));
for(const patch of [{DELIVERY_DISPATCH_ENABLED:'false'},{DELIVERY_ENVIRONMENT:'production'},{DELIVERY_CLUB_IDS:'[24,24]'},
 {DELIVERY_CLUB_IDS:'[]'},{DELIVERY_CLUB_IDS:'[1,2,3,4,5,6]'},{DELIVERY_TIMEOUT_MS:'0'},{DELIVERY_TIMEOUT_MS:'5000'},{INBOX:null},{SOURCE:null}])
 test(`dispatcher rejects unsafe configuration ${JSON.stringify(patch)}`,t=>use(t,async f=>{await assert.rejects(()=>drain({...f.runner,...patch}));assert.equal(f.count('pa_delivery_jobs'),0);}));
test('source and inbox entrypoints remain disabled without explicit runtime gates',t=>use(t,async f=>{
 assert.throws(()=>new DeliverySource({...f.env,ALLOCATION_DELIVERY_ENABLED:'false'},ids.outbox));
 assert.throws(()=>new AllocationInbox({...f.sinkEnv,INBOX_ENABLED:'false'}));
}));
test('private inbox pagination scopes every result and is read-only',t=>use(t,async f=>{
 await f.addOrder();await drain(f.runner);await drain(f.runner);
 const first=await f.sink.list({clubId:24,afterEventId:null,limit:1});assert.ok(first.nextAfterEventId);
 const second=await f.sink.list({clubId:24,afterEventId:first.nextAfterEventId,limit:1});assert.equal(second.nextAfterEventId,null);
 assert.notEqual(first.items[0].eventId,second.items[0].eventId);
 assert.deepEqual((await f.sink.list({clubId:25,afterEventId:null,limit:5})).items,[]);
}));
test('immutable source and consumer evidence reject updates and deletes',t=>use(t,async f=>{
 await drain(f.runner);
 for(const table of ['pa_delivery_commands','pa_delivery_jobs','pa_outbox','pa_receipts','pa_ledger'])assert.throws(()=>f.db.sql.exec(`DELETE FROM ${table}`));
 assert.throws(()=>f.db.sql.exec("UPDATE pa_delivery_jobs SET state='pending'"));
 assert.throws(()=>f.sinkDb.sql.exec('DELETE FROM adi_events'));assert.throws(()=>f.sinkDb.sql.exec("UPDATE adi_events SET envelope_json='{}'"));
}));
test('wrong lease and stale revision cannot acknowledge an event',t=>use(t,async f=>{
 const {claim}=await claimed(f);
 const input={clubId:24,eventId:claim.eventId,leaseId:claim.leaseId,expectedRevision:claim.revision,requestId:crypto.randomUUID(),outcome:'delivered',reason:'none',receiptId:claim.eventId};
 await deny(()=>f.source.finish({...input,leaseId:crypto.randomUUID()}),'conflict');
 await deny(()=>f.source.finish({...input,expectedRevision:claim.revision-1}),'conflict');
 f.advance(10000);await deny(()=>f.source.finish(input),'conflict');
}));
test('unrecognized infrastructure errors never expose SQL or private diagnostics',t=>use(t,async f=>{
 f.db.beforeRun=()=>{throw Error('private phone token SELECT pa_receipts');};
 await assert.rejects(()=>f.source.take({clubId:24}),e=>e.code==='delivery_unavailable'&&!e.message.includes('private'));
}));
