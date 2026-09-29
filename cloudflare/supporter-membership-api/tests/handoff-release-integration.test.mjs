import {readFileSync} from 'node:fs';
import {NOW_SQL} from '../../payment-allocation/src/policy.mjs';
import {PaymentHandoffService} from '../../payment-allocation/src/handoff-service.mjs';
import {checkoutPrincipal,readPrincipal} from '../../payment-allocation/tests/checkout-fixture.mjs';
import test,{after} from 'node:test';import assert from 'node:assert/strict';
import {fixture} from './fixture.mjs';import {compileHandoff} from '../scripts/compile-handoff.mjs';
const compiled=compileHandoff();after(()=>compiled.cleanup());
const {PaymentHandoffCoordinator}=await import(compiled.url),{MembershipApiClient}=await import(compiled.clientUrl);
async function setup(t){const f=await fixture(t),data=new Map(),tails=new Map();let dialCount=0;const network=[];
 const store={async runExclusive(k,work){const prior=tails.get(k)??Promise.resolve();let release;tails.set(k,new Promise(r=>release=r));await prior;try{return await work();}finally{release();}},
 async load(k){return data.get(k)??null;},async compareAndSet(k,old,v){if((data.get(k)??null)!==old)return false;data.set(k,v);return true;}};
 f.payment.db.sql.exec(readFileSync(new URL('../../payment-allocation/migrations/0003_payment_handoff_journal.sql',import.meta.url),'utf8').replaceAll(NOW_SQL,'test_now_ms()'));
f.payment.db.sql.exec(readFileSync(new URL('../../payment-allocation/migrations/0004_release_unclaimed_handoff.sql',import.meta.url),'utf8').replaceAll(NOW_SQL,'test_now_ms()'));
 f.payment.db.sql.exec('UPDATE pa_handoff_settings SET enabled=1');f.payment.env.HANDOFF_JOURNAL_ENABLED='true';f.env.MEMBERSHIP_HANDOFF_JOURNAL_ENABLED='true';
 f.payment.env.HANDOFF_RELEASE_ENABLED='true';f.env.MEMBERSHIP_HANDOFF_RELEASE_ENABLED='true';f.payment.db.sql.exec('UPDATE pa_handoff_release_settings SET enabled=1');
 const journal=new PaymentHandoffService(f.payment.env,checkoutPrincipal),journalReader=new PaymentHandoffService(f.payment.env,readPrincipal);
 f.env.CHECKOUT.releaseHandoff=v=>journal.releaseHandoff(v);
 f.env.CHECKOUT.reserveHandoff=v=>journal.reserveHandoff(v);f.env.CHECKOUT.claimHandoff=v=>journal.claimHandoff(v);f.env.CHECKOUT_READER.currentHandoff=v=>journalReader.currentHandoff(v);
 const client=new MembershipApiClient(f.env.NATIVE_ORIGIN,24,async()=>f.tokens.accessToken,async(url,init)=>{
  network.push(init.method);const req=new Request(url,{...init,headers:{...init.headers,'cf-connecting-ip':'203.0.113.10'}});
  Object.defineProperty(req,'cf',{value:{colo:'TEST'}});return f.gateway.fetch(req,f.env);
 });
 const flow=new PaymentHandoffCoordinator(client,store,{async open(){dialCount++;return true;}},()=>0,50,true);
 const session=await client.session(),prepared=await client.prepare(session,crypto.randomUUID(),'gold');network.length=0;
 return {...f,flow,client,store,data,network,prepared,dialCount:()=>dialCount};}


