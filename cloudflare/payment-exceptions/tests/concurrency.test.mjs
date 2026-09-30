import test from 'node:test';
import assert from 'node:assert/strict';
import {Worker} from 'node:worker_threads';
import {mkdtempSync,rmSync} from 'node:fs';import {tmpdir} from 'node:os';import {join} from 'node:path';
import {fixture} from './fixture.mjs';
async function race(path,inputs){
 const gate=new SharedArrayBuffer(4),view=new Int32Array(gate);let ready=0;const workers=[];
 try{return await Promise.all(inputs.map(input=>new Promise((resolve,reject)=>{
  const w=new Worker(new URL('./race-worker.mjs',import.meta.url),{workerData:{path,input,gate}});workers.push(w);let result=false;
  w.on('message',m=>{if(m.ready){if(++ready===inputs.length){Atomics.store(view,0,1);Atomics.notify(view,0);}}else{result=true;resolve(m);}});
  w.on('error',reject);w.on('exit',c=>{if(!result)reject(Error('Worker exited '+c));});
 })));}finally{await Promise.all(workers.map(w=>w.terminate()));}
}
function setup(t){const dir=mkdtempSync(join(tmpdir(),'px-race-')),path=join(dir,'cases.sqlite');const f=fixture(null,path);f.db.sql.exec('PRAGMA journal_mode=WAL');t.after(()=>{f.db.close();rmSync(dir,{recursive:true,force:true});});return {...f,path};}
test('independent SQLite connections: concurrent proposals commit exactly one head',async t=>{
 const f=setup(t),o=await f.open();const inputs=[1,2].map(()=>f.command({caseId:o.input.caseId,expectedRevision:1,action:'propose',detail:{reasonCode:'review_complete',evidenceDigest:'d'.repeat(64),disposition:'refer_reconciliation'}}));
 const results=await race(f.path,inputs);assert.equal(results.filter(r=>r.ok).length,1);assert.equal(results.filter(r=>r.code==='stale_revision').length,1);assert.equal(f.count(),2);
});
test('independent SQLite connections: approve versus reject cannot both commit',async t=>{
 const f=setup(t),o=await f.open();await f.transition(o.input.caseId,'propose');
 const inputs=['approve','reject'].map(action=>f.command({identity:f.identity('checker'),caseId:o.input.caseId,expectedRevision:2,action,detail:{reasonCode:'review_complete',evidenceDigest:null}}));
 const results=await race(f.path,inputs);assert.equal(results.filter(r=>r.ok).length,1);assert.equal(results.filter(r=>r.code==='stale_revision').length,1);assert.equal(f.count(),3);
});
test('independent SQLite connections: duplicated operation returns the same durable event',async t=>{
 const f=setup(t),i=f.command();const results=await race(f.path,[i,i]);assert.equal(results.filter(r=>r.ok).length,2);assert.equal(results[0].result.outcome.eventId,results[1].result.outcome.eventId);assert.equal(f.count(),1);
});
