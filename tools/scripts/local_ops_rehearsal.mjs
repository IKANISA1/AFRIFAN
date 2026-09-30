#!/usr/bin/env node
/** Executes only disposable real-SQLite fixtures. Never reads credentials or contacts a provider. */
import assert from 'node:assert/strict';import {createHash,randomUUID} from 'node:crypto';
import {mkdtempSync,mkdirSync,chmodSync,writeFileSync,readFileSync,copyFileSync} from 'node:fs';import {tmpdir} from 'node:os';import {resolve,join,dirname} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';import {execFileSync} from 'node:child_process';
import {recoveryFixture,TestD1,sourceEnv,ids,CONSUMER} from '../../cloudflare/allocation-delivery/tests/recovery/fixture.mjs';
import {DeliverySource} from '../../cloudflare/allocation-delivery/src/source.mjs';import {AllocationInbox} from '../../cloudflare/allocation-delivery/src/inbox.mjs';
import {inboxEnv} from '../../cloudflare/allocation-delivery/tests/fixture.mjs';import {drain} from '../../cloudflare/allocation-delivery/src/dispatcher.mjs';
import {PaymentAllocationService} from '../../cloudflare/payment-allocation/src/service.mjs';
import {hash as envelopeHash} from '../../cloudflare/allocation-delivery/src/policy.mjs';
const ROOT=resolve(dirname(fileURLToPath(import.meta.url)),'../..'),BASELINE='9f2a658cc49c212f780b7906bbd37edd215e60bf';
const PROGRAM=Object.freeze({name:'AFRICLUB_DISPOSABLE_LOCAL_SQLITE_V1',clubIds:[24,25,26,27,28],eventsPerClub:12,concurrentDrains:4,
 maxDrainCycles:50,maxDrainP95Ms:1000,maxRestoreMs:5000,scope:'synthetic fixture budgets, not production traffic or approved SLOs'});
const hash=x=>createHash('sha256').update(x).digest('hex');
const fileHash=file=>hash(readFileSync(file));
const financialTables=['pa_allocations','pa_external_claims','pa_ledger','pa_memberships','pa_orders','pa_outbox','pa_receipts'];
function tableHash(db,table){const rows=db.sql.prepare(`SELECT * FROM ${table}`).all().map(row=>JSON.stringify(row)).sort();return hash(JSON.stringify(rows));}
const financialHashes=db=>Object.fromEntries(financialTables.map(table=>[table,tableHash(db,table)]));
function balance(db){return db.sql.prepare(`SELECT count(*) ledger_count,coalesce(sum(amount),0) ledger_amount,
 (SELECT count(*) FROM pa_allocations) allocation_count,(SELECT count(*) FROM pa_external_claims) external_claim_count,
 (SELECT count(*) FROM pa_receipts) receipt_count,(SELECT count(*) FROM pa_outbox) outbox_count FROM pa_ledger`).get();}