async function reserveOnly(f){const actor=await f.client.session();const r=await f.client.reserveHandoff(actor,f.prepared.orderId,crypto.randomUUID());return r.handoff.handoffId;}
async function stranded(f){const original=f.env.CHECKOUT.reserveHandoff;f.env.CHECKOUT.reserveHandoff=async v=>{await original(v);throw Error('response lost before claim');};
 const q=await f.flow.review(f.prepared.orderId);await assert.rejects(f.flow.confirm(q.reviewId,true));f.env.CHECKOUT.reserveHandoff=original;
 return (await f.flow.recover()).server.handoff.handoffId;
}
test('actual pipeline: stranded pre-claim reservation -> explicit release -> fresh reviewed handoff',async t=>{
 const f=await setup(t),id=await stranded(f);assert.equal(f.dialCount(),0);assert.equal(JSON.parse([...f.data.values()][0]).phase,'reserved');
 const result=await f.flow.releaseUnclaimed(id,true);assert.equal(result.handoff.phase,'released');assert.equal(result.mayOpenDialer,false);
 assert.equal(JSON.parse([...f.data.values()][0]).phase,'not_opened');assert.equal(f.payment.count('pa_handoff_releases'),1);
 const review=await f.flow.review(f.prepared.orderId);await f.flow.confirm(review.reviewId,true);assert.equal(f.dialCount(),1);assert.equal(f.payment.count('pa_memberships'),0);
});
for(const ack of [false,null,undefined,'true',1])test('release requires explicit acknowledgement '+ack,async t=>{const f=await setup(t),id=await reserveOnly(f);await assert.rejects(f.flow.releaseUnclaimed(id,ack),e=>e.code==='explicit_confirmation_required');assert.equal(f.payment.count('pa_handoff_releases'),0);});
test('lost local state still permits explicit release of a never-claimed server reservation',async t=>{const f=await setup(t),id=await reserveOnly(f);f.data.clear();const x=await f.flow.releaseUnclaimed(id,true);assert.equal(x.handoff.phase,'released');assert.equal(f.data.size,0);assert.equal(f.dialCount(),0);});
test('restore/recover never releases a reservation automatically',async t=>{const f=await setup(t);await reserveOnly(f);f.network.length=0;await f.flow.recover();await f.flow.recover();assert.ok(!f.network.includes('POST'));assert.equal(f.payment.count('pa_handoff_releases'),0);});
test('claimed uncertain attempt remains blocked even with empty local storage',async t=>{const f=await setup(t),q=await f.flow.review(f.prepared.orderId);await f.flow.confirm(q.reviewId,true);f.data.clear();const r=await f.flow.recover();await assert.rejects(f.flow.releaseUnclaimed(r.server.handoff.handoffId,true),e=>e.code==='handoff_not_releasable');assert.equal(f.payment.count('pa_handoff_releases'),0);assert.equal(f.dialCount(),1);});
for(const phase of ['opened','unknown'])test('local '+phase+' evidence cannot be erased through release',async t=>{const f=await setup(t),id=await stranded(f);const [k,v]=[...f.data.entries()][0];f.data.set(k,JSON.stringify({...JSON.parse(v),phase}));await assert.rejects(f.flow.releaseUnclaimed(id,true),e=>e.code==='unresolved_payment_handoff');assert.equal(f.payment.count('pa_handoff_releases'),0);});
test('lost release response retries only the same operation with no dial or duplicate release',async t=>{const f=await setup(t),id=await stranded(f),original=f.env.CHECKOUT.releaseHandoff,keys=[];
 f.env.CHECKOUT.releaseHandoff=async v=>{keys.push(v.requestId);await original(v);throw Error('lost response');};await assert.rejects(f.flow.releaseUnclaimed(id,true),e=>e.outcome==='unknown');
 assert.equal(JSON.parse([...f.data.values()][0]).phase,'reserved');f.env.CHECKOUT.releaseHandoff=async v=>{keys.push(v.requestId);return original(v);};await f.flow.releaseUnclaimed(id,true);
 assert.deepEqual(keys,[id,id]);assert.equal(f.payment.count('pa_handoff_releases'),1);assert.equal(f.dialCount(),0);
});
test('persistence failure after release preserves local marker for explicit recovery',async t=>{const f=await setup(t),id=await stranded(f),save=f.store.compareAndSet;f.store.compareAndSet=async()=>false;await assert.rejects(f.flow.releaseUnclaimed(id,true),e=>e.code==='handoff_outcome_unknown');assert.equal(JSON.parse([...f.data.values()][0]).phase,'reserved');f.store.compareAndSet=save;await f.flow.releaseUnclaimed(id,true);assert.equal(JSON.parse([...f.data.values()][0]).phase,'not_opened');});
test('a concurrent claim defeats release and no local marker is cleared',async t=>{const f=await setup(t),id=await stranded(f),original=f.env.CHECKOUT.releaseHandoff;f.env.CHECKOUT.releaseHandoff=async v=>{await f.env.CHECKOUT.claimHandoff({...v,requestId:crypto.randomUUID()});return original(v);};await assert.rejects(f.flow.releaseUnclaimed(id,true));assert.equal(f.payment.count('pa_handoff_releases'),0);assert.equal(JSON.parse([...f.data.values()][0]).phase,'reserved');assert.equal(f.dialCount(),0);});
test('postcommit identity revocation withholds release result without erasing the journal',async t=>{const f=await setup(t),id=await stranded(f),original=f.env.CHECKOUT.releaseHandoff;f.env.CHECKOUT.releaseHandoff=async v=>{const r=await original(v);await f.auth.service.revoke(24,f.tokens.accessToken,{scope:'current'});return r;};await assert.rejects(f.flow.releaseUnclaimed(id,true));assert.equal(f.payment.count('pa_handoff_releases'),1);assert.equal(JSON.parse([...f.data.values()][0]).phase,'reserved');});
test('background invalidation before release prevents mutation',async t=>{const f=await setup(t),id=await stranded(f),read=f.client.handoffCurrent.bind(f.client);f.client.handoffCurrent=async a=>{const r=await read(a);f.flow.invalidateReview();return r;};await assert.rejects(f.flow.releaseUnclaimed(id,true),e=>e.code==='payment_review_invalidated');assert.equal(f.payment.count('pa_handoff_releases'),0);});
test('background invalidation during release preserves local recovery marker',async t=>{const f=await setup(t),id=await stranded(f),original=f.env.CHECKOUT.releaseHandoff;f.env.CHECKOUT.releaseHandoff=async v=>{const r=await original(v);f.flow.invalidateReview();return r;};await assert.rejects(f.flow.releaseUnclaimed(id,true),e=>e.code==='payment_review_invalidated');assert.equal(f.payment.count('pa_handoff_releases'),1);assert.equal(JSON.parse([...f.data.values()][0]).phase,'reserved');});
test('wrong response handoff cannot satisfy release confirmation',async t=>{const f=await setup(t),id=await stranded(f),original=f.env.CHECKOUT.releaseHandoff;f.env.CHECKOUT.releaseHandoff=async v=>{const r=await original(v);return {...r,handoff:{...r.handoff,handoffId:crypto.randomUUID()}};};await assert.rejects(f.flow.releaseUnclaimed(id,true),e=>e.outcome==='unknown');assert.equal(JSON.parse([...f.data.values()][0]).phase,'reserved');});
test('release API remains unavailable unless separately enabled',async t=>{const f=await setup(t),id=await reserveOnly(f);f.env.MEMBERSHIP_HANDOFF_RELEASE_ENABLED='false';await assert.rejects(f.flow.releaseUnclaimed(id,true));assert.equal(f.payment.count('pa_handoff_releases'),0);});
test('review and release do not imply membership or payment success',async t=>{const f=await setup(t),id=await reserveOnly(f);await f.flow.releaseUnclaimed(id,true);for(const table of ['pa_allocations','pa_memberships','pa_ledger','pa_reference_claims'])if(table!=='pa_reference_claims')assert.equal(f.payment.count(table),0);});
