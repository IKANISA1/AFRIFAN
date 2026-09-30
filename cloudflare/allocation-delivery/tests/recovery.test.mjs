import test from 'node:test';import assert from 'node:assert/strict';
import {Worker} from 'node:worker_threads';import {mkdtempSync,rmSync,readFileSync} from 'node:fs';import {tmpdir} from 'node:os';import {join} from 'node:path';
import {recoveryFixture,TestD1,ids,MAKER,CHECKER,CHECKER2} from './recovery/fixture.mjs';
import {DeliveryRecovery} from '../src/recovery.mjs';import {drain} from '../src/dispatcher.mjs';
const deny=(fn,code)=>assert.rejects(fn,e=>e.code===code);
async function use(t,fn){const f=await recoveryFixture();t.after(()=>f.close());await fn(f);}
function effects(f){return {ledger:f.count('pa_ledger'),members:f.count('pa_memberships'),claims:f.count('pa_external_claims'),outbox:f.count('pa_outbox'),sink:f.sinkDb.sql.prepare('SELECT count(*) n FROM adi_events').get().n};}
async function race(data){
 const workers=data.map(workerData=>new Worker(new URL('./recovery/recovery-race-worker.mjs',import.meta.url),{workerData}));
 try{
  await Promise.all(workers.map(w=>new Promise((res,rej)=>{w.once('message',res);w.once('error',rej);})));
  const results=workers.map(w=>new Promise((res,rej)=>{w.once('message',res);w.once('error',rej);w.once('exit',c=>{if(c)rej(Error('worker failed'));});}));
  workers.forEach(w=>w.postMessage('go'));return await Promise.all(results);
 }finally{await Promise.all(workers.map(w=>w.terminate()));}
}
test('prepare records no dispatch, financial change or re-drive; checker atomically retains one original command',t=>use(t,async f=>{
 const before=effects(f),commands=f.count('pa_delivery_commands');
 const prepared=await f.maker.prepare(f.request);assert.equal(prepared.state,'prepared');assert.equal(prepared.makerSelf,true);
 assert.deepEqual(await f.maker.prepare(f.request),prepared);assert.equal(f.count('pa_delivery_commands'),commands);assert.deepEqual(effects(f),before);
 assert.equal((await f.checker.decision({clubId:24,decisionId:f.request.decisionId})).makerSelf,false);
 const receipt=await f.checker.confirm(f.confirm);assert.equal(receipt.committed,true);assert.equal(receipt.operationId,f.request.operationId);
 assert.deepEqual(await f.checker.confirm(f.confirm),receipt);assert.equal(f.count('pa_delivery_commands'),commands+1);assert.deepEqual(effects(f),before);
 assert.equal((await drain(f.runner)).stored,1);assert.equal(f.count('pa_ledger'),before.ledger);assert.equal(f.count('pa_outbox'),1);
 assert.equal(f.sinkDb.sql.prepare('SELECT event_id FROM adi_events').get().event_id,f.request.eventId);
 assert.deepEqual(await f.checker.confirm(f.confirm),receipt);assert.equal((await drain(f.runner)).examined,0);
}));
test('mutation replay cannot change decision evidence, original command key or retained reason',t=>use(t,async f=>{
 await f.maker.prepare(f.request);
 for(const patch of [{operationId:crypto.randomUUID()},{evidenceSha256:'cd'.repeat(32)},{reason:'configuration_corrected'}])
  await deny(()=>f.maker.prepare({...f.request,...patch}),'idempotency_conflict');
 for(const patch of [{operationId:crypto.randomUUID()},{evidenceSha256:'cd'.repeat(32)},{expectedRevision:f.request.expectedRevision+1}])
  await deny(()=>f.checker.confirm({...f.confirm,...patch}),'conflict');
 assert.equal(f.db.sql.prepare("SELECT count(*) n FROM pa_delivery_commands WHERE action='redrive'").get().n,0);
}));
test('maker cannot confirm; dispatcher cannot prepare even with review role; checker cannot replace prior confirmer',t=>use(t,async f=>{
 await f.maker.prepare(f.request);await deny(()=>f.maker.confirm(f.confirm),'permission_denied');
 f.db.sql.prepare("INSERT INTO pa_delivery_grants VALUES(?,24,'review',1)").run(ids.outbox);
 await deny(()=>new DeliveryRecovery(f.recoveryEnv,ids.outbox).prepare({...f.request,decisionId:crypto.randomUUID(),operationId:crypto.randomUUID()}),'conflict');
 await f.checker.confirm(f.confirm);await deny(()=>f.checker2.confirm(f.confirm),'idempotency_conflict');
}));
test('applied recovery lineage blocks legacy direct re-drive before any event change',t=>use(t,async f=>{
 const input={clubId:24,eventId:f.request.eventId,expectedRevision:f.request.expectedRevision,requestId:crypto.randomUUID(),reason:'dependency_restored'};
 await deny(()=>f.review.redrive(input),'permission_denied');assert.equal((await f.maker.inspectEvent({clubId:24,eventId:f.request.eventId})).state,'dead');
}));
test('expired decision requires a fresh explicitly prepared decision and creates no command',t=>use(t,async f=>{
 await f.maker.prepare(f.request);f.advance(300000);await deny(()=>f.checker.confirm(f.confirm),'conflict');
 assert.equal(f.db.sql.prepare("SELECT count(*) n FROM pa_delivery_commands WHERE action='redrive'").get().n,0);
 const fresh={...f.request,decisionId:crypto.randomUUID(),operationId:crypto.randomUUID()};await f.maker.prepare(fresh);
 assert.equal((await f.checker.confirm({...f.confirm,decisionId:fresh.decisionId,operationId:fresh.operationId})).committed,true);
}));
for(const [name,change] of [
 ['maker revoked',f=>f.db.sql.prepare('UPDATE pa_principals SET enabled=0 WHERE principal_id=?').run(MAKER)],
 ['checker revoked',f=>f.db.sql.prepare('UPDATE pa_principals SET enabled=0 WHERE principal_id=?').run(CHECKER)],
 ['review grant revoked',f=>f.db.sql.prepare("UPDATE pa_delivery_grants SET enabled=0 WHERE principal_id=? AND role='review'").run(CHECKER)],
 ['club revoked',f=>f.db.sql.exec('UPDATE pa_clubs SET enabled=0 WHERE club_id=24')],
 ['source reconciliation revoked',f=>f.db.sql.exec('UPDATE pa_settings SET source_reconciled=0')],
 ['recovery disabled',f=>f.db.sql.exec('UPDATE pa_recovery_control SET enabled=0')]
])test(`confirmation rechecks ${name} at mutation boundary`,t=>use(t,async f=>{
 await f.maker.prepare(f.request);f.db.beforeRun=()=>change(f);await assert.rejects(()=>f.checker.confirm(f.confirm));
 assert.equal(f.db.sql.prepare('SELECT state FROM pa_recovery_decisions').get().state,'prepared');
 assert.equal(f.db.sql.prepare("SELECT count(*) n FROM pa_delivery_commands WHERE action='redrive'").get().n,0);
}));
test('prepare/confirmation lost commit acknowledgements recover the same retained decision and receipt',t=>use(t,async f=>{
 f.db.loseRun=true;const prepared=await f.maker.prepare(f.request);assert.equal(prepared.state,'prepared');assert.equal(f.count('pa_recovery_decisions'),1);
 f.db.loseRun=true;const receipt=await f.checker.confirm(f.confirm);assert.equal(receipt.committed,true);
 assert.equal(f.db.sql.prepare("SELECT count(*) n FROM pa_delivery_commands WHERE action='redrive'").get().n,1);
 assert.deepEqual(await f.checker.confirm(f.confirm),receipt);
}));
test('transaction failure during command application rolls back decision confirmation and job together',t=>use(t,async f=>{
 await f.maker.prepare(f.request);f.db.sql.exec("CREATE TRIGGER synthetic_fail_redrive BEFORE INSERT ON pa_delivery_commands WHEN NEW.action='redrive' BEGIN SELECT RAISE(ABORT,'synthetic injected failure'); END;");
 await assert.rejects(()=>f.checker.confirm(f.confirm));assert.equal(f.db.sql.prepare('SELECT state FROM pa_recovery_decisions').get().state,'prepared');
 assert.equal((await f.maker.inspectEvent({clubId:24,eventId:f.request.eventId})).state,'dead');
 f.db.sql.exec('DROP TRIGGER synthetic_fail_redrive');assert.equal((await f.checker.confirm(f.confirm)).committed,true);
}));
test('cross-club requests and request-selected principals never obtain a receipt or mutate an event',t=>use(t,async f=>{
 await f.maker.prepare(f.request);
 await deny(()=>f.checker.confirm({...f.confirm,clubId:25}),'conflict');
 await deny(()=>f.maker.prepare({...f.request,clubId:25,decisionId:crypto.randomUUID(),operationId:crypto.randomUUID()}),'conflict');
 await deny(()=>f.checker.confirm({...f.confirm,principalId:CHECKER}),'invalid_request');
 assert.equal(f.db.sql.prepare("SELECT count(*) n FROM pa_delivery_commands WHERE action='redrive'").get().n,0);
}));
for(const patch of [{reason:['dependency_restored']},{expectedRevision:true},{evidenceSha256:'not-a-sha'},{evidenceRef:'https://private.test/token'},
 {phone:'secret'},{clubId:'24'}])test(`rejects invalid decision ${Object.keys(patch)[0]}`,t=>use(t,async f=>{
 await deny(()=>f.maker.prepare({...f.request,...patch}),'invalid_request');assert.equal(f.count('pa_recovery_decisions'),0);
}));
test('decision identity/evidence and confirmed history reject direct update and deletion',t=>use(t,async f=>{
 await f.maker.prepare(f.request);assert.throws(()=>f.db.sql.exec("UPDATE pa_recovery_decisions SET reason='configuration_corrected'"));
 assert.throws(()=>f.db.sql.exec('DELETE FROM pa_recovery_decisions'));await f.checker.confirm(f.confirm);
 assert.throws(()=>f.db.sql.exec("UPDATE pa_recovery_decisions SET confirmed_at_ms=confirmed_at_ms+1"));
}));
test('independent checker connections racing the same decision retain exactly one command',t=>use(t,async f=>{
 await f.maker.prepare(f.request);const dir=mkdtempSync(join(tmpdir(),'africlub-recovery-race-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));
 const file=join(dir,'source.sqlite');f.db.sql.prepare('VACUUM INTO ?').run(file);
 const replies=await race([CHECKER,CHECKER2].map(principal=>({file,operation:'confirm',principal,input:f.confirm})));
 assert.equal(replies.filter(x=>x.ok).length,1);assert.ok(['conflict','idempotency_conflict'].includes(replies.find(x=>!x.ok).code));
 const d=new TestD1(file);try{assert.equal(d.sql.prepare("SELECT count(*) n FROM pa_delivery_commands WHERE action='redrive'").get().n,1);assert.equal(d.sql.prepare('SELECT state FROM pa_delivery_jobs').get().state,'pending');}finally{d.close();}
}));
test('independent identical checker retries return the same immutable command receipt',t=>use(t,async f=>{
 await f.maker.prepare(f.request);const dir=mkdtempSync(join(tmpdir(),'africlub-recovery-replay-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));
 const file=join(dir,'source.sqlite');f.db.sql.prepare('VACUUM INTO ?').run(file);
 const replies=await race([1,2].map(()=>({file,operation:'confirm',principal:CHECKER,input:f.confirm})));
 assert.equal(replies.filter(x=>x.ok).length,2);assert.deepEqual(replies[0].result,replies[1].result);
 const d=new TestD1(file);try{assert.equal(d.sql.prepare("SELECT count(*) n FROM pa_delivery_commands WHERE action='redrive'").get().n,1);}finally{d.close();}
}));
test('two prepared decisions racing a stale event revision cannot both redrive',t=>use(t,async f=>{
 const other={...f.request,decisionId:crypto.randomUUID(),operationId:crypto.randomUUID()};await f.maker.prepare(f.request);await f.maker.prepare(other);
 const dir=mkdtempSync(join(tmpdir(),'africlub-recovery-stale-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));const file=join(dir,'source.sqlite');f.db.sql.prepare('VACUUM INTO ?').run(file);
 const replies=await race([f.confirm,{...f.confirm,decisionId:other.decisionId,operationId:other.operationId}].map(input=>({file,operation:'confirm',principal:CHECKER,input})));
 assert.equal(replies.filter(x=>x.ok).length,1);assert.equal(replies.find(x=>!x.ok).code,'conflict');
 const d=new TestD1(file);try{assert.equal(d.sql.prepare("SELECT count(*) n FROM pa_delivery_commands WHERE action='redrive'").get().n,1);}finally{d.close();}
}));
test('new migration starts disabled and entrypoints expose only trusted named bindings',()=>{
 const sql=readFileSync(new URL('../migrations_source/0007_approved_recovery.sql',import.meta.url),'utf8');assert.match(sql,/VALUES\(1,0,300000,'UNAPPROVED'\)/);
 const worker=readFileSync(new URL('../src/recovery-worker.mjs',import.meta.url),'utf8');assert.match(worker,/RECOVERY_MAKER_PRINCIPAL_ID/);assert.match(worker,/RECOVERY_CHECKER_PRINCIPAL_ID/);
 assert.doesNotMatch(worker,/input\.principal|console\./);
});
