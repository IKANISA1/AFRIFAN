import test from 'node:test';import assert from 'node:assert/strict';
import {compileClient} from '../scripts/compile-client.mjs';import {fixture} from './fixture.mjs';
const compiled=compileClient();const {MembershipApiClient,CheckoutCoordinator}=await import(compiled.url);test.after(()=>compiled.cleanup());
async function setup(t,options={}){const f=await fixture(t);let accessToken=f.tokens.accessToken;const seen=[];
 const transport=async(url,init)=>{seen.push({method:init.method,key:init.headers['idempotency-key'],body:init.body});const req=new Request(url,init);req.headers.set('cf-connecting-ip','203.0.113.10');Object.defineProperty(req,'cf',{value:{colo:'TEST'}});return f.gateway.fetch(req,f.env);};
 const client=new MembershipApiClient(f.env.NATIVE_ORIGIN,24,async()=>accessToken,options.fetcher??transport,options.timeoutMs??15000);
 return {...f,client,seen,transport,setToken(v){accessToken=v;}};}
function store(){const data=new Map(),locks=new Map();return {data,failWrite:false,failAfter:false,lie:false,
 async runExclusive(scope,fn){const previous=locks.get(scope)??Promise.resolve();let release;const done=new Promise(r=>release=r);locks.set(scope,done);await previous;try{return await fn();}finally{release();}},
 async load(s){return data.get(s)??null;},async compareAndSet(s,expected,v){if(this.failWrite)return false;if((data.get(s)??null)!==expected)return false;if(!this.lie)data.set(s,v);if(this.failAfter)throw Error('storage acknowledgement lost');return true;}};}
test('strictly compiled native client exercises all four routes',async t=>{const f=await setup(t),a=await f.client.session(),p=await f.client.prepare(a,crypto.randomUUID(),'gold');
 assert.equal(p.membershipActivated,false);assert.equal((await f.client.read(a,p.orderId)).paymentInstruction.amount,10000);
 await assert.rejects(f.client.receipt(a,p.orderId),e=>e.code==='receipt_not_available');await f.allocate(p.orderId);
 assert.equal((await f.client.receipt(a,p.orderId)).historical,true);});
test('coordinator persists original key before POST, restore never sends a POST',async t=>{const f=await setup(t),s=store();const original=f.env.CHECKOUT.prepare;
 f.env.CHECKOUT.prepare=async v=>{assert.equal([...s.data.values()].some(x=>JSON.parse(x).requestId===v.requestId),true);return original(v);};
 const c=new CheckoutCoordinator(f.client,s),p=await c.begin('gold'),before=f.seen.filter(x=>x.method==='POST').length,r=await c.restore();
 assert.equal(r.orderId,p.orderId);assert.equal(f.seen.filter(x=>x.method==='POST').length,before);assert.equal(JSON.stringify([...s.data.values()]).includes(f.tokens.accessToken),false);});
test('unknown network response survives restore and explicitly resumes same original request',async t=>{const f=await setup(t),s=store();let lose=true;
 const client=new MembershipApiClient(f.env.NATIVE_ORIGIN,24,async()=>f.tokens.accessToken,async(u,i)=>{const r=await f.transport(u,i);if(i.method==='POST'&&lose){lose=false;throw Error('network lost');}return r;});
 const c=new CheckoutCoordinator(client,s);await assert.rejects(c.begin('gold'),e=>e.outcome==='unknown');const state=await c.restore();assert.equal(state.phase,'pending');
 const before=f.payment.count('pa_checkout_requests');await assert.rejects(c.begin('silver'),e=>e.code==='unresolved_checkout');const p=await c.resume();assert.equal(p.requestId,state.requestId);assert.equal(f.payment.count('pa_checkout_requests'),before);});
for(const mode of ['failWrite','lie'])test(`recovery store ${mode} stops before any POST`,async t=>{const f=await setup(t),s=store();s[mode]=true;await assert.rejects(new CheckoutCoordinator(f.client,s).begin('gold'));assert.equal(f.seen.some(x=>x.method==='POST'),false);});
test('failed final recovery-state save retains a resumable original key',async t=>{const f=await setup(t),s=store();let n=0;const old=s.compareAndSet.bind(s);s.compareAndSet=async(...args)=>{if(++n===2)throw Error('durable storage failed');return old(...args);};
 const c=new CheckoutCoordinator(f.client,s);await assert.rejects(c.begin('gold'));const pending=await c.restore();assert.equal(pending.phase,'pending');assert.equal((await c.resume()).requestId,pending.requestId);assert.equal(f.payment.count('pa_checkout_requests'),1);});
