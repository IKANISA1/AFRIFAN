import test from 'node:test';import assert from 'node:assert/strict';
import {mkdtempSync,rmSync,chmodSync,symlinkSync} from 'node:fs';import {tmpdir} from 'node:os';import {join} from 'node:path';import {spawnSync} from 'node:child_process';import {pathToFileURL} from 'node:url';
import {recoveryFixture} from './recovery/fixture.mjs';import {LocalRecoveryJournal} from '../../../tools/scripts/local_ops_rehearsal_journal.mjs';
const compiledDir=mkdtempSync(join(tmpdir(),'africlub-recovery-client-'));
const compiled=spawnSync('tsc',[new URL('../recovery-client.ts',import.meta.url).pathname,'--strict','--target','ES2022','--module','NodeNext','--moduleResolution','NodeNext','--outDir',compiledDir],{encoding:'utf8'});
assert.equal(compiled.status,0,compiled.stdout+compiled.stderr);
const {DeliveryRecoveryClient}=await import(pathToFileURL(join(compiledDir,'recovery-client.js')));process.on('exit',()=>rmSync(compiledDir,{recursive:true,force:true}));
async function use(t,fn){const f=await recoveryFixture(),dir=mkdtempSync(join(tmpdir(),'africlub-recovery-journal-'));chmodSync(dir,0o700);
 const scopeId=crypto.randomUUID(),journal=new LocalRecoveryJournal(join(dir,'maker.sqlite'),{clubId:24,role:'maker',scopeId});
 t.after(()=>{journal.close();f.close();rmSync(dir,{recursive:true,force:true});});await fn(f,journal,dir,scopeId);}
