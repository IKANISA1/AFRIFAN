import test from 'node:test';import assert from 'node:assert/strict';
import {Worker} from 'node:worker_threads';import {DatabaseSync} from 'node:sqlite';
import {mkdtempSync,rmSync} from 'node:fs';import {join} from 'node:path';import {tmpdir} from 'node:os';
import {handoffFixture,reservePrincipal,ids} from './handoff-fixture.mjs';
import {checkoutPrincipal} from './checkout-fixture.mjs';
async function concurrent(file,now,items){
 const gate=new SharedArrayBuffer(4),workers=[],ready=[],results=[];let timer;
 for(const item of items){let markReady,failReady;ready.push(new Promise((resolve,reject)=>{markReady=resolve;failReady=reject;}));
  const w=new Worker(new URL('./handoff-concurrent-worker.mjs',import.meta.url),{workerData:{file,now,gate,principal:reservePrincipal,operation:'reserve',...item}});workers.push(w);
  results.push(new Promise((resolve,reject)=>{w.on('error',e=>{failReady(e);reject(e);});w.on('message',v=>v.ready?markReady():resolve(v));w.on('exit',code=>{if(code){const e=Error('worker failed');failReady(e);reject(e);}});}));
 }
 try{return await Promise.race([(async()=>{await Promise.all(ready);Atomics.store(new Int32Array(gate),0,1);Atomics.notify(new Int32Array(gate),0);return Promise.all(results);})(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('concurrency deadline')),15000);})]);}
 finally{clearTimeout(timer);await Promise.all(workers.map(w=>w.terminate()));}
}

async function run(t,f,items){const dir=mkdtempSync(join(tmpdir(),'handoff-threads-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));const file=join(dir,'state.sqlite');f.db.sql.prepare('VACUUM INTO ?').run(file);const results=await concurrent(file,f.db.time,items),sql=new DatabaseSync(file);sql.function('test_now_ms',()=>f.db.time);t.after(()=>sql.close());return {results,sql};}
for(const same of [true,false])test('independent SQLite reserve connections: '+(same?'same key':'different keys'),async t=>{const f=await handoffFixture(t),a=f.handoffRequest,b={...a,requestId:same?a.requestId:crypto.randomUUID()};const {results:r,sql}=await run(t,f,[{input:a},{input:b}]);assert.equal(r.filter(x=>x.ok&&x.result.mayInvokeDialer).length,1,JSON.stringify(r));assert.equal(sql.prepare('SELECT count(*) n FROM pa_handoff_reservations').get().n,1);assert.equal(sql.prepare('SELECT count(*) n FROM pa_handoff_audit').get().n,1);assert.equal(sql.prepare('SELECT count(*) n FROM pa_memberships').get().n,0);if(same){assert.ok(r.every(x=>x.ok));assert.equal(r[0].result.handoffId,r[1].result.handoffId);}});
test('independent reservation versus checkout replacement has one coherent winner',async t=>{const f=await handoffFixture(t);f.addPackage({tier:'silver',annual_price:5000});const {results:r,sql}=await run(t,f,[{input:f.handoffRequest},{operation:'prepare',principal:checkoutPrincipal,input:f.request({tier:'silver'})}]);assert.ok(r[0].ok!==r[1].ok,JSON.stringify(r));assert.equal(sql.prepare('SELECT state FROM pa_orders WHERE order_id=?').get(f.snapshot.orderId).state,r[0].ok?'pending':'cancelled');assert.equal(sql.prepare('SELECT count(*) n FROM pa_handoff_slots').get().n,r[0].ok?1:0);});
test('independent reservation versus allocation never renews twice or falsifies settlement',async t=>{const f=await handoffFixture(t),o=f.orderFor(f.prepared),e=f.evidence(o);e.parsed.rawId=e.raw.id;await f.ingestion.ingest(e);const {results:r,sql}=await run(t,f,[{input:f.handoffRequest},{operation:'allocate',principal:ids.allocate,input:f.allocation(e,o)}]);assert.equal(r[1].ok,true,JSON.stringify(r));assert.equal(sql.prepare('SELECT count(*) n FROM pa_allocations').get().n,1);assert.equal(sql.prepare('SELECT count(*) n FROM pa_memberships').get().n,1);assert.equal(sql.prepare('SELECT count(*) n FROM pa_handoff_unresolved').get().n,0);});