test('account switch cannot resume another users recovery state',async t=>{const f=await setup(t),s=store(),c=new CheckoutCoordinator(f.client,s);await c.begin('gold');const other=await f.attacker();f.setToken(other.accessToken);assert.equal(await c.restore(),null);await assert.rejects(c.resume(),e=>e.code==='no_pending_checkout');});
test('session swap between selection and POST is rejected before network write',async t=>{const f=await setup(t),a=await f.client.session(),other=await f.attacker();f.setToken(other.accessToken);await assert.rejects(f.client.prepare(a,crypto.randomUUID(),'gold'),e=>e.code==='session_changed');assert.equal(f.seen.some(x=>x.method==='POST'),false);});
test('corrupted recovery document is not silently replaced',async t=>{const f=await setup(t),s=store(),a=await f.client.session();s.data.set(`africlub-membership-v1:24:${a.userId}`,'corrupt');await assert.rejects(new CheckoutCoordinator(f.client,s).begin('gold'));assert.equal(f.seen.some(x=>x.method==='POST'),false);});
for(const field of ['orderId','requestId','clubId','paymentVerified'])test(`malformed successful prepare ${field} is outcome unknown`,async t=>{const f=await setup(t),a=await f.client.session();const c=new MembershipApiClient(f.env.NATIVE_ORIGIN,24,async()=>f.tokens.accessToken,async(u,i)=>{const r=await f.transport(u,i),v=await r.json();v[field]=field==='paymentVerified'?true:'invalid';return Response.json(v);});await assert.rejects(c.prepare(a,crypto.randomUUID(),'gold'),e=>e.outcome==='unknown');assert.equal(f.payment.count('pa_checkout_requests'),1);});
for(const error of ['bad_json','oversize','wrong_type','redirect','unexpected_status'])test(`untrusted response ${error} cannot become a successful write`,async t=>{
 const f=await setup(t),a=await f.client.session();const c=new MembershipApiClient(f.env.NATIVE_ORIGIN,24,async()=>f.tokens.accessToken,async()=>{
  if(error==='bad_json')return new Response('{',{headers:{'content-type':'application/json'}});
  if(error==='oversize')return new Response(' '.repeat(17000),{headers:{'content-type':'application/json'}});
  if(error==='wrong_type')return new Response('{}',{headers:{'content-type':'text/html'}});
  if(error==='redirect')return new Response(null,{status:302,headers:{location:'https://attacker.invalid'}});
  return Response.json({schemaVersion:1,error:'raw_secret'},{status:500});});
 await assert.rejects(c.prepare(a,crypto.randomUUID(),'gold'),e=>e.outcome==='unknown'&&!e.message.includes('raw_secret'));});
test('client timeout does not retry writes',async t=>{const f=await setup(t),a=await f.client.session();let sends=0;const c=new MembershipApiClient(f.env.NATIVE_ORIGIN,24,async()=>f.tokens.accessToken,async()=>{sends++;return new Promise(()=>{});},10);await assert.rejects(c.prepare(a,crypto.randomUUID(),'gold'),e=>e.outcome==='unknown');assert.equal(sends,1);});
test('credentials never sent to a non-HTTPS or path-bearing origin',()=>{for(const origin of ['http://host.invalid','https://host.invalid/path','https://user:pass@host.invalid'])assert.throws(()=>new MembershipApiClient(origin,24,async()=>''));});
test('invalid tier rejected locally without preparing',async t=>{const f=await setup(t),a=await f.client.session();await assert.rejects(f.client.prepare(a,crypto.randomUUID(),'GOLD'));assert.equal(f.seen.some(x=>x.method==='POST'),false);});
test('read-only restore does not allocate or create a recovery document',async t=>{const f=await setup(t),s=store();assert.equal(await new CheckoutCoordinator(f.client,s).restore(),null);assert.equal(s.data.size,0);assert.equal(f.payment.count('pa_checkout_requests'),0);});