const binding=(service,patch={})=>({decision:x=>service.decision(x),prepare:x=>service.prepare(x),confirm:x=>service.confirm(x),...patch});
test('real durable journal write/readback precedes any mutation; construction/read performs none',t=>use(t,async(f,journal)=>{
 let calls=0;const client=new DeliveryRecoveryClient(binding(f.maker,{prepare:async x=>{calls++;assert.equal((await journal.load()).value.phase,'attempted');return f.maker.prepare(x);}}),journal,24,'maker');
 assert.equal(await client.pending(),null);assert.equal(calls,0);await client.stage(f.request);assert.equal(calls,0);
 const result=await client.sendOriginal();assert.equal(result.state,'prepared');assert.equal(calls,1);assert.equal((await journal.load()).value.phase,'acknowledged');
 assert.equal(journal.db.prepare('SELECT count(*) n FROM recovery_journal_history').get().n,3);
 assert.throws(()=>journal.db.exec('DELETE FROM recovery_journal_history'));
}));
test('storage failure or readback mismatch sends no binding command',t=>use(t,async f=>{
 for(const journal of [{load:async()=>({version:0,value:null}),compareAndSwap:async()=>{throw Error('write failed');}},
  {load:async()=>({version:0,value:null}),compareAndSwap:async()=>true}]){
  let calls=0;const client=new DeliveryRecoveryClient(binding(f.maker,{prepare:async x=>{calls++;return f.maker.prepare(x);}}),journal,24,'maker');
  await assert.rejects(()=>client.stage(f.request));assert.equal(calls,0);
 }
}));
test('lost preparation acknowledgment survives client reconstruction and reconciles with a GET only',t=>use(t,async(f,journal)=>{
 let writes=0,reads=0;const remote=binding(f.maker,{prepare:async x=>{writes++;await f.maker.prepare(x);throw Error('lost reply');},decision:async x=>{reads++;return f.maker.decision(x);}});
 const first=new DeliveryRecoveryClient(remote,journal,24,'maker');await first.stage(f.request);await assert.rejects(()=>first.sendOriginal(),e=>e.code==='write_outcome_unknown');
 assert.equal((await journal.load()).value.phase,'attempted');const second=new DeliveryRecoveryClient(remote,journal,24,'maker');
 assert.equal((await second.pending()).request.decisionId,f.request.decisionId);assert.equal(writes,1);await second.reconcileReadOnly();
 assert.equal(writes,1);assert.equal(reads,1);assert.equal((await journal.load()).value.phase,'acknowledged');assert.equal(f.count('pa_recovery_decisions'),1);
}));
test('unknown confirmation retains exact operation across restart; GET-only reconciliation recovers the durable receipt',t=>use(t,async(f,_maker,dir)=>{
 await f.maker.prepare(f.request);const journal=new LocalRecoveryJournal(join(dir,'checker.sqlite'),{clubId:24,role:'checker',scopeId:crypto.randomUUID()});t.after(()=>journal.close());
 let writes=0,reads=0;const remote=binding(f.checker,{confirm:async x=>{writes++;assert.ok(!Object.hasOwn(x,'eventId'));await f.checker.confirm(x);throw Error('lost reply');},decision:async x=>{reads++;return f.checker.decision(x);}});
 const command={...f.confirm,eventId:f.request.eventId};const first=new DeliveryRecoveryClient(remote,journal,24,'checker');await first.stage(command);
 await assert.rejects(()=>first.sendOriginal(),e=>e.code==='write_outcome_unknown');const second=new DeliveryRecoveryClient(remote,journal,24,'checker');
 await second.reconcileReadOnly();assert.equal(writes,1);assert.equal(reads,1);assert.equal((await second.pending()).receipt.operationId,f.request.operationId);
 assert.equal(f.db.sql.prepare("SELECT count(*) n FROM pa_delivery_commands WHERE action='redrive'").get().n,1);
}));
test('explicit original retry repeats one operation identity, never allocates a new decision or command',t=>use(t,async(f,journal)=>{
 let writes=0;const client=new DeliveryRecoveryClient(binding(f.maker,{prepare:async x=>{writes++;const result=await f.maker.prepare(x);if(writes===1)throw Error('lost reply');return result;}}),journal,24,'maker');
 await client.stage(f.request);await assert.rejects(()=>client.sendOriginal());await client.sendOriginal();assert.equal(writes,2);assert.equal(f.count('pa_recovery_decisions'),1);
}));
test('unknown operations cannot be replaced; wrong club/role journals and extra request fields fail closed',t=>use(t,async(f,journal)=>{
 const client=new DeliveryRecoveryClient(binding(f.maker),journal,24,'maker');await client.stage(f.request);
 await assert.rejects(()=>client.stage({...f.request,decisionId:crypto.randomUUID(),operationId:crypto.randomUUID()}),e=>e.code==='unresolved_operation');
 await assert.rejects(()=>new DeliveryRecoveryClient(binding(f.maker),journal,25,'maker').pending(),e=>e.code==='journal_unavailable');
 await assert.rejects(()=>new DeliveryRecoveryClient(binding(f.maker),journal,24,'checker').pending(),e=>e.code==='journal_unavailable');
 await assert.rejects(()=>client.stage({...f.request,phone:'secret'}),e=>e.code==='invalid_request');
}));
test('wrong-event confirmation receipt is rejected and the original command stays uncertain',t=>use(t,async(f,_j,dir)=>{
 await f.maker.prepare(f.request);const journal=new LocalRecoveryJournal(join(dir,'checker.sqlite'),{clubId:24,role:'checker',scopeId:crypto.randomUUID()});t.after(()=>journal.close());
 const client=new DeliveryRecoveryClient(binding(f.checker,{confirm:async x=>({...await f.checker.confirm(x),eventId:crypto.randomUUID()})}),journal,24,'checker');
 await client.stage({...f.confirm,eventId:f.request.eventId});await assert.rejects(()=>client.sendOriginal(),e=>e.code==='write_outcome_unknown');assert.equal((await client.pending()).phase,'attempted');
}));
test('scope invalidation fences a late response and never publishes or replaces its original unresolved request',t=>use(t,async(f,journal)=>{
 let release;const wait=new Promise(resolve=>{release=resolve;});const client=new DeliveryRecoveryClient(binding(f.maker,{prepare:async x=>{const result=await f.maker.prepare(x);await wait;return result;}}),journal,24,'maker');
 await client.stage(f.request);const request=client.sendOriginal();await new Promise(resolve=>setTimeout(resolve,5));client.invalidate();release();
 await assert.rejects(()=>request,e=>e.code==='write_outcome_unknown');assert.equal((await journal.load()).value.phase,'attempted');
}));
test('a binding ignoring its deadline has unknown outcome and cannot trigger an automatic retry',t=>use(t,async(f,journal)=>{
 let calls=0;const client=new DeliveryRecoveryClient(binding(f.maker,{prepare:async()=>{calls++;return new Promise(()=>{});}}),journal,24,'maker',100);
 await client.stage(f.request);await assert.rejects(()=>client.sendOriginal(),e=>e.code==='write_outcome_unknown');assert.equal(calls,1);assert.equal((await client.pending()).phase,'attempted');
}));
test('two local clients racing a shared journal stage/attempt send at most one mutation',t=>use(t,async(f,journal)=>{
 let calls=0;const remote=binding(f.maker,{prepare:async x=>{calls++;return f.maker.prepare(x);}});
 const a=new DeliveryRecoveryClient(remote,journal,24,'maker'),b=new DeliveryRecoveryClient(remote,journal,24,'maker');await a.stage(f.request);
 const replies=await Promise.allSettled([a.sendOriginal(),b.sendOriginal()]);assert.equal(replies.filter(x=>x.status==='fulfilled').length,1);assert.equal(calls,1);
}));
test('journal rejects public file permissions, symlinks and another operator scope',t=>use(t,async(_f,journal,dir,scopeId)=>{
 assert.throws(()=>new LocalRecoveryJournal(journal.file,{clubId:24,role:'maker',scopeId:crypto.randomUUID()}),/journal_scope_conflict/);
 symlinkSync(journal.file,join(dir,'link.sqlite'));assert.throws(()=>new LocalRecoveryJournal(join(dir,'link.sqlite'),{clubId:24,role:'maker',scopeId}),/journal_file_not_private/);
 chmodSync(journal.file,0o644);assert.throws(()=>new LocalRecoveryJournal(journal.file,{clubId:24,role:'maker',scopeId}),/journal_file_not_private/);chmodSync(journal.file,0o600);
}));