function assertConserved(db,expected){const values=balance(db);for(const [key,value] of Object.entries(values))assert.equal(value,key==='ledger_amount'?expected*10000:expected);return values;}
function check(db){assert.equal(db.sql.prepare('PRAGMA integrity_check').get().integrity_check,'ok');assert.deepEqual(db.sql.prepare('PRAGMA foreign_key_check').all(),[]);}
function snapshot(db,path){db.sql.prepare('VACUUM INTO ?').run(path);chmodSync(path,0o600);return {file:resolve(path),bytes:readFileSync(path).length,sha256:fileHash(path)};}
async function allocate(f,clubId,receiverId){
 const order=f.createOrder({club_id:clubId,receiver_id:receiverId});const evidence=f.evidence(order);evidence.parsed.rawId=evidence.raw.id;
 await f.ingestion.ingest(evidence);const command=f.allocation(evidence,order);const receipt=await f.allocator.allocate(command);
 return {order,evidence,command,receipt};
}
async function addForwardOrder(db,env,template){
 const order={...template.order,order_id:randomUUID(),source_intent_id:randomUUID(),checkout_reference:`MEM-${randomUUID()}`,
  state:'pending',created_at_ms:db.time-1000,expires_at_ms:db.time+86400000};
 const names=Object.keys(order);db.sql.prepare(`INSERT INTO pa_orders(${names.join(',')}) VALUES(${names.map(()=>'?').join(',')})`).run(...Object.values(order));
 const evidence=structuredClone(template.evidence);evidence.requestId=randomUUID();evidence.raw.id=randomUUID();evidence.parsed.id=randomUUID();
 evidence.parsed.rawId=evidence.raw.id;evidence.parsed.providerReference=`TX-${randomUUID()}`;evidence.raw.receivedAt=db.time;evidence.parsed.transactionAt=db.time;
 const ingestion=new PaymentAllocationService(env,ids.ingest),allocator=new PaymentAllocationService(env,ids.allocate);
 await ingestion.ingest(evidence);await allocator.allocate({requestId:randomUUID(),clubId:order.club_id,orderId:order.order_id,evidenceId:evidence.parsed.id});
}
export async function runRehearsal({output}={}){
 const started=performance.now(),privateDir=mkdtempSync(join(tmpdir(),'africlub-local-ops-'));chmodSync(privateDir,0o700);
 const originalFetch=globalThis.fetch;let networkAttempts=0;globalThis.fetch=()=>{networkAttempts++;throw Error('external_network_disabled_for_rehearsal');};
 const f=await recoveryFixture(),metrics=[],durations=[];const resources=[];const artifacts={};
 try{
  const receivers=new Map([[24,ids.receiver]]);
  for(const clubId of PROGRAM.clubIds){
   if(![24,25].includes(clubId)){
    f.db.sql.prepare('INSERT INTO pa_clubs(club_id,club_slug,country,currency,enabled) VALUES(?,?,?,?,1)').run(clubId,`synthetic-club-${clubId}`,'RW','RWF');
    f.db.sql.prepare('INSERT INTO pa_subjects(user_id,club_id,enabled) VALUES(?,?,1)').run(ids.user,clubId);
    f.db.sql.prepare('INSERT INTO pa_grants SELECT principal_id,?,capability,enabled,revision FROM pa_grants WHERE club_id=24').run(clubId);
    f.db.sql.prepare('INSERT INTO pa_delivery_control VALUES(?,1,?,3,10000,1000,?)').run(clubId,CONSUMER,'SYNTHETIC_NOT_APPROVAL');
    f.db.sql.prepare('INSERT INTO pa_delivery_grants SELECT principal_id,?,role,enabled FROM pa_delivery_grants WHERE club_id=24').run(clubId);
    f.sinkDb.sql.prepare('INSERT INTO adi_clubs VALUES(?,1)').run(clubId);
   }
   if(clubId!==24){const id=randomUUID();receivers.set(clubId,id);f.db.sql.prepare('INSERT INTO pa_receivers(receiver_id,club_id,partner_id,provider,country,currency,recipient,active) VALUES(?,?,?,?,?,?,?,1)')
    .run(id,clubId,ids.partner,'mtn_rwanda','RW','RWF','123456');}
  }
  const prepared=await f.maker.prepare(f.request);assert.equal(prepared.state,'prepared');const decisionReceipt=await f.checker.confirm(f.confirm);
  assert.deepEqual(await f.checker.confirm(f.confirm),decisionReceipt);
  for(const clubId of PROGRAM.clubIds)for(let index=0;index<PROGRAM.eventsPerClub;index++)await allocate(f,clubId,receivers.get(clubId));
  const baselineEvents=1+PROGRAM.clubIds.length*PROGRAM.eventsPerClub;
  assertConserved(f.db,baselineEvents);const baselineFinancial=financialHashes(f.db);
  artifacts.olderSource=snapshot(f.db,join(privateDir,'older-source.sqlite'));
  artifacts.olderInbox=snapshot(f.sinkDb,join(privateDir,'older-inbox.sqlite'));
  const forwardOrders=[];for(const clubId of PROGRAM.clubIds)forwardOrders.push(await allocate(f,clubId,receivers.get(clubId)));
  const expectedEvents=baselineEvents+forwardOrders.length,financialBefore=financialHashes(f.db);assertConserved(f.db,expectedEvents);
  f.runner.DELIVERY_CLUB_IDS=JSON.stringify(PROGRAM.clubIds);
  Object.assign(f.runner,{PRIVATE_METRICS_ENABLED:'true',PRIVATE_METRICS_RETENTION_MS:'86400000',PRIVATE_METRICS_POLICY_REF:'SYNTHETIC_TEST_POLICY',
   PRIVATE_METRICS:{record:value=>{metrics.push(value);if(metrics.length===1)throw Error('synthetic telemetry failure');}}});
  let sinkLostAck=false,sourceLostAck=false,lateSink=false,latePromise=null;
  f.runner.INBOX={accept:async event=>{
   if(event.clubId===24&&!sinkLostAck){sinkLostAck=true;await f.sink.accept(event);throw Error('synthetic reply loss after sink commit');}
   if(event.clubId===26&&!lateSink){lateSink=true;latePromise=new Promise(resolve=>setTimeout(async()=>resolve(await f.sink.accept(event)),140));return latePromise;}
   return f.sink.accept(event);
  }};
  f.runner.SOURCE={take:x=>f.source.take(x),readForDispatch:x=>f.source.readForDispatch(x),finish:async input=>{
   const receipt=await f.source.finish(input);if(input.clubId===25&&!sourceLostAck){sourceLostAck=true;throw Error('synthetic reply loss after source commit');}return receipt;
  }};
  let cycles=0,unknowns=0,retries=0;const perClubObserved=new Map(PROGRAM.clubIds.map(x=>[x,0]));
  while(cycles<PROGRAM.maxDrainCycles){
   const replies=await Promise.all(Array.from({length:PROGRAM.concurrentDrains},async()=>{const start=performance.now();const result=await drain(f.runner);durations.push(performance.now()-start);return result;}));
   for(const reply of replies){unknowns+=reply.unknown;retries+=reply.retryRecorded;}
   if(latePromise)await latePromise;cycles++;f.advance(1000);
   const count=f.db.sql.prepare("SELECT count(*) n FROM pa_delivery_jobs WHERE state='delivered'").get().n;if(count===expectedEvents)break;
  }
  assert.ok(cycles<PROGRAM.maxDrainCycles);assert.ok(unknowns>0);assert.ok(retries>0);assert.ok(sinkLostAck&&sourceLostAck&&lateSink);
  assert.deepEqual(financialHashes(f.db),financialBefore);assertConserved(f.db,expectedEvents);
  assert.equal(f.sinkDb.sql.prepare('SELECT count(*) n FROM adi_events').get().n,expectedEvents);
  assert.equal(f.db.sql.prepare("SELECT count(*) n FROM pa_delivery_jobs WHERE state='delivered'").get().n,expectedEvents);
  for(const clubId of PROGRAM.clubIds){
   const count=f.sinkDb.sql.prepare('SELECT count(*) n FROM adi_events WHERE club_id=?').get(clubId).n;
   assert.equal(count,PROGRAM.eventsPerClub+1+(clubId===24?1:0));perClubObserved.set(clubId,count);
  }
  const sorted=[...durations].sort((a,b)=>a-b),p95=sorted[Math.ceil(sorted.length*.95)-1];assert.ok(p95<=PROGRAM.maxDrainP95Ms);
  // Freeze the old writer before any restored candidate can be enabled. The frozen source is the forward checkpoint.
  f.db.sql.exec("UPDATE pa_settings SET writer_mode='disabled'");await assert.rejects(()=>f.source.take({clubId:24}));
  artifacts.forwardSource=snapshot(f.db,join(privateDir,'forward-source-frozen.sqlite'));artifacts.forwardInbox=snapshot(f.sinkDb,join(privateDir,'forward-inbox.sqlite'));
  const restoreStart=performance.now(),olderFile=join(privateDir,'older-restored-quarantined.sqlite');copyFileSync(artifacts.olderSource.file,olderFile);chmodSync(olderFile,0o600);
  const older=new TestD1(olderFile);resources.push(older);older.time=f.db.time;older.sql.exec("UPDATE pa_settings SET writer_mode='disabled'");check(older);
  assertConserved(older,baselineEvents);assert.deepEqual(financialHashes(older),baselineFinancial);
  assert.notDeepEqual(financialHashes(older),financialBefore);const gap=expectedEvents-balance(older).allocation_count;assert.equal(gap,5);
  await assert.rejects(()=>new DeliverySource(sourceEnv(older),ids.outbox).take({clubId:24}));
  // Restore the newer frozen checkpoint into a NEW database; no destructive restore or invented financial replay is allowed.
  const promotedFile=join(privateDir,'forward-restored.sqlite'),inboxFile=join(privateDir,'inbox-restored.sqlite');
  copyFileSync(artifacts.forwardSource.file,promotedFile);copyFileSync(artifacts.forwardInbox.file,inboxFile);chmodSync(promotedFile,0o600);chmodSync(inboxFile,0o600);
  assert.equal(fileHash(promotedFile),artifacts.forwardSource.sha256);assert.equal(fileHash(inboxFile),artifacts.forwardInbox.sha256);
  const promoted=new TestD1(promotedFile),restoredInbox=new TestD1(inboxFile);resources.push(promoted,restoredInbox);promoted.time=f.db.time;restoredInbox.time=f.db.time;check(promoted);check(restoredInbox);
  assert.deepEqual(financialHashes(promoted),financialBefore);assertConserved(promoted,expectedEvents);
  for(const row of restoredInbox.sql.prepare('SELECT event_id,envelope_sha256,envelope_json FROM adi_events').all()){
   assert.equal(await envelopeHash(JSON.parse(row.envelope_json)),row.envelope_sha256);
   const source=promoted.sql.prepare('SELECT state,receipt_id FROM pa_delivery_jobs WHERE event_id=?').get(row.event_id);
   assert.equal(source.state,'delivered');assert.equal(source.receipt_id,row.event_id);
  }
  promoted.sql.exec("UPDATE pa_settings SET writer_mode='isolated-staging'");
  const writerModes=[f.db,older,promoted].map(db=>db.sql.prepare('SELECT writer_mode FROM pa_settings').get().writer_mode);
  assert.equal(writerModes.filter(x=>x==='isolated-staging').length,1);
  const restoredEnv=sourceEnv(promoted),source=new DeliverySource(restoredEnv,ids.outbox),sink=new AllocationInbox(inboxEnv(restoredInbox));
  const restoredRunner={...f.runner,SOURCE:source,INBOX:sink};assert.equal((await drain(restoredRunner)).examined,0);
  const restoredMs=performance.now()-restoreStart;assert.ok(restoredMs<=PROGRAM.maxRestoreMs);
  // Execute the actual pre-change dispatcher body from the recorded Git candidate, rebinding only its relative policy import.
  const previousBody=execFileSync('git',['show',`${BASELINE}:cloudflare/allocation-delivery/src/dispatcher.mjs`],{cwd:ROOT,encoding:'utf8'});
  const importText="from './policy.mjs'";assert.equal(previousBody.split(importText).length,2);
  const rollbackBody=previousBody.replace(importText,`from '${pathToFileURL(join(ROOT,'cloudflare/allocation-delivery/src/policy.mjs')).href}'`);
  const rollbackFile=join(privateDir,'rollback-dispatcher.mjs');writeFileSync(rollbackFile,rollbackBody,{mode:0o600});const oldDispatcher=await import(pathToFileURL(rollbackFile));
  assert.equal((await oldDispatcher.drain(restoredRunner)).examined,0);const beforeRollbackHash=financialHashes(promoted);
  await addForwardOrder(promoted,restoredEnv,forwardOrders[0]);assert.equal((await oldDispatcher.drain(restoredRunner)).stored,1);
  assertConserved(promoted,expectedEvents+1);assert.equal(restoredInbox.sql.prepare('SELECT count(*) n FROM adi_events').get().n,expectedEvents+1);
  assert.equal((await oldDispatcher.drain(restoredRunner)).examined,0);check(promoted);check(restoredInbox);
  promoted.sql.exec("UPDATE pa_settings SET writer_mode='disabled'");await assert.rejects(()=>source.take({clubId:24}));
  await assert.rejects(()=>oldDispatcher.drain({...restoredRunner,DELIVERY_DISPATCH_ENABLED:'false'}));
  assert.equal(networkAttempts,0);
  // Independent connections/threads exercise financial conservation and competing retained review decisions.
  const independent=execFileSync(process.execPath,['--test','cloudflare/payment-allocation/tests/concurrency.test.mjs',
   'cloudflare/allocation-delivery/tests/recovery.test.mjs'],{cwd:ROOT,encoding:'utf8',timeout:15000,maxBuffer:8388608});
  const testCount=Number(independent.match(/^# tests (\d+)$/m)?.[1]),passCount=Number(independent.match(/^# pass (\d+)$/m)?.[1]),failCount=Number(independent.match(/^# fail (\d+)$/m)?.[1]);
  assert.ok(testCount>0&&testCount===passCount&&failCount===0);const independentLog=join(privateDir,'independent-connection-tests.log');writeFileSync(independentLog,independent,{mode:0o600});
  const report={schemaVersion:1,generatedAt:new Date().toISOString(),scope:'executed disposable SQLite/private-binding/synthetic-only rehearsal',
   program:PROGRAM,passed:true,productionReady:false,externalNetworkAttempts:networkAttempts,providerCalls:0,liveChanges:0,
   load:{allocatedEvents:expectedEvents,drainCalls:durations.length,cycles,concurrentDrains:PROGRAM.concurrentDrains,drainP95Ms:Number(p95.toFixed(3)),
    drainMaximumMs:Number(Math.max(...durations).toFixed(3)),unknownSummaries:unknowns,retrySummaries:retries,perClubInboxCounts:Object.fromEntries(perClubObserved),
    financialConservation:balance(f.db),financialHashesBefore:financialBefore,financialHashesAfter:financialHashes(f.db),telemetryEvents:metrics.length,
    sinkLostAck,sourceLostAck,ignoredSinkDeadlineWithLateCommit:lateSink},
   restore:{restoredMs:Number(restoredMs.toFixed(3)),integrity:'ok',foreignKeyViolations:0,olderBackupMissingPostBackupAllocations:gap,
    olderBackupStayedQuarantined:true,forwardCheckpointByteHashesVerified:true,forwardFinancialHashesVerified:true,
    sourceAndSinkOriginalEventReceiptPairsVerified:expectedEvents,singleWriterModesAtCutover:writerModes,artifacts},
   independentConnections:{tests:testCount,passed:passCount,failed:failCount,log:{file:independentLog,sha256:fileHash(independentLog)},
    scope:'real SQLite files and distinct Node workers; financial same-key/different-key/provider races and recovery reviewer races'},
   rollback:{baselineCommit:BASELINE,baselineDispatcherSha256:hash(previousBody),executedBodySha256:hash(rollbackBody),relativeImportRebindings:1,
    previousDispatcherActuallyExecuted:true,forwardDataRetainedBeforeRollback:beforeRollbackHash,newEventDeliveredAfterRollback:true,
    finalConservation:balance(promoted),finalEnabledWriterCount:0,killSwitchRejected:true},
   privateFixtureDirectory:privateDir,totalMs:Number((performance.now()-started).toFixed(3)),
   limitations:['SQLite fixtures are not D1/workerd/provider/device acceptance','Measured budgets are synthetic local bounds, not approved production SLOs',
    'Forward reconciliation restores an authenticated current local checkpoint; production backup provenance and access require separate verification',
    'The old dispatcher body is executed with one import-path rebinding, on current private source and inbox adapters','No schema or financial history was downgraded or deleted']};
  if(output){const out=resolve(output);mkdirSync(dirname(out),{recursive:true});writeFileSync(out,JSON.stringify(report,null,2)+'\n',{mode:0o600});}
  return report;
 }finally{resources.forEach(resource=>resource.close());f.close();globalThis.fetch=originalFetch;}
}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 const args=process.argv.slice(2);if(args.length!==2||args[0]!=='--output')throw Error('usage: local_ops_rehearsal.mjs --output <report.json>');
 try{const report=await runRehearsal({output:args[1]});console.log(JSON.stringify({passed:report.passed,productionReady:false,allocatedEvents:report.load.allocatedEvents,
  drainCalls:report.load.drainCalls,restoreMs:report.restore.restoredMs,report:resolve(args[1]),externalNetworkAttempts:report.externalNetworkAttempts}));}
 catch{console.error('local_ops_rehearsal_failed');process.exitCode=1;}
}
