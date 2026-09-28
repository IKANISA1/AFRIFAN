import {test,before,after} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';import {tmpdir} from 'node:os';
import {join} from 'node:path';import {fileURLToPath,pathToFileURL} from 'node:url';
import {spawnSync} from 'node:child_process';
import {withPayments,ORIGIN} from './support/fixture.mjs';
import {createBrowserGateway} from '../src/index.mjs';
let Client,dir;
before(async()=>{
 dir=mkdtempSync(join(tmpdir(),'africlub-browser-client-'));
 const r=spawnSync('tsc',['--strict','--target','ES2022','--module','NodeNext','--moduleResolution','NodeNext','--lib','ES2022,DOM','--skipLibCheck',
  '--outDir',dir,fileURLToPath(new URL('../client.ts',import.meta.url))],{encoding:'utf8',timeout:30000});
 assert.equal(r.status,0,r.stdout+r.stderr);({BrowserMemberClient:Client}=await import(pathToFileURL(join(dir,'client.js'))));
});
after(()=>rmSync(dir,{recursive:true,force:true}));
async function setup(t){
 const f=await withPayments(t),jar=new Map(),memory=new Map(),calls=[];
 let lock=Promise.resolve();const storage={getItem:k=>memory.get(k)??null,setItem:(k,v)=>memory.set(k,v),removeItem:k=>memory.delete(k),
  async withLock(k,fn){const prior=lock;let release;lock=new Promise(r=>release=r);await prior;try{return await fn();}finally{release();}}};
 const transport=async(url,init)=>{
  calls.push({url,init});const h=new Headers(init.headers);h.set('cf-connecting-ip','203.0.113.21');h.set('sec-fetch-site','same-origin');
  if(init.method==='POST')h.set('origin',ORIGIN);
  if(jar.size)h.set('cookie',[...jar].map(([k,v])=>`${k}=${v}`).join('; '));
  const r=new Request(url,{...init,headers:h});Object.defineProperty(r,'cf',{value:{colo:'TEST'}});
  const response=await createBrowserGateway({clock:()=>f.clock.now}).fetch(r,f.env);
  for(const c of response.headers.getSetCookie()){
   const first=c.split(';')[0],i=first.indexOf('='),name=first.slice(0,i),value=first.slice(i+1);
   if(c.includes('Max-Age=0'))jar.delete(name);else jar.set(name,value);
  }
  return response;
 };
 const make=(patch={})=>new Client(ORIGIN,24,{fetch:transport,clock:()=>f.clock.now,recoveryStore:storage,...patch});
 const client=make();
 const login=async(c=client)=>{await c.start();const challenge=await c.challenge('+250700000001',f.key());
  const row=f.sql('SELECT * FROM auth_challenges WHERE challenge_id=?',challenge.challengeId)[0];
  const payload=await f.service.vault.open(row.delivery_cipher,`challenge:${challenge.challengeId}`);
  return c.verify(challenge.challengeId,payload.code,f.key());};
 return {...f,jar,memory,calls,storage,transport,make,client,login};
}
test('compiled client signs in and reads actual current membership',async t=>{
 const f=await setup(t);const s=await f.login();assert.equal(s.userId,f.ids.user);f.payment.membership();
 assert.equal((await f.client.membershipStatus()).isActive,true);
 for(const c of f.calls){assert.equal(c.init.credentials,'same-origin');assert.equal(c.init.redirect,'error');assert.equal(c.init.cache,'no-store');
  assert(!('authorization' in c.init.headers));assert(!('cookie' in c.init.headers));}
 assert.equal(f.memory.size,0);
});
test('constructing and restoring never performs a write',async t=>{
 const f=await setup(t);assert.equal(f.calls.length,0);await f.login();const before=f.calls.length;
 const c=f.make();assert.equal(f.calls.length,before);await c.restore();assert.equal(f.calls.at(-1).init.method,'GET');
});
test('browser client rotates and logs out through the actual gateway',async t=>{
 const f=await setup(t);const a=await f.login(),b=await f.client.rotate(f.key());assert.notEqual(a.csrfToken,b.csrfToken);
 await f.client.logout(f.key());assert.equal(f.jar.size,0);await assert.rejects(f.client.restore(),e=>e.status===401);
});
test('compiled checkout client persists before write then clears only validated acknowledgement',async t=>{
 const f=await setup(t);await f.login();const real=f.env.CHECKOUT.prepare;
 f.env.CHECKOUT.prepare=async v=>{assert.equal(f.memory.size,1);assert.equal(JSON.parse([...f.memory.values()][0]).requestId,v.requestId);return real(v);};
 const key=f.key(),p=await f.client.prepareCheckout('gold',key);assert.equal(p.requestId,key);assert.equal(f.memory.size,0);
 assert.equal((await f.client.checkout(p.orderId)).status,'pending_current');
});
test('lost response survives client recreation; read-only recovery does not submit another order',async t=>{
 const f=await setup(t);await f.login();let drop=true;
 const c=f.make({fetch:async(...a)=>{const r=await f.transport(...a);if(drop&&a[0].endsWith('/membership/checkouts')){drop=false;throw Error('lost');}return r;}});
 await c.restore();const key=f.key();await assert.rejects(c.prepareCheckout('gold',key),e=>e.outcomeUnknown&&e.requestId===key);
 assert.equal(f.memory.size,1);const before=f.payment.effects(),count=f.calls.length,c2=f.make();await c2.restore();
 assert.equal((await c2.pendingCheckout()).requestId,key);const found=await c2.recoverCheckout();assert.equal(found.found,true);
 assert.equal(found.result.requestId,key);assert.equal(f.memory.size,0);assert.deepEqual(f.payment.effects(),before);
 assert(f.calls.slice(count).every(c=>c.init.method==='GET'));
});
test('not-observed recovery retains pending identity and blocks a new key',async t=>{
 const f=await setup(t);await f.login();const c=f.make({fetch:async(...a)=>{if(a[0].endsWith('/membership/checkouts'))throw Error('before-send loss');return f.transport(...a);}});
 await c.restore();const key=f.key();await assert.rejects(c.prepareCheckout('gold',key),e=>e.outcomeUnknown);
 const c2=f.make();await c2.restore();assert.equal((await c2.recoverCheckout()).found,false);assert.equal(f.memory.size,1);
 await assert.rejects(c2.prepareCheckout('gold',f.key()),e=>e.code==='pending_checkout');assert.equal(f.payment.count('pa_checkout_requests'),0);
 const result=await c2.retryPendingCheckout();assert.equal(result.requestId,key);assert.equal(f.payment.count('pa_checkout_requests'),1);
});
test('same-owner reauthentication can recover original pending checkout without a changed key',async t=>{
 const f=await setup(t);await f.login();const real=f.env.CHECKOUT.prepare;f.env.CHECKOUT.prepare=async v=>{await real(v);throw Error('lost');};
 const key=f.key();await assert.rejects(f.client.prepareCheckout('gold',key),e=>e.outcomeUnknown);
 await f.client.logout(f.key());assert.equal(f.memory.size,1);await f.login();
 const r=await f.client.recoverCheckout();assert.equal(r.result.requestId,key);assert.equal(f.memory.size,0);
});
test('failed recovery storage prevents the outgoing checkout',async t=>{
 const f=await setup(t);await f.login();f.storage.setItem=()=>{throw Error('disk');};
 await assert.rejects(f.client.prepareCheckout('gold',f.key()),e=>e.code==='recovery_store_unavailable');
 assert(!f.calls.some(c=>c.url.endsWith('/membership/checkouts')));
});
test('storage readback mismatch fails before the network write',async t=>{
 const f=await setup(t);await f.login();f.storage.setItem=()=>{};
 await assert.rejects(f.client.prepareCheckout('gold',f.key()),e=>e.code==='recovery_store_unavailable');assert.equal(f.payment.count('pa_checkout_requests'),0);
});
test('corrupt persisted record blocks writes without deleting evidence',async t=>{
 const f=await setup(t),s=await f.login();const k=`africlub-browser-checkout:v1:${ORIGIN}:24:${s.userId}`;f.memory.set(k,'{corrupt');
 await assert.rejects(f.client.prepareCheckout('gold',f.key()),e=>e.code==='recovery_store_corrupt');assert.equal(f.memory.get(k),'{corrupt');
});
test('no injected durable lock-capable store means checkout is unavailable, not best effort',async t=>{
 const f=await setup(t);await f.login();const c=f.make({recoveryStore:undefined});await c.restore();
 await assert.rejects(c.prepareCheckout('gold',f.key()),e=>e.code==='recovery_store_required');assert.equal(f.payment.count('pa_checkout_requests'),0);
});
test('metadata store never receives OTP, phone number, CSRF or bearer credentials',async t=>{
 const f=await setup(t);const s=await f.login();f.env.CHECKOUT.prepare=async()=>{throw Error('uncertain');};
 await assert.rejects(f.client.prepareCheckout('gold',f.key()));const raw=[...f.memory.values()].join();
 for(const forbidden of ['+250700000001','accessToken','refreshToken','csrfToken',s.csrfToken,'sessionCookie'])assert(!raw.includes(forbidden));
});
test('rotated cookie with lost response can restore CSRF then explicitly retry original rotation',async t=>{
 const f=await setup(t);await f.login();let lost=true;const c=f.make({fetch:async(...args)=>{
  const r=await f.transport(...args);if(lost&&args[0].endsWith('/rotate')){lost=false;throw Error('body lost');}return r;}});
 await c.restore();const key=f.key();await assert.rejects(c.rotate(key),e=>e.outcomeUnknown);await c.restore();
 await c.rotate(key);assert.equal(f.count('auth_browser_rotations'),1);
});
for(const patch of [{clubId:26},{role:'admin'},{phoneVerified:false},{accessToken:'secret'},{expiresAt:1}])
 test('client rejects contradictory session '+Object.keys(patch)[0],async t=>{
 const f=await setup(t),s=await f.login();const c=f.make({fetch:async()=>Response.json({...s,...patch})});
 await assert.rejects(c.restore(),e=>e.code==='invalid_response');
});
test('malformed successful checkout response retains pending state and unknown outcome',async t=>{
 const f=await setup(t);await f.login();const c=f.make({fetch:async(...a)=>{const r=await f.transport(...a);if(a[0].endsWith('/membership/checkouts')){
  return Response.json({...await r.json(),membershipActivated:true});}return r;}});await c.restore();
 const key=f.key();await assert.rejects(c.prepareCheckout('gold',key),e=>e.code==='invalid_response'&&e.outcomeUnknown&&e.requestId===key);assert.equal(f.memory.size,1);
});
test('read failure is not labelled as an unknown write',async t=>{
 const f=await setup(t),c=f.make({fetch:async()=>{throw Error('offline');}});await assert.rejects(c.restore(),e=>!e.outcomeUnknown);
});
for(const origin of ['http://browser.example.invalid',ORIGIN+'/path',ORIGIN+'?query=1','https://a:b@browser.example.invalid'])
 test('client rejects noncanonical origin '+origin,()=>assert.throws(()=>new Client(origin,24)));
