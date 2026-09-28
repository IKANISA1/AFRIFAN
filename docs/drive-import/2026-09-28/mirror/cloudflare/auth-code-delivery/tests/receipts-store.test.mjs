import {test} from 'node:test';
import assert from 'node:assert/strict';
import {receiptFixture,ACCOUNT} from './receipts-fixture.mjs';
import {AuthenticationCodeDeliveryService} from '../src/service.mjs';
import {ReceiptStore} from '../src/receipt-store.mjs';
import {StatusAwareDeliveryService} from '../src/status-aware-service.mjs';
test('tracked dispatch preserves original accepted receipt and duplicate suppression',async t=>{
 const f=receiptFixture(t),raw={...f.input,template:f.route.templateName};const a=await f.tracked.deliverWithReceipt(raw),b=await f.tracked.deliverWithReceipt(raw);
 assert.deepEqual(a,b);assert.equal(a.messageId,'wamid.SYNTHETIC');assert.equal(f.count('delivery_receipt_bindings'),1);assert.equal(f.calls.filter(x=>x.init.method==='POST').length,1);
 const rows=JSON.stringify(f.db.sql.prepare('SELECT * FROM delivery_receipt_bindings').all());assert(!rows.includes(f.input.phone));assert(!rows.includes('"code"'));
});
test('binding exists before provider metadata or sending',async t=>{const f=receiptFixture(t);f.override(async(_u,o)=>{
 assert.equal(f.count('delivery_receipt_bindings'),1);return Response.json(o.method==='GET'?f.template():f.success());});await f.tracked.deliver(f.input);
});
test('parallel tracked duplicates submit once',async t=>{const f=receiptFixture(t);await Promise.all([f.tracked.deliver(f.input),f.tracked.deliver(f.input)]);assert.equal(f.calls.filter(x=>x.init.method==='POST').length,1);});
for(const mutate of [x=>x.phone='+250700000002',x=>x.code='654321',x=>x.clubId=44,x=>x.expiresAt-=1000])test('changed request cannot replace retained binding '+mutate.toString(),async t=>{
 const f=receiptFixture(t);await f.tracked.deliver(f.input);const input={...f.input};mutate(input);await assert.rejects(f.tracked.deliver(input));assert.equal(f.calls.filter(x=>x.init.method==='POST').length,1);
});
test('unbound historical dispatch is not retroactively attributed',async t=>{
 const f=receiptFixture(t);await f.service.deliver(f.input);await assert.rejects(f.tracked.deliver(f.input),/receipt_binding_conflict/);assert.equal(f.count('delivery_receipt_bindings'),0);
});
test('disabled binding or changed sender prevents provider call',async t=>{
 const f=receiptFixture(t);f.env.RECEIPT_BINDING_ENABLED='false';await assert.rejects(f.tracked.deliver(f.input));assert.equal(f.calls.length,0);
 f.env.RECEIPT_BINDING_ENABLED='true';f.env.RECEIPT_ROUTES_JSON=JSON.stringify([{clubId:24,businessAccountId:ACCOUNT,phoneNumberId:'100000000000088'}]);await assert.rejects(f.tracked.deliver(f.input));assert.equal(f.calls.length,0);
});
test('database binding failure causes no external call',async t=>{
 const f=receiptFixture(t);f.db.failUpdate=true;await assert.rejects(f.tracked.deliver(f.input));assert.equal(f.calls.length,0);
});
test('unmatched statuses never produce acceptance',async t=>{
 const f=receiptFixture(t);f.override(async(_u,o)=>{if(o.method==='GET')return Response.json(f.template());throw Error('lost');});await f.tracked.deliver(f.input);
 await f.send(f.payload('delivered'));assert.equal(f.count('delivery_status_links'),0);assert.equal((await f.status()).providerAccepted,false);assert.equal((await f.status()).deliveryState,'unknown');
 await f.store.reconcile();assert.equal(f.count('delivery_status_links'),0);
});
test('duplicate notifications have one durable event and one link',async t=>{
 const f=receiptFixture(t);await f.tracked.deliver(f.input);await Promise.all([f.send(),f.send()]);assert.equal(f.count('delivery_status_events'),1);assert.equal(f.count('delivery_status_links'),1);
});
test('out of order notifications cannot regress read to sent',async t=>{
 const f=receiptFixture(t);await f.tracked.deliver(f.input);await f.send(f.payload('read'));f.advance(1000);await f.send(f.payload('sent'));
 const s=await f.status();assert.equal(s.deliveryState,'read');assert.equal(s.observedEvents,2);assert.equal(s.informationOnly,true);
});
test('failed and delivered facts remain visible as conflict, not rewritten',async t=>{
 const f=receiptFixture(t);await f.tracked.deliver(f.input);await f.send(f.payload('delivered'));await f.send(f.payload('failed',{errors:[{code:7}]}));
 const s=await f.status();assert.equal(s.deliveryState,'conflicting');assert.equal(s.providerAccepted,true);assert.deepEqual(s.errorCodes,[7]);
 assert.equal(f.db.sql.prepare('SELECT state FROM delivery_dispatches').get().state,'accepted');
});
test('failed without delivered/read is reported failed even after late sent',async t=>{
 const f=receiptFixture(t);await f.tracked.deliver(f.input);await f.send(f.payload('failed'));await f.send(f.payload('sent'));assert.equal((await f.status()).deliveryState,'failed');
});
test('deleted is separate evidence and does not revoke identity or erase delivery fact',async t=>{
 const f=receiptFixture(t);await f.tracked.deliver(f.input);await f.send(f.payload('read'));await f.send(f.payload('deleted'));const s=await f.status();assert.equal(s.deliveryState,'read');assert(s.reported.deletedAt!==null);
});
test('callback before provider receipt commit is reconciled afterwards',async t=>{
 const f=receiptFixture(t);f.override(async(_u,o)=>{if(o.method==='GET')return Response.json(f.template());
  assert.equal((await f.send()).status,200);assert.equal(f.count('delivery_status_links'),0);return Response.json(f.success());});
 await f.tracked.deliver(f.input);assert.equal(f.count('delivery_status_links'),0);assert.equal((await f.store.reconcile()).linked,1);assert.equal((await f.status()).deliveryState,'delivered');
});
for(const changes of [{recipient_id:'250700000002'},{id:'wamid.OTHER'},{timestamp:'1789900000'}])test('no correlation for wrong identity/message/time '+JSON.stringify(changes),async t=>{
 const f=receiptFixture(t);await f.tracked.deliver(f.input);await f.send(f.payload('delivered',changes));assert.equal(f.count('delivery_status_links'),0);
});
test('same provider sender can serve two clubs without cross-club read',async t=>{
 const f=receiptFixture(t);const routes=JSON.parse(f.env.RECEIPT_ROUTES_JSON);routes.push({...routes[0],clubId:44});f.env.RECEIPT_ROUTES_JSON=JSON.stringify(routes);
 await f.tracked.deliver(f.input);await f.send();await assert.rejects(new ReceiptStore(f.env,{clock:f.now}).read({challengeId:f.input.challengeId,clubId:44}),/receipt_not_found/);
});
for(const values of [{clubId:24,challengeId:'bad'},{clubId:24,challengeId:'VALID',actor:'admin'},{clubId:'24',challengeId:'VALID'}])test('private status read strict fields '+JSON.stringify(values),async t=>{
 const f=receiptFixture(t);const v={...values};if(v.challengeId==='VALID')v.challengeId=f.input.challengeId;await assert.rejects(f.store.read(v));
});
test('disabled reads and revoked routing deny historical status',async t=>{
 const f=receiptFixture(t);await f.tracked.deliver(f.input);f.env.RECEIPT_READ_ENABLED='false';await assert.rejects(f.status());
 f.env.RECEIPT_READ_ENABLED='true';f.env.RECEIPT_ROUTES_JSON=JSON.stringify([{clubId:24,businessAccountId:'100000000000098',phoneNumberId:f.route.phoneNumberId}]);
 await assert.rejects(new ReceiptStore(f.env,{clock:f.now}).read({clubId:24,challengeId:f.input.challengeId}),/receipt_not_found/);
});
for(const position of [0,1,2,3])test('event batch failure rolls back every earlier effect at position '+position,async t=>{
 const f=receiptFixture(t);await f.tracked.deliver(f.input);const p=f.payload();p.entry[0].changes[0].value.statuses.push({...p.entry[0].changes[0].value.statuses[0],status:'read'});
 f.failBatchAt(position);assert.equal((await f.send(p)).status,503);assert.equal(f.count('delivery_status_events'),0);assert.equal(f.count('delivery_status_links'),0);
 f.failBatchAt(-1);assert.equal((await f.send(p)).status,200);assert.equal(f.count('delivery_status_events'),2);
});
test('lost response after commit is safely acknowledged on same signed retry',async t=>{
 const f=receiptFixture(t);await f.tracked.deliver(f.input);f.loseBatch();assert.equal((await f.send()).status,503);assert.equal(f.count('delivery_status_events'),1);assert.equal((await f.send()).status,200);assert.equal(f.count('delivery_status_events'),1);
});
for(const table of ['delivery_receipt_bindings','delivery_status_events','delivery_status_links'])test('immutable retained evidence '+table,async t=>{
 const f=receiptFixture(t);await f.tracked.deliver(f.input);await f.send();const col=table==='delivery_receipt_bindings'?'club_id':table==='delivery_status_events'?'status':'club_id';
 assert.throws(()=>f.db.sql.exec(`UPDATE ${table} SET ${col}=${table==='delivery_status_events'?"'failed'":'44'}`));assert.throws(()=>f.db.sql.exec(`DELETE FROM ${table}`));
});
test('database guard rejects manually misattributed link',async t=>{
 const f=receiptFixture(t);await f.tracked.deliver(f.input);await f.send(f.payload('delivered',{recipient_id:'250700000002'}));const event=f.db.sql.prepare('SELECT event_id FROM delivery_status_events').get();
 assert.throws(()=>f.db.sql.prepare('INSERT INTO delivery_status_links VALUES(?,?,?,?)').run(event.event_id,f.input.challengeId,24,f.now()),/correlation/);
});
test('reconciliation disabled and no guessed matches',async t=>{
 const f=receiptFixture(t);f.env.RECEIPT_RECONCILE_ENABLED='false';await assert.rejects(f.store.reconcile());assert.equal(f.count('delivery_status_links'),0);
});
