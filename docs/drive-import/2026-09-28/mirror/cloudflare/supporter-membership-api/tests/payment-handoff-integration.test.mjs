import test,{after} from 'node:test';import assert from 'node:assert/strict';
import {fixture} from './fixture.mjs';import {compileHandoff} from '../scripts/compile-handoff.mjs';
const compiled=compileHandoff();after(()=>compiled.cleanup());
const {PaymentHandoffCoordinator}=await import(compiled.url),{MembershipApiClient}=await import(compiled.clientUrl);
async function setup(t){const f=await fixture(t),data=new Map(),tails=new Map();let dialCount=0;const network=[];
 const store={async runExclusive(k,work){const prior=tails.get(k)??Promise.resolve();let release;tails.set(k,new Promise(r=>release=r));await prior;try{return await work();}finally{release();}},
 async load(k){return data.get(k)??null;},async compareAndSet(k,old,v){if((data.get(k)??null)!==old)return false;data.set(k,v);return true;}};
 const client=new MembershipApiClient(f.env.NATIVE_ORIGIN,24,async()=>f.tokens.accessToken,async(url,init)=>{
  network.push(init.method);const req=new Request(url,{...init,headers:{...init.headers,'cf-connecting-ip':'203.0.113.10'}});
  Object.defineProperty(req,'cf',{value:{colo:'TEST'}});return f.gateway.fetch(req,f.env);
 });
 const flow=new PaymentHandoffCoordinator(client,store,{async open(){dialCount++;return true;}},()=>0,50,true);
 const session=await client.session(),prepared=await client.prepare(session,crypto.randomUUID(),'gold');network.length=0;
 return {...f,flow,client,store,data,network,prepared,dialCount:()=>dialCount};}
test('real services: handoff is GET-only and does not allocate or activate membership',async t=>{const f=await setup(t),q=await f.flow.review(f.prepared.orderId);const r=await f.flow.confirm(q.reviewId,true);
 assert.equal(r.platformOpened,true);assert.equal(r.paymentVerified,false);assert.equal(f.dialCount(),1);assert.ok(f.network.every(x=>x==='GET'));
 assert.equal(f.payment.count('pa_allocations'),0);assert.equal(f.payment.count('pa_memberships'),0);assert.equal(f.payment.count('pa_ledger'),0);
 await f.allocate(f.prepared.orderId);const recovered=await f.flow.recover();assert.equal(recovered.status.status,'allocated');assert.equal(f.payment.count('pa_memberships'),1);assert.equal(f.dialCount(),1);});
test('real services: changed catalog invalidates reviewed instructions',async t=>{const f=await setup(t),q=await f.flow.review(f.prepared.orderId);
 f.payment.db.sql.exec('UPDATE pa_checkout_packages SET annual_price=annual_price+100');
 await assert.rejects(f.flow.confirm(q.reviewId,true));assert.equal(f.dialCount(),0);assert.equal(f.payment.count('pa_memberships'),0);});
test('real services: revoked access refuses handoff after review',async t=>{const f=await setup(t),q=await f.flow.review(f.prepared.orderId);
 await f.auth.service.revoke(24,f.tokens.accessToken,{scope:'current'});await assert.rejects(f.flow.confirm(q.reviewId,true));assert.equal(f.dialCount(),0);});
test('real services: allocated order cannot open a second payment',async t=>{const f=await setup(t),q=await f.flow.review(f.prepared.orderId);await f.allocate(f.prepared.orderId);
 await assert.rejects(f.flow.confirm(q.reviewId,true));assert.equal(f.dialCount(),0);assert.equal(f.payment.count('pa_allocations'),1);});
test('real services: launched but pending handoff cannot be repeated after restart',async t=>{const f=await setup(t),q=await f.flow.review(f.prepared.orderId);await f.flow.confirm(q.reviewId,true);
 const restarted=new PaymentHandoffCoordinator(f.client,f.store,{async open(){throw Error('must never be invoked');}},()=>0,50,true);
 const recovered=await restarted.recover();assert.equal(recovered.record.phase,'opened');assert.equal(recovered.status.status,'pending_current');
 await assert.rejects(restarted.review(f.prepared.orderId),e=>e.code==='unresolved_payment_handoff');assert.equal(f.dialCount(),1);});
