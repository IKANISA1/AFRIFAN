import {test} from 'node:test';
import assert from 'node:assert/strict';
import {fixture as authFixture} from '../../supporter-auth/tests/support/fixture.mjs';
import {dispatchOtp} from '../../supporter-auth/src/delivery.mjs';
import {receiptFixture} from './receipts-fixture.mjs';
import {StatusAwareDeliveryService} from '../src/status-aware-service.mjs';
import {receiptKey} from '../src/receipts-policy.mjs';
async function setup(t){const a=authFixture(t),f=receiptFixture(t);f.advance(a.clock.now-f.now());
 f.route.templateName='synthetic_auth';f.route.reviewExpiresAt=f.now()+86400000;f.env.DELIVERY_ROUTES_JSON=JSON.stringify([f.route]);
 const c=await a.issue();f.input.challengeId=c.challengeId;
 a.env.AUTH_DELIVERY_MODE='private-deduplicated';a.env.OTP_DELIVERY={deliverWithReceipt:v=>f.tracked.deliverWithReceipt(v)};
 return {a,f,c};}
test('queue, private sender, signed receipt and OTP verification remain separate authorities',async t=>{
 const {a,f,c}=await setup(t);const drained=await dispatchOtp(a.env,{clock:()=>a.clock.now});assert.equal(drained.accepted,1);
 assert.equal(a.count('auth_sessions'),0);assert.equal(a.count('auth_accounts'),0);
 assert.equal((await f.send()).status,200);assert.equal((await f.status()).deliveryState,'delivered');
 assert.equal(a.count('auth_sessions'),0);assert.equal(a.count('auth_accounts'),0);
 await a.service.verify(24,{challengeId:c.challengeId,clientSecret:c.secret,code:c.code},a.key());
 assert.equal(a.count('auth_sessions'),1);assert.equal(a.count('auth_accounts'),1);
});
test('forged receipt cannot change auth challenge or dispatch acceptance',async t=>{
 const {a,f}=await setup(t);await dispatchOtp(a.env,{clock:()=>a.clock.now});
 const before=JSON.stringify(a.sql('SELECT * FROM auth_challenges'));
 assert.equal((await f.send(f.payload(),{'x-hub-signature-256':'sha256='+'0'.repeat(64)})).status,403);
 assert.equal(JSON.stringify(a.sql('SELECT * FROM auth_challenges')),before);assert.equal(f.count('delivery_status_events'),0);
});
test('failed delivery observation cannot revoke an authenticated session',async t=>{
 const {a,f,c}=await setup(t);await dispatchOtp(a.env,{clock:()=>a.clock.now});
 const tokens=await a.service.verify(24,{challengeId:c.challengeId,clientSecret:c.secret,code:c.code},a.key());
 const before=JSON.stringify(a.sql('SELECT * FROM auth_sessions'));
 await f.send(f.payload('failed',{errors:[{code:131026}]}));assert.equal((await f.status()).deliveryState,'failed');
 assert.equal(JSON.stringify(a.sql('SELECT * FROM auth_sessions')),before);assert(tokens);
});
test('early callback through queued sender links only after known acceptance',async t=>{
 const {a,f}=await setup(t);f.override(async(_url,options)=>{
  if(options.method==='GET')return Response.json(f.template());
  assert.equal((await f.send()).status,200);assert.equal(f.count('delivery_status_links'),0);return Response.json(f.success());
 });
 await dispatchOtp(a.env,{clock:()=>a.clock.now});assert.equal(f.count('delivery_status_links'),0);
 await f.store.reconcile();assert.equal((await f.status()).deliveryState,'delivered');assert.equal(a.count('auth_sessions'),0);
});
test('ambiguous provider outcome and a signed status cannot authorize acceptance or resend',async t=>{
 const {a,f}=await setup(t);f.override(async(_url,options)=>{if(options.method==='GET')return Response.json(f.template());throw Error('lost response');});
 assert.equal((await dispatchOtp(a.env,{clock:()=>a.clock.now})).failed,1);
 await f.send();assert.equal((await f.status()).providerAccepted,false);assert.equal((await f.status()).deliveryState,'unknown');
 a.clock.now+=31000;f.advance(31000);await dispatchOtp(a.env,{clock:()=>a.clock.now});
 assert.equal(f.calls.filter(c=>c.init.method==='POST').length,1);assert.equal(a.count('auth_sessions'),0);
});
test('same key reused for recipient and dispatch commitment fails closed',async t=>{const f=receiptFixture(t);f.env.RECEIPT_HMAC_KEY=f.env.DISPATCH_HMAC_KEY;assert.throws(()=>receiptKey(f.env));await assert.rejects(f.tracked.deliver(f.input));assert.equal(f.calls.length,0);});
test('bounded reconciliation handles 100 correlatable events then remaining events',async t=>{
 const f=receiptFixture(t);await f.tracked.deliver(f.input);await f.send();
 const e=f.db.sql.prepare('SELECT * FROM delivery_status_events').get();
 const ins=f.db.sql.prepare('INSERT INTO delivery_status_events VALUES(?,?,?,?,?,?,?,?,?,?)');
 for(let i=1;i<=105;i++)ins.run(i.toString(16).padStart(64,'0'),e.business_account_id,e.phone_number_id,e.provider_message_id,e.recipient_commitment,e.key_version,e.status,e.provider_at+i,e.received_at+i,'[]');
 assert.equal((await f.store.reconcile()).linked,100);assert.equal((await f.store.reconcile()).linked,5);assert.equal((await f.store.reconcile()).linked,0);
 assert.equal(f.count('delivery_status_links'),106);
});
test('uncorrelatable old pending observations do not starve later eligible links',async t=>{
 const f=receiptFixture(t);await f.tracked.deliver(f.input);await f.send();const e=f.db.sql.prepare('SELECT * FROM delivery_status_events').get();
 const ins=f.db.sql.prepare('INSERT INTO delivery_status_events VALUES(?,?,?,?,?,?,?,?,?,?)');
 for(let i=1;i<=150;i++)ins.run(i.toString(16).padStart(64,'0'),e.business_account_id,e.phone_number_id,'wamid.unrelated'+i,e.recipient_commitment,e.key_version,e.status,e.provider_at,e.received_at-1000,'[]');
 ins.run('f'.repeat(64),e.business_account_id,e.phone_number_id,e.provider_message_id,e.recipient_commitment,e.key_version,'read',e.provider_at+1000,e.received_at+1000,'[]');
 assert.equal((await f.store.reconcile()).linked,1);assert.equal((await f.status()).deliveryState,'read');
});
test('private read fails closed instead of silently truncating more than 200 observations',async t=>{
 const f=receiptFixture(t);await f.tracked.deliver(f.input);await f.send();const e=f.db.sql.prepare('SELECT * FROM delivery_status_events').get();
 for(let i=1;i<=201;i++)f.db.sql.prepare('INSERT INTO delivery_status_events VALUES(?,?,?,?,?,?,?,?,?,?)').run(i.toString(16).padStart(64,'0'),e.business_account_id,e.phone_number_id,e.provider_message_id,e.recipient_commitment,'1','sent',e.provider_at+i,e.received_at+i,'[]');
 await f.store.reconcile();await f.store.reconcile();await f.store.reconcile();await assert.rejects(f.status(),/receipt_history_limit/);
});
test('migration is forward-only and preserved dispatch triggers reject alteration',async t=>{
 const f=receiptFixture(t);await f.tracked.deliver(f.input);await f.send();
 assert.throws(()=>f.db.sql.exec("UPDATE delivery_dispatches SET state='unknown'"));assert.throws(()=>f.db.sql.exec('DELETE FROM delivery_dispatches'));
 assert.equal(f.db.sql.prepare('PRAGMA integrity_check').get().integrity_check,'ok');
 assert.deepEqual(f.db.sql.prepare('PRAGMA foreign_key_check').all(),[]);
});
