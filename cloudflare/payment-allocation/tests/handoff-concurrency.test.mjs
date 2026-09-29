import test from 'node:test';import assert from 'node:assert/strict';
import {Worker} from 'node:worker_threads';import {DatabaseSync} from 'node:sqlite';
import {mkdtempSync,rmSync,readFileSync} from 'node:fs';import {join} from 'node:path';import {tmpdir} from 'node:os';
import {checkoutFixture,checkoutPrincipal,ids} from './checkout-fixture.mjs';
async function concurrent(file,now,items){
 const gate=new SharedArrayBuffer(4),workers=[],ready=[],results=[];let timer;
 for(const item of items){let markReady,failReady;ready.push(new Promise((resolve,reject)=>{markReady=resolve;failReady=reject;}));
  const w=new Worker(new URL('./handoff-concurrent-worker.mjs',import.meta.url),{workerData:{file,now,gate,principal:checkoutPrincipal,operation:'prepare',...item}});workers.push(w);
  results.push(new Promise((resolve,reject)=>{w.on('error',e=>{failReady(e);reject(e);});w.on('message',v=>v.ready?markReady():resolve(v));w.on('exit',code=>{if(code){const e=Error('worker failed');failReady(e);reject(e);}});}));
 }
 try{return await Promise.race([(async()=>{await Promise.all(ready);Atomics.store(new Int32Array(gate),0,1);Atomics.notify(new Int32Array(gate),0);return Promise.all(results);})(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('concurrency deadline')),15000);})]);}
 finally{clearTimeout(timer);await Promise.all(workers.map(w=>w.terminate()));}
}

import {PaymentHandoffService} from '../src/handoff-service.mjs';import {NOW_SQL} from '../src/policy.mjs';
async function prepared(t){const f=checkoutFixture();t.after(()=>f.close());
 f.db.sql.exec(readFileSync(new URL('../migrations/0003_payment_handoff_journal.sql',import.meta.url),'utf8').replaceAll(NOW_SQL,'test_now_ms()'));
f.db.sql.exec(readFileSync(new URL('../migrations/0004_release_unclaimed_handoff.sql',import.meta.url),'utf8').replaceAll(NOW_SQL,'test_now_ms()'));
 f.env.HANDOFF_JOURNAL_ENABLED='true';f.db.sql.exec('UPDATE pa_handoff_settings SET enabled=1');
 const order=await f.checkout.prepare(f.request()),service=new PaymentHandoffService(f.env,checkoutPrincipal),scope={clubId:24,userId:ids.user};
 const reservation=await service.reserveHandoff({...scope,orderId:order.checkout.orderId,requestId:crypto.randomUUID()});
 const dir=mkdtempSync(join(tmpdir(),'handoff-concurrency-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));
 return {...f,order,scope,reservation,file:join(dir,'state.sqlite')};}
for(const same of [true,false])test('independent connections grant exactly once: '+(same?'same key':'different key'),async t=>{
 const f=await prepared(t),a={...f.scope,handoffId:f.reservation.handoff.handoffId,requestId:crypto.randomUUID()},b={...a,requestId:same?a.requestId:crypto.randomUUID()};
 f.db.sql.prepare('VACUUM INTO ?').run(f.file);
 const r=await concurrent(f.file,f.db.time,[{operation:'claimHandoff',input:a},{operation:'claimHandoff',input:b}]);
 assert.ok(r.every(x=>x.ok),JSON.stringify(r));assert.equal(r.filter(x=>x.result.mayOpenDialer).length,1);
 const db=new DatabaseSync(f.file);try{assert.equal(db.prepare('SELECT count(*) n FROM pa_handoff_claims').get().n,1);assert.equal(db.prepare('SELECT count(*) n FROM pa_memberships').get().n,0);}finally{db.close();}
});
test('independent replacement racing claim cannot cancel a claimed order',async t=>{
 const f=await prepared(t);f.addPackage({tier:'silver',annual_price:5000});f.db.sql.prepare('VACUUM INTO ?').run(f.file);
 const r=await concurrent(f.file,f.db.time,[{operation:'claimHandoff',input:{...f.scope,handoffId:f.reservation.handoff.handoffId,requestId:crypto.randomUUID()}},{operation:'prepare',input:f.request({tier:'silver'})}]);
 const db=new DatabaseSync(f.file);try{const count=db.prepare('SELECT count(*) n FROM pa_handoff_claims').get().n,state=db.prepare('SELECT state FROM pa_orders WHERE order_id=?').get(f.order.checkout.orderId).state;
 assert.ok(count===0||count===1);if(count===1){assert.equal(state,'pending');assert.equal(r[1].ok,false);}else{assert.equal(state,'cancelled');assert.equal(r[0].ok,false);assert.equal(r[1].ok,true);}assert.equal(db.prepare('SELECT count(*) n FROM pa_memberships').get().n,0);
 }finally{db.close();}
});

for(const same of [true,false])test('independent release retries commit one record: '+same,async t=>{
 const f=await prepared(t);f.db.sql.exec('UPDATE pa_handoff_release_settings SET enabled=1');const a={...f.scope,handoffId:f.reservation.handoff.handoffId,requestId:crypto.randomUUID()},b={...a,requestId:same?a.requestId:crypto.randomUUID()};f.db.sql.prepare('VACUUM INTO ?').run(f.file);
 const replies=await concurrent(f.file,f.db.time,[{operation:'releaseHandoff',input:a},{operation:'releaseHandoff',input:b}]);
 const db=new DatabaseSync(f.file);try{assert.equal(db.prepare('SELECT count(*) n FROM pa_handoff_releases').get().n,1);assert.equal(db.prepare('SELECT count(*) n FROM pa_handoff_claims').get().n,0);assert.equal(replies.filter(x=>x.ok).length,same?2:1);assert.ok(replies.filter(x=>x.ok).every(x=>!x.result.mayOpenDialer));}finally{db.close();}
});
for(const reversed of [false,true])test('independent release vs claim has exactly one winner: '+reversed,async t=>{
 const f=await prepared(t);f.db.sql.exec('UPDATE pa_handoff_release_settings SET enabled=1');const input={...f.scope,handoffId:f.reservation.handoff.handoffId,requestId:crypto.randomUUID()};f.db.sql.prepare('VACUUM INTO ?').run(f.file);const items=[{operation:'releaseHandoff',input},{operation:'claimHandoff',input:{...input,requestId:crypto.randomUUID()}}];if(reversed)items.reverse();
 await concurrent(f.file,f.db.time,items);const db=new DatabaseSync(f.file);try{const releases=db.prepare('SELECT count(*) n FROM pa_handoff_releases').get().n,claims=db.prepare('SELECT count(*) n FROM pa_handoff_claims').get().n;assert.equal(releases+claims,1);assert.equal(db.prepare('SELECT count(*) n FROM pa_memberships').get().n,0);}finally{db.close();}
});
