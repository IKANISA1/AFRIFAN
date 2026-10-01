import test from 'node:test';
import assert from 'node:assert/strict';
import {claimed,ids,CONSUMER} from './fixture.mjs';
import {drain} from '../src/dispatcher.mjs';
import {withTransportClock,deferred,expireTransportDeadline} from './transport-clock.mjs';
const fail=(f,c)=>assert.rejects(f,e=>e.code===c);
const scope={clubId:24,state:'dead',afterEventId:null,limit:50};
const finish=(f,c,patch={})=>f.source.finish({clubId:24,eventId:c.eventId,leaseId:c.leaseId,expectedRevision:c.revision,requestId:crypto.randomUUID(),outcome:'retry',reason:'sink_unavailable',receiptId:null,...patch});
const withFixture=withTransportClock;
test('actual allocation event becomes one durable operational inbox record and acknowledgement',t=>withFixture(t,async f=>{
 const before={ledger:f.count('pa_ledger'),members:f.count('pa_memberships'),claims:f.count('pa_external_claims')};
 const result=await drain(f.runner);assert.equal(result.stored,1);
 assert.equal((await drain(f.runner)).stored,0);
 assert.equal(f.sinkDb.sql.prepare('SELECT count(*) n FROM adi_events').get().n,1);
 assert.deepEqual({ledger:f.count('pa_ledger'),members:f.count('pa_memberships'),claims:f.count('pa_external_claims')},before);
 assert.equal((await f.review.inspect({...scope,state:'delivered'})).items.length,1);
 assert.equal(f.count('pa_delivery_commands'),3);
}));
test('projection contains no payer phone, provider reference, amount, cookie or raw receipt',t=>withFixture(t,async f=>{
 const {event}=await claimed(f);
 assert.deepEqual(Object.keys(event).sort(),['schemaVersion','consumerId','eventId','clubId','orderId','userId','kind','allocationRecorded','businessTargetFulfilled','recordedAt'].sort());
 assert.equal(event.eventId,f.receipt.allocationId);assert.equal(event.userId,ids.user);
}));
test('contribution allocation remains explicitly unfulfilled; delivery never awards rewards',t=>withFixture(t,async f=>{
 await drain(f.runner);
 await f.addOrder({kind:'contribution',tier:null,initiative_id:crypto.randomUUID(),amount:200});
 await drain(f.runner);
 const history=await f.sink.list({clubId:24,afterEventId:null,limit:50});
 const c=history.items.find(x=>x.kind==='contribution');assert.equal(c.businessTargetFulfilled,false);
 assert.equal(f.count('pa_memberships'),1);
}));
test('source and receiver commit-response loss recover without duplicating records',t=>withFixture(t,async f=>{
 f.db.loseRun=true;f.sinkDb.loseRun=true;
 assert.equal((await drain(f.runner)).stored,1);
 assert.equal(f.count('pa_delivery_jobs'),1);assert.equal(f.count('pa_delivery_commands'),3);
}));
test('remote sink transport loses reply after commit, retry deduplicates original event',t=>withFixture(t,async f=>{
 f.runner.INBOX={accept:async event=>{await f.sink.accept(event);throw Error('private diagnostic');}};
 assert.equal((await drain(f.runner)).retryRecorded,1);
 assert.equal(f.sinkDb.sql.prepare('SELECT count(*) n FROM adi_events').get().n,1);
 f.advance(1000);f.runner.INBOX=f.sink;
 assert.equal((await drain(f.runner)).stored,1);
 assert.equal(f.sinkDb.sql.prepare('SELECT count(*) n FROM adi_events').get().n,1);
 const row=(await f.review.inspect({...scope,state:'delivered'})).items[0];assert.equal(row.attempts,2);
}));
test('source transport loses ack after commit; summary stays unknown and no duplicate resend',t=>withFixture(t,async f=>{
 f.runner.SOURCE={take:x=>f.source.take(x),readForDispatch:x=>f.source.readForDispatch(x),finish:async x=>{await f.source.finish(x);throw Error('reply lost');}};
 assert.equal((await drain(f.runner)).unknown,1);assert.equal((await f.review.inspect({...scope,state:'delivered'})).items.length,1);
 f.runner.SOURCE=f.source;assert.equal((await drain(f.runner)).examined,0);
}));
test('retry backoff and maximum attempts enter dead letter without deleting source event',t=>withFixture(t,async f=>{
 f.runner.INBOX={accept:async()=>{throw Error('unavailable');}};
 await drain(f.runner);assert.equal((await drain(f.runner)).examined,0);
 f.advance(1000);await drain(f.runner);f.advance(1999);assert.equal((await drain(f.runner)).examined,0);
 f.advance(1);await drain(f.runner);
 const [dead]=(await f.review.inspect(scope)).items;assert.equal(dead.attempts,3);assert.equal(dead.state,'dead');
 assert.equal(f.count('pa_outbox'),1);assert.equal(f.count('pa_receipts'),1);
 assert.equal((await drain(f.runner)).examined,0);
}));
test('expired claim is recorded before retry; repeated crash cannot exceed attempt budget',t=>withFixture(t,async f=>{
 for(let i=0;i<3;i++){
  const {event}=await f.source.take({clubId:24});assert.ok(event);
  f.advance(10000);assert.equal((await f.source.take({clubId:24})).event,null);
  f.advance(4000);
 }
 const dead=(await f.review.inspect(scope)).items[0];assert.equal(dead.attempts,3);assert.equal(dead.reason,'lease_expired');
 assert.equal((await f.source.take({clubId:24})).event,null);
}));
test('independent reviewer redrives the same event, keeps attempts and original audit',t=>withFixture(t,async f=>{
 const {claim}=await claimed(f);await finish(f,claim,{outcome:'dead',reason:'invalid_receipt'});
 const row=(await f.review.inspect(scope)).items[0];
 const input={clubId:24,eventId:row.eventId,expectedRevision:row.revision,requestId:crypto.randomUUID(),reason:'dependency_restored'};
 const result=await f.review.redrive(input);assert.deepEqual(await f.review.redrive(input),result);
 await fail(()=>f.review.redrive({...input,reason:'configuration_corrected'}),'idempotency_conflict');
 assert.equal((await drain(f.runner)).stored,1);
 const done=(await f.review.inspect({...scope,state:'delivered'})).items[0];assert.equal(done.eventId,row.eventId);assert.equal(done.attempts,2);assert.equal(done.cycleAttempts,1);
 assert.equal(f.count('pa_outbox'),1);
}));
test('dispatcher cannot redrive, including when given an additional reviewer grant',t=>withFixture(t,async f=>{
 const {claim}=await claimed(f);await finish(f,claim,{outcome:'dead',reason:'invalid_event'});
 const input={clubId:24,eventId:claim.eventId,expectedRevision:claim.revision+1,requestId:crypto.randomUUID(),reason:'configuration_corrected'};
 await fail(()=>f.source.redrive(input),'permission_denied');
 f.db.sql.prepare("INSERT INTO pa_delivery_grants VALUES(?,24,'review',1)").run(ids.outbox);
 await fail(()=>f.source.redrive(input),'conflict');
}));
test('stale reviewer cannot redrive a changed job head',t=>withFixture(t,async f=>{
 const {claim}=await claimed(f);await finish(f,claim,{outcome:'dead',reason:'invalid_event'});
 const base={clubId:24,eventId:claim.eventId,expectedRevision:claim.revision+1,reason:'configuration_corrected'};
 await f.review.redrive({...base,requestId:crypto.randomUUID()});
 await fail(()=>f.review.redrive({...base,requestId:crypto.randomUUID()}),'conflict');
}));
test('replayed finish returns original command outcome even after later redrive',t=>withFixture(t,async f=>{
 const {claim}=await claimed(f);
 const input={clubId:24,eventId:claim.eventId,leaseId:claim.leaseId,expectedRevision:claim.revision,requestId:crypto.randomUUID(),outcome:'dead',reason:'invalid_event',receiptId:null};
 const receipt=await f.source.finish(input);
 await f.review.redrive({clubId:24,eventId:claim.eventId,expectedRevision:claim.revision+1,requestId:crypto.randomUUID(),reason:'configuration_corrected'});
 assert.deepEqual(await f.source.finish(input),receipt);
}));
for(const kind of ['leased','delivered'])test(`legacy ${kind} attempted records are never silently adopted`,t=>withFixture(t,async f=>{
 if(kind==='pending'){
  // The baseline cannot legally transition an attempted row back to pending; test legacy leased instead.
  const result=await f.outbox.claim({clubId:24,limit:1});assert.equal(result.events.length,1);
 }else{
  const result=await f.outbox.claim({clubId:24,limit:1});
  if(kind==='delivered')await f.outbox.acknowledge({clubId:24,eventId:result.events[0].eventId,leaseId:result.events[0].leaseId});
 }
 f.advance(70000);assert.equal((await f.source.take({clubId:24})).event,null);assert.equal(f.count('pa_delivery_jobs'),0);
}));
test('new ownership blocks legacy claiming at the database boundary',t=>withFixture(t,async f=>{
 await f.source.take({clubId:24});await assert.rejects(()=>f.outbox.claim({clubId:24,limit:1}));
 assert.equal(f.db.sql.prepare('SELECT attempts FROM pa_outbox_delivery').get().attempts,0);
}));
test('malformed event receipt goes to dead letter before sink dispatch',t=>withFixture(t,async f=>{
 // Corruption injection only in the disposable fixture; production records stay immutable.
 f.db.sql.exec('DROP TRIGGER pa_outbox_update_blocked');
 f.db.sql.prepare("UPDATE pa_outbox SET payload_json='{}'").run();let sends=0;
 f.runner.INBOX={accept:async()=>{sends++;}};
 assert.equal((await drain(f.runner)).deadRecorded,1);assert.equal(sends,0);
}));
test('wrong receiver receipt cannot acknowledge the source',t=>withFixture(t,async f=>{
 f.runner.INBOX={accept:async value=>({...await f.sink.accept(value),consumerId:crypto.randomUUID()})};
 assert.equal((await drain(f.runner)).deadRecorded,1);assert.equal((await f.review.inspect({...scope,state:'delivered'})).items.length,0);
}));
test('timeout does not mean remote cancellation; late sink commit deduplicates',t=>withFixture(t,async f=>{
 const entered=deferred(),release=deferred();let pending;
 f.runner.INBOX={accept:event=>{entered.resolve();return (pending=release.promise.then(()=>f.sink.accept(event)));}};
 const operation=drain(f.runner);
 assert.equal((await expireTransportDeadline(t,operation,entered.promise,Number(f.runner.DELIVERY_TIMEOUT_MS))).retryRecorded,1);
 assert.equal(f.sinkDb.sql.prepare('SELECT count(*) n FROM adi_events').get().n,0);
 release.resolve();await pending;
 f.advance(1000);f.runner.INBOX=f.sink;assert.equal((await drain(f.runner)).stored,1);
 assert.equal(f.sinkDb.sql.prepare('SELECT count(*) n FROM adi_events').get().n,1);
}));
test('source authorization revoked during external call preserves unknown acknowledgement',t=>withFixture(t,async f=>{
 f.runner.INBOX={accept:async event=>{const r=await f.sink.accept(event);f.db.sql.prepare('UPDATE pa_principals SET enabled=0 WHERE principal_id=?').run(ids.outbox);return r;}};
 assert.equal((await drain(f.runner)).unknown,1);assert.equal(f.sinkDb.sql.prepare('SELECT count(*) n FROM adi_events').get().n,1);
 assert.equal(f.db.sql.prepare('SELECT state FROM pa_delivery_jobs').get().state,'leased');
}));
test('one unavailable club does not prevent other configured clubs from being attempted',t=>withFixture(t,async f=>{
 f.runner.DELIVERY_CLUB_IDS='[25,24]';f.db.sql.exec('UPDATE pa_delivery_control SET enabled=0 WHERE club_id=25');
 const r=await drain(f.runner);assert.equal(r.unavailableClubs,1);assert.equal(r.stored,1);
}));
test('one run takes at most one event per club',t=>withFixture(t,async f=>{
 await f.addOrder();await f.addOrder();assert.equal((await drain(f.runner)).examined,1);
 assert.equal(f.count('pa_delivery_jobs'),1);
}));
test('private review pages preserve filtering and bounded continuation',t=>withFixture(t,async f=>{
 await f.addOrder();await drain(f.runner);await drain(f.runner);
 const one=await f.review.inspect({...scope,state:'delivered',limit:1});assert.equal(one.items.length,1);assert.ok(one.nextAfterEventId);
 const two=await f.review.inspect({...scope,state:'delivered',limit:1,afterEventId:one.nextAfterEventId});assert.equal(two.items.length,1);assert.equal(two.nextAfterEventId,null);
 assert.notEqual(one.items[0].eventId,two.items[0].eventId);
 assert.deepEqual((await f.review.inspect({...scope,clubId:25,state:'delivered'})).items,[]);
}));
