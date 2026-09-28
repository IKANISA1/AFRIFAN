import test from 'node:test';import assert from 'node:assert/strict';
import {Worker} from 'node:worker_threads';import {DatabaseSync} from 'node:sqlite';
import {mkdtempSync,rmSync} from 'node:fs';import {join} from 'node:path';import {tmpdir} from 'node:os';
import {checkoutFixture,checkoutPrincipal,ids} from './checkout-fixture.mjs';
async function concurrent(file,now,items){
 const gate=new SharedArrayBuffer(4),workers=[],ready=[],results=[];let timer;
 for(const item of items){let markReady,failReady;ready.push(new Promise((resolve,reject)=>{markReady=resolve;failReady=reject;}));
  const w=new Worker(new URL('./checkout-concurrent-worker.mjs',import.meta.url),{workerData:{file,now,gate,principal:checkoutPrincipal,operation:'prepare',...item}});workers.push(w);
  results.push(new Promise((resolve,reject)=>{w.on('error',e=>{failReady(e);reject(e);});w.on('message',v=>v.ready?markReady():resolve(v));w.on('exit',code=>{if(code){const e=Error('worker failed');failReady(e);reject(e);}});}));
 }
 try{return await Promise.race([(async()=>{await Promise.all(ready);Atomics.store(new Int32Array(gate),0,1);Atomics.notify(new Int32Array(gate),0);return Promise.all(results);})(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('concurrency deadline')),15000);})]);}
 finally{clearTimeout(timer);await Promise.all(workers.map(w=>w.terminate()));}
}
for(const mode of ['same-key','different-key','competing-tiers'])test(`checkout independent SQLite connections: ${mode}`,async t=>{
 const f=checkoutFixture();t.after(()=>f.close());const dir=mkdtempSync(join(tmpdir(),'checkout-concurrency-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));
 const a=f.request(),b={...a,requestId:mode==='same-key'?a.requestId:crypto.randomUUID()};
 if(mode==='competing-tiers'){f.addPackage({tier:'silver',annual_price:5000});b.tier='silver';}
 const file=join(dir,'state.sqlite');f.db.sql.prepare('VACUUM INTO ?').run(file);
 const r=await concurrent(file,f.db.time,[{input:a},{input:b}]);assert.ok(r.every(x=>x.ok),JSON.stringify(r));
 const db=new DatabaseSync(file);try{
  assert.equal(db.prepare("SELECT count(*) n FROM pa_orders WHERE state='pending' AND kind='membership'").get().n,1);
  assert.equal(db.prepare('SELECT count(*) n FROM pa_memberships').get().n,0);
  assert.equal(db.prepare('SELECT count(*) n FROM pa_checkout_order_details').get().n,mode==='competing-tiers'?2:1);
  if(mode==='same-key')assert.deepEqual(r[0].result,r[1].result);
  if(mode==='different-key')assert.deepEqual(r[0].result.checkout,r[1].result.checkout);
 }finally{db.close();}
});
test('independent checkout replacement versus allocation serializes safely',async t=>{
 const f=checkoutFixture();t.after(()=>f.close());const first=await f.checkout.prepare(f.request()),order=f.orderFor(first),e=f.evidence(order);e.parsed.rawId=e.raw.id;await f.ingestion.ingest(e);f.addPackage({tier:'silver',annual_price:5000});
 const dir=mkdtempSync(join(tmpdir(),'checkout-allocation-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));const file=join(dir,'state.sqlite');f.db.sql.prepare('VACUUM INTO ?').run(file);
 const r=await concurrent(file,f.db.time,[{input:f.request({tier:'silver'})},{input:f.allocation(e,order),operation:'allocate',principal:ids.allocate}]);
 assert.equal(r[0].ok,true,JSON.stringify(r));if(!r[1].ok)assert.equal(r[1].code,'binding_conflict');
 const db=new DatabaseSync(file);try{assert.equal(db.prepare('SELECT count(*) n FROM pa_memberships').get().n,r[1].ok?1:0);assert.equal(db.prepare('SELECT state FROM pa_orders WHERE order_id=?').get(order.order_id).state,r[1].ok?'fulfilled':'cancelled');assert.equal(db.prepare("SELECT count(*) n FROM pa_orders WHERE state='pending'").get().n,1);}finally{db.close();}
});