test('compiled current-membership client reads own status without creating checkout',async t=>{
 const f=await setup(t);f.payment.membership();const actor=await f.client.session(),r=await f.client.membershipStatus(actor);
 assert.equal(r.currentStatus,'active');assert.equal(r.isActive,true);assert.equal(r.historical,false);assert.equal(f.seen.some(x=>x.method==='POST'),false);
});
test('compiled current-membership client cannot treat historical allocation as suspension override',async t=>{
 const f=await setup(t),actor=await f.client.session(),prepared=await f.client.prepare(actor,crypto.randomUUID(),'gold');await f.allocate(prepared.orderId);
 const receipt=await f.client.receipt(actor,prepared.orderId);f.payment.db.sql.exec("UPDATE pa_memberships SET status='suspended'");
 assert.equal(receipt.membershipAtAllocation.status,'active');assert.equal((await f.client.membershipStatus(actor)).currentStatus,'suspended');
});
test('compiled current-membership client reports no-membership and expires reads correctly',async t=>{
 const f=await setup(t),actor=await f.client.session();assert.equal((await f.client.membershipStatus(actor)).currentStatus,'not_member');
 f.payment.membership({expires_at_ms:f.payment.db.time-1});const r=await f.client.membershipStatus(actor);assert.equal(r.currentStatus,'expired');assert.equal(r.isActive,false);
});
test('compiled current-membership client rejects foreign user projection',async t=>{
 const f=await setup(t);f.payment.membership();const actor=await f.client.session();const client=new MembershipApiClient(f.env.NATIVE_ORIGIN,24,async()=>f.tokens.accessToken,async(u,i)=>{
  const r=await f.transport(u,i);if(String(u).endsWith('/membership/status')){const v=await r.json();v.userId=crypto.randomUUID();return Response.json(v);}return r;
 });await assert.rejects(client.membershipStatus(actor));
});
test('compiled current-membership client rejects unknown upstream fields instead of persisting them',async t=>{
 const f=await setup(t);f.payment.membership();const actor=await f.client.session();const client=new MembershipApiClient(f.env.NATIVE_ORIGIN,24,async()=>f.tokens.accessToken,async(u,i)=>{
  const r=await f.transport(u,i);if(String(u).endsWith('/membership/status')){const v=await r.json();v.privateData='not-for-client';return Response.json(v);}return r;
 });await assert.rejects(client.membershipStatus(actor));
});
for(const [operation,mutate] of [
 ['checkout status',v=>{v.status=['allocated'];v.paymentEvidenceAllocated=false;}],
 ['receipt status',v=>{v.membershipAtAllocation.status=[v.membershipAtAllocation.status];}],
 ['membership recorded status',v=>{v.membership.recordedStatus=[v.membership.recordedStatus];}],
 ['membership payment status',v=>{v.membership.paymentStatus=[v.membership.paymentStatus];v.currentStatus='pending';v.isActive=false;}],
])test(`native client rejects array coercion in ${operation}`,async t=>{
 const f=await setup(t),actor=await f.client.session(),p=await f.client.prepare(actor,crypto.randomUUID(),'gold');await f.allocate(p.orderId);
 const client=new MembershipApiClient(f.env.NATIVE_ORIGIN,24,async()=>f.tokens.accessToken,async(u,i)=>{
  const r=await f.transport(u,i),v=await r.json();mutate(v);return Response.json(v);
 });
 const read=operation==='checkout status'?()=>client.read(actor,p.orderId):operation==='receipt status'?()=>client.receipt(actor,p.orderId):()=>client.membershipStatus(actor);
 await assert.rejects(read());
});
test('a malformed recovery phase cannot replace an unresolved operation with a new key',async t=>{
 const f=await setup(t),s=store(),a=await f.client.session();
 s.data.set(`africlub-membership-v1:24:${a.userId}`,JSON.stringify({version:1,userId:a.userId,clubId:24,requestId:crypto.randomUUID(),tier:'gold',phase:['pending'],orderId:crypto.randomUUID()}));
 await assert.rejects(new CheckoutCoordinator(f.client,s).begin('silver'),e=>e.code==='recovery_store_invalid');
 assert.equal(f.seen.some(x=>x.method==='POST'),false);
});
