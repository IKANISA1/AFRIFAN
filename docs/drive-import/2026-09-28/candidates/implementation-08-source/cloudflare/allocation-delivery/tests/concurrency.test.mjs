import test from 'node:test';import assert from 'node:assert/strict';
import {Worker} from 'node:worker_threads';import {mkdtempSync,rmSync} from 'node:fs';import {tmpdir} from 'node:os';import {join} from 'node:path';
import {fixture,claimed,TestD1} from './fixture.mjs';
async function race(data){
 const workers=data.map(workerData=>new Worker(new URL('./race-worker.mjs',import.meta.url),{workerData}));
 try{
  await Promise.all(workers.map(w=>new Promise((res,rej)=>{w.once('message',res);w.once('error',rej);}))); 
  const replies=workers.map(w=>new Promise((res,rej)=>{w.once('message',res);w.once('error',rej);w.once('exit',code=>{if(code)rej(Error('worker failed'));});}));
  workers.forEach(w=>w.postMessage('go'));return await Promise.all(replies);
 }finally{await Promise.all(workers.map(w=>w.terminate()));}
}
async function use(t,fn){const f=await fixture(),dir=mkdtempSync(join(tmpdir(),'africlub-delivery-race-'));t.after(()=>{f.close();rmSync(dir,{recursive:true,force:true});});return fn(f,dir);}
function copy(db,path){db.sql.prepare('VACUUM INTO ?').run(path);}
test('two independent source connections grant one event lease',t=>use(t,async(f,dir)=>{
 const file=join(dir,'source.db');copy(f.db,file);
 const replies=await race([{file,operation:'take'},{file,operation:'take'}]);
 assert.equal(replies.filter(r=>r.ok&&r.result.event!==null).length,1);
 const d=new TestD1(file);try{assert.equal(d.sql.prepare("SELECT count(*) n FROM pa_delivery_commands WHERE action='claim'").get().n,1);}finally{d.close();}
}));
test('legacy claim and new ownership cannot both win from independent connections',t=>use(t,async(f,dir)=>{
 const file=join(dir,'source.db');copy(f.db,file);
 const replies=await race([{file,operation:'take'},{file,operation:'legacy'}]);
 const newWon=replies[0].ok&&replies[0].result.event!==null;
 const legacyWon=replies[1].ok&&replies[1].result.events.length===1;
 assert.notEqual(Boolean(newWon),Boolean(legacyWon));
}));
test('two independent receiver connections deduplicate an identical event',t=>use(t,async(f,dir)=>{
 const {event}=await claimed(f),file=join(dir,'inbox.db');copy(f.sinkDb,file);
 const replies=await race([{file,operation:'accept',input:event},{file,operation:'accept',input:event}]);
 assert.equal(replies.filter(r=>r.ok).length,2);assert.deepEqual(replies[0].result,replies[1].result);
 const d=new TestD1(file);try{assert.equal(d.sql.prepare('SELECT count(*) n FROM adi_events').get().n,1);}finally{d.close();}
}));
test('conflicting concurrent receiver payloads cannot replace each other',t=>use(t,async(f,dir)=>{
 const {event}=await claimed(f),file=join(dir,'inbox.db');copy(f.sinkDb,file);
 const replies=await race([{file,operation:'accept',input:event},{file,operation:'accept',input:{...event,userId:crypto.randomUUID()}}]);
 assert.equal(replies.filter(r=>r.ok).length,1);assert.equal(replies.find(r=>!r.ok).code,'idempotency_conflict');
}));
test('competing dead-letter reviewers cannot both update the same revision',t=>use(t,async(f,dir)=>{
 const {claim}=await claimed(f);
 await f.source.finish({clubId:24,eventId:claim.eventId,leaseId:claim.leaseId,expectedRevision:claim.revision,requestId:crypto.randomUUID(),outcome:'dead',reason:'invalid_event',receiptId:null});
 const input={clubId:24,eventId:claim.eventId,expectedRevision:claim.revision+1,reason:'configuration_corrected'};
 const file=join(dir,'source.db');copy(f.db,file);
 const replies=await race([{file,operation:'redrive',input:{...input,requestId:crypto.randomUUID()}},{file,operation:'redrive',input:{...input,requestId:crypto.randomUUID()}}]);
 assert.equal(replies.filter(r=>r.ok).length,1);assert.equal(replies.find(r=>!r.ok).code,'conflict');
}));
