import test from 'node:test';import assert from 'node:assert/strict';
import {register} from 'node:module';import {readFileSync} from 'node:fs';
import {DatabaseSync} from 'node:sqlite';
import {fixture as allocationFixture,ids} from '../../payment-allocation/tests/fixture.mjs';
import {checkoutFixture,checkoutPrincipal,readPrincipal} from '../../payment-allocation/tests/checkout-fixture.mjs';
import {NOW_SQL} from '../../payment-allocation/src/policy.mjs';
import {fixture as caseFixture,SUBJECTS} from '../../payment-exceptions/tests/fixture.mjs';
import {fixture as publicFixture,imported,SUBJECT,PRINCIPAL,ASSET} from '../../operator-api/tests/support/fixture.mjs';
import {receiptFixture} from '../../auth-code-delivery/tests/receipts-fixture.mjs';
import {fixture as senderFixture} from '../../auth-code-delivery/tests/fixture.mjs';
import {fixture as deliveryFixture} from '../../allocation-delivery/tests/fixture.mjs';
import {recoveryFixture,MAKER,CHECKER} from '../../allocation-delivery/tests/recovery/fixture.mjs';
import {createWebRouter} from '../../supporter-web-router/src/index.mjs';
import {PrivateMetricsStore} from '../sink.mjs';
import {traceOperation} from '../telemetry.mjs';
import {rpcOperation,httpOperation} from '../entrypoints.mjs';
register(new URL('./workers-loader.mjs',import.meta.url),import.meta.url);
const financial=await import('../../payment-allocation/src/worker.mjs');
const checkout=await import('../../payment-allocation/src/checkout-worker.mjs');
const {PaymentExceptionCases}=await import('../../payment-exceptions/src/worker.mjs');
const {PublicSourcePublisher}=await import('../../rayon-public/src/publication-worker.mjs');
const {AuthorizedPublicSourcePublisher}=await import('../../rayon-public/src/authorized-publication-worker.mjs');
const {AuthenticationDeliveryReceiptReader}=await import('../../auth-code-delivery/src/receipt-reader-worker.mjs');
const {default:receiptWorker}=await import('../../auth-code-delivery/src/receipts-webhook-worker.mjs');
const {default:publicWorker}=await import('../../rayon-public/src/index.mjs');
const source=await import('../../allocation-delivery/src/source-worker.mjs');
const inbox=await import('../../allocation-delivery/src/inbox-worker.mjs');
const recovery=await import('../../allocation-delivery/src/recovery-worker.mjs');
function observed(env={},record){
 const records=[],pending=[];const ctx={waitUntil(p){pending.push(p);}};
 Object.assign(env,{PRIVATE_METRICS_ENABLED:'true',PRIVATE_METRICS_RETENTION_MS:'3600000',PRIVATE_METRICS_POLICY_REF:'SYNTHETIC_TEST_POLICY',
  PRIVATE_METRICS:{record:record??(async input=>records.push(input))}});
 return {env,ctx,records,async flush(){for(let i=0;i<pending.length;i++)await pending[i];await new Promise(r=>setTimeout(r,0));}};
}
const binding=(Class,o)=>Object.assign(new Class(),{env:o.env,ctx:o.ctx});
function metrics(o,operations,service,secrets=[]){
 assert.equal(o.records.length,operations.length);assert.deepEqual(o.records.map(r=>r.metric.operation),operations);
 const ids=new Set();for(const {metric} of o.records){assert.equal(metric.service,service);assert.deepEqual(Object.keys(metric),
  ['schemaVersion','event','service','operation','traceId','clubId','observedAt','durationMs','outcome']);ids.add(metric.traceId);}
 assert.equal(ids.size,operations.length);const text=JSON.stringify(o.records);
 for(const secret of secrets)assert.equal(text.includes(secret),false,`secret entered telemetry: ${secret}`);
 assert.doesNotMatch(text,/authorization|cookie|providerReference|challengeId|userId|recipient|https?:\/\/|SENSITIVE/);
}
test('actual financial entrypoints preserve one allocation, receipt and delivery while emitting five isolated projections',async t=>{
 const f=allocationFixture();t.after(()=>f.close());const o=observed(f.env);Object.assign(o.env,{INGEST_PRINCIPAL_ID:ids.ingest,ALLOCATE_PRINCIPAL_ID:ids.allocate,READ_PRINCIPAL_ID:ids.read,OUTBOX_PRINCIPAL_ID:ids.outbox});
 await binding(financial.PaymentEvidenceIngestor,o).ingest(f.input);
 const a=await binding(financial.PaymentAllocator,o).allocate(f.allocation());assert.equal(a.amount,10000);
 assert.deepEqual(await binding(financial.PaymentReceiptReader,o).readReceipt({clubId:24,orderId:f.order.order_id}),a);
 const outbox=binding(financial.PaymentAllocationOutbox,o),e=(await outbox.claim({clubId:24,limit:1})).events[0];
 assert.equal((await outbox.acknowledge({clubId:24,eventId:e.eventId,leaseId:e.leaseId})).acknowledged,true);
 assert.equal(f.count('pa_allocations'),1);assert.equal(f.count('pa_ledger'),1);assert.equal(f.count('pa_receipts'),1);
 await o.flush();metrics(o,['payment_ingest','payment_allocate','payment_receipt','delivery_claim','delivery_acknowledge'],'payment_allocation',
  [ids.user,f.order.order_id,e.eventId,e.leaseId,f.input.parsed.providerReference]);
 assert.equal(o.records[0].metric.clubId,null);assert(o.records.slice(1).every(r=>r.metric.clubId===24));
});
test('postcommit permission revocation stays unknown and telemetry does not repeat a financial command',async t=>{
 const f=allocationFixture();t.after(()=>f.close());await f.ingestion.ingest(f.input);
 const o=observed(f.env);o.env.ALLOCATE_PRINCIPAL_ID=ids.allocate;let commits=0;
 f.db.afterCommit=()=>{commits++;f.db.sql.prepare('UPDATE pa_grants SET enabled=0 WHERE principal_id=?').run(ids.allocate);};
 await assert.rejects(binding(financial.PaymentAllocator,o).allocate(f.allocation()),e=>e.code==='permission_denied');
 await o.flush();assert.equal(commits,1);assert.equal(f.count('pa_allocations'),1);assert.equal(f.count('pa_ledger'),1);
 assert.equal(o.records.length,1);assert.equal(o.records[0].metric.outcome,'unknown');
});
test('hung private metrics binding cannot delay or repeat a committed allocation',async t=>{
 const f=allocationFixture();t.after(()=>f.close());await f.ingestion.ingest(f.input);let calls=0;
 const o=observed(f.env,()=>{calls++;return new Promise(()=>{});});o.env.ALLOCATE_PRINCIPAL_ID=ids.allocate;
 const started=performance.now(),a=await binding(financial.PaymentAllocator,o).allocate(f.allocation());
 assert.equal(a.amount,10000);await o.flush();assert(performance.now()-started<1000);assert.equal(calls,1);assert.equal(f.count('pa_ledger'),1);
});
test('all eleven checkout and handoff entrypoints project no user, order, dialer or operation keys',async t=>{
 const f=checkoutFixture();t.after(()=>f.close());
 for(const name of ['0003_payment_handoff_journal.sql','0004_release_unclaimed_handoff.sql'])f.db.sql.exec(readFileSync(new URL('../../payment-allocation/migrations/'+name,import.meta.url),'utf8').replaceAll(NOW_SQL,'test_now_ms()'));
 f.db.sql.exec('UPDATE pa_handoff_settings SET enabled=1;UPDATE pa_handoff_release_settings SET enabled=1;');
 const o=observed(f.env);Object.assign(o.env,{CHECKOUT_PRINCIPAL_ID:checkoutPrincipal,CHECKOUT_READ_PRINCIPAL_ID:readPrincipal,HANDOFF_JOURNAL_ENABLED:'true',HANDOFF_RELEASE_ENABLED:'true'});
 const write=binding(checkout.MembershipCheckout,o),read=binding(checkout.MembershipCheckoutReader,o),scope={clubId:24,userId:ids.user},v=f.request();
 const a=await write.prepare(v);assert.equal((await write.lookupPreparedOperation({...scope,requestId:v.requestId})).found,true);
 const r=await write.reserveHandoff({...scope,orderId:a.checkout.orderId,requestId:crypto.randomUUID()});
 await write.releaseHandoff({...scope,handoffId:r.handoff.handoffId,requestId:crypto.randomUUID()});
 const r2=await write.reserveHandoff({...scope,orderId:a.checkout.orderId,requestId:crypto.randomUUID()});
 assert.equal((await write.claimHandoff({...scope,handoffId:r2.handoff.handoffId,requestId:crypto.randomUUID()})).mayOpenDialer,true);
 assert.equal((await read.currentHandoff(scope)).handoff.phase,'claimed');
 assert.equal((await read.offers(scope)).offers.length,1);assert.equal((await read.membershipStatus(scope)).currentStatus,'not_member');
 assert.equal((await read.read({...scope,orderId:a.checkout.orderId})).status,'pending_current');
 assert.equal((await read.history({...scope,limit:20,cursor:null})).items.length,0);
 const order=f.orderFor(a),e=f.evidence(order);e.parsed.rawId=e.raw.id;await f.ingestion.ingest(e);await f.allocator.allocate(f.allocation(e,order));
 assert.equal((await read.historicalReceipt({...scope,orderId:a.checkout.orderId})).receipt.historical,true);
 await o.flush();metrics(o,['checkout_create','checkout_read','handoff_reserve','handoff_release','handoff_reserve','handoff_claim','handoff_read',
  'checkout_offers','membership_read','membership_read','membership_history','payment_receipt'],'payment_allocation',
  [ids.user,v.requestId,a.checkout.orderId,a.checkout.ussdCode,r.handoff.handoffId,r2.handoff.handoffId]);
 assert.equal(f.count('pa_ledger'),1);assert.equal(f.count('pa_handoff_claims'),1);
});
test('case entrypoints emit one metric each with identity and financial references omitted',async t=>{
 const f=caseFixture(t),o=observed(f.env),b=binding(PaymentExceptionCases,o),v=f.command(),scope={identity:f.identity(),clubId:24};
 assert.equal((await b.command(v)).ok,true);assert.equal((await b.access(scope)).ok,true);
 assert.equal((await b.operation({...scope,operationId:v.operationId})).ok,true);
 assert.equal((await b.get({...scope,caseId:v.caseId})).ok,true);
 assert.equal((await b.list({...scope,afterCaseId:null,limit:20,state:null})).ok,true);
 assert.equal((await b.history({...scope,caseId:v.caseId,afterRevision:0,limit:20})).ok,true);
 await o.flush();metrics(o,['case_command','case_read','case_read','case_read','case_read','case_read'],'payment_exceptions',
  [SUBJECTS.maker,v.caseId,v.operationId,v.detail.orderId]);assert.equal(f.count(),1);
});
test('case lost commit response and revoked observation are unknown without another insert',async t=>{
 const f=caseFixture(t),o=observed(f.env),b=binding(PaymentExceptionCases,o);let commits=0;
 f.db.afterRun=()=>{commits++;f.db.sql.exec('UPDATE px_grants SET enabled=0');};f.db.loseRun=true;
 const result=await b.command(f.command());assert.equal(result.ok,false);assert.equal(f.count(),1);await o.flush();
 assert.equal(commits,1);assert.equal(o.records.length,1);assert.equal(o.records[0].metric.outcome,'unknown');
});
test('all nine authorized publication entrypoints retain one publication and exclude actor, media and review identity',async t=>{
 const f=publicFixture(t),s=await imported(f),o=observed(f.env),b=binding(AuthorizedPublicSourcePublisher,o),scope={identity:f.identity,clubId:24};
 for(const method of ['session','candidates','head'])assert.equal((await b[method](scope)).ok,true);
 assert.equal((await b.candidate({...scope,snapshotId:s.id})).ok,true);
 const r=await b.review({...scope,snapshotId:s.id,expectedPreviousId:null,reviewRef:'SYNTHETIC_REVIEW'});assert.equal(r.ok,true);
 assert.equal((await b.preview({...scope,snapshotId:s.id,route:'news',offset:0})).ok,true);
 assert.equal((await b.reviewStatus({...scope,reviewId:r.data.reviewId})).ok,true);
 const p=await b.publish({...scope,reviewId:r.data.reviewId,idempotencyKey:'SYNTHETIC_KEY_12345678'});assert.equal(p.ok,true);
 assert.equal((await b.publication({...scope,operationId:p.data.operationId})).ok,true);
 await o.flush();metrics(o,['publication_read','publication_read','publication_read','publication_read','publication_command',
  'publication_read','publication_read','publication_command','publication_read'],'rayon_public',
  [SUBJECT,PRINCIPAL,s.id,ASSET,r.data.reviewId,p.data.operationId,'SYNTHETIC_KEY_12345678','SYNTHETIC_REVIEW']);
 assert.equal(f.sql('SELECT count(*) n FROM public_operator_publications')[0].n,1);
});
test('private legacy publisher and public content route isolate sink failure from approved snapshot',async t=>{
 const f=publicFixture(t),s=await imported(f);let sinkCalls=0;
 const o=observed(f.env,()=>{sinkCalls++;throw Error('SENSITIVE_TELEMETRY');});
 const p=await binding(PublicSourcePublisher,o).publish({snapshotId:s.id,approvedBy:'SYNTHETIC_OPERATOR',approvalRef:'SYNTHETIC_APPROVAL',expectedPreviousId:null});
 assert.equal(p.alreadyActive,false);
 const response=await publicWorker.fetch(new Request('https://public.example.invalid/v1/public/rayon/news?token=SENSITIVE_QUERY',{headers:{authorization:'Bearer SENSITIVE_HEADER'}}),o.env,o.ctx);
 assert.equal(response.status,200);assert.equal((await response.json()).rows.length,1);
 await o.flush();assert.equal(sinkCalls,2);assert.equal(f.sql('SELECT count(*) n FROM public_snapshot_head')[0].n,1);
});
test('public read failure emits only a fixed unavailable outcome without raw route or backend error',async()=>{
 const o=observed(),r=await publicWorker.fetch(new Request('https://public.example.invalid/v1/public/rayon/news?userId=SENSITIVE'),o.env,o.ctx);
 assert.equal(r.status,503);await o.flush();metrics(o,['publication_read'],'rayon_public',['public.example.invalid','SENSITIVE']);
 assert.equal(o.records[0].metric.outcome,'unavailable');assert.equal(o.records[0].metric.clubId,null);
});
test('receipt webhook commit, reconciliation and private reader emit once without message, phone, challenge or signing keys',async t=>{
 const f=receiptFixture(t);await f.tracked.deliver(f.input);const o=observed(f.env);
 const payload=f.payload();payload.entry[0].changes[0].value.statuses[0].timestamp=String(Math.floor(Date.now()/1000));
 const response=await receiptWorker.fetch(await f.signed(payload,{'x-trace-id':'SENSITIVE_INBOUND'}),o.env,o.ctx);assert.equal(response.status,200);
 await receiptWorker.scheduled({},o.env,o.ctx);await o.flush();
 const status=await binding(AuthenticationDeliveryReceiptReader,o).readDeliveryStatus({clubId:24,challengeId:f.input.challengeId});
 assert.equal(status.deliveryState,'delivered');await o.flush();metrics(o,['delivery_receipt','delivery_receipt','delivery_receipt'],'receipt_delivery',
  [f.input.phone,f.input.challengeId,'wamid.SYNTHETIC',o.env.WA_WEBHOOK_APP_SECRET,o.env.WA_WEBHOOK_VERIFY_TOKEN]);
 assert.equal(o.records[1].metric.outcome,'no_work');assert.equal(f.count('delivery_status_events'),1);
});
test('receipt lost acknowledgement persists once and telemetry does not replay the webhook',async t=>{
 const f=receiptFixture(t),o=observed(f.env);f.loseBatch();const payload=f.payload();payload.entry[0].changes[0].value.statuses[0].timestamp=String(Math.floor(Date.now()/1000));
 const r=await receiptWorker.fetch(await f.signed(payload),o.env,o.ctx);assert.equal(r.status,503);await o.flush();
 assert.equal(f.count('delivery_status_events'),1);assert.equal(o.records.length,1);assert.equal(o.records[0].metric.outcome,'unknown');
});
test('router forwards the original request once and strips all transport values from metrics',async()=>{
 const calls=[],o=observed({WEB_ROUTER_ENABLED:'true',WEB_ORIGIN:'https://browser.example.invalid',
  BROWSER_API:{async fetch(r){calls.push(r);return new Response('{}');}},NEXT_APP:{async fetch(){throw Error('unused');}}});
 const request=new Request(o.env.WEB_ORIGIN+'/v1/browser/session?token=SENSITIVE',{headers:{cookie:'SENSITIVE_COOKIE','x-trace-id':'SENSITIVE_TRACE'}});
 const r=await createWebRouter().fetch(request,o.env,o.ctx);assert.equal(r.status,200);assert.equal(calls[0],request);await o.flush();
 metrics(o,['route'],'frontend_router',['SENSITIVE','browser.example.invalid']);assert.equal(calls.length,1);
});
test('router timeout and late commit retain unknown once despite a throwing telemetry sink',async()=>{
 let sends=0,commits=0,sinks=0,finish;const o=observed({WEB_ROUTER_ENABLED:'true',WEB_ORIGIN:'https://browser.example.invalid',
  BROWSER_API:{fetch(){sends++;return new Promise(r=>{finish=()=>{commits++;r(new Response('{}'));};});}},NEXT_APP:{fetch(){throw Error('unused');}}},()=>{sinks++;throw Error('SENSITIVE');});
 const r=await createWebRouter({rpcMs:5}).fetch(new Request(o.env.WEB_ORIGIN+'/v1/browser/membership/checkouts',{method:'POST',body:'SENSITIVE_BODY'}),o.env,o.ctx);
 assert.equal(r.status,503);assert.equal((await r.json()).outcome,'unknown');finish();await o.flush();assert.equal(sends,1);assert.equal(commits,1);assert.equal(sinks,1);
});
test('entrypoint wrappers never inspect bodies and preserve a mutating error result',async()=>{
 const o=observed();let work=0;const input=Object.defineProperty({userId:'SENSITIVE'},'clubId',{get(){throw Error('SENSITIVE');}});
 const result={ok:false,error:{code:'SENSITIVE',status:403}};
 assert.equal(await rpcOperation(o,{service:'payment_exceptions',operation:'case_command',mutating:true},input,()=>{work++;return result;}),result);
 const request={method:'POST',get url(){throw Error('must not inspect URL');},get body(){throw Error('must not inspect body');}};
 const response=new Response(null,{status:403});assert.equal(await httpOperation(o.env,{service:'receipt_delivery',operation:'delivery_receipt'},request,()=>{work++;return response;},o.ctx),response);
 await o.flush();assert.equal(work,2);assert(o.records.every(r=>r.metric.outcome==='unknown'&&r.metric.clubId===null));
});
test('default mutating trace classification does not call a permission failure denied after commit',async()=>{
 const o=observed(),e=Object.assign(Error('SENSITIVE'),{code:'permission_denied'});let work=0;
 await assert.rejects(traceOperation(o.env,{service:'supporter_auth',operation:'account_deletion'},()=>{work++;throw e;},{ctx:o.ctx}),x=>x===e);
 await o.flush();assert.equal(work,1);assert.equal(o.records[0].metric.outcome,'unknown');
});
test('actual RPC-to-isolated-SQLite telemetry sink persists a sanitized operation without financial binding access',async t=>{
 const f=allocationFixture();t.after(()=>f.close());await f.ingestion.ingest(f.input);
 const sql=new DatabaseSync(':memory:');t.after(()=>sql.close());sql.exec(readFileSync(new URL('../migrations/0001_private_metrics.sql',import.meta.url),'utf8'));
 const db={withSession(){return this;},prepare(query){return {args:[],bind(...args){return {...this,args};},async first(){return sql.prepare(query).get(...this.args);},async all(){return {results:sql.prepare(query).all(...this.args)};},async run(){return {meta:{changes:Number(sql.prepare(query).run(...this.args).changes)}};}};}};
 const sinkEnv={PRIVATE_METRICS_STORE_ENABLED:'true',PRIVATE_METRICS_ENVIRONMENT:'isolated-staging',PRIVATE_METRICS_RETENTION_MS:'3600000',PRIVATE_METRICS_POLICY_REF:'SYNTHETIC_TEST_POLICY',METRICS_DB:db};
 const store=new PrivateMetricsStore(sinkEnv),o=observed(f.env,input=>store.record(input));o.env.ALLOCATE_PRINCIPAL_ID=ids.allocate;
 await binding(financial.PaymentAllocator,o).allocate(f.allocation());await o.flush();
 const rows=sql.prepare('SELECT metric_json,expires_at_ms FROM private_metrics').all();assert.equal(rows.length,1);
 const value=JSON.parse(rows[0].metric_json);assert.equal(value.operation,'payment_allocate');assert.equal(value.outcome,'completed');
 assert.equal((await store.readTrace({traceId:value.traceId,limit:1})).items.length,1);assert.equal(f.count('pa_ledger'),1);
 assert.equal('ALLOCATION_DB' in sinkEnv,false);assert.equal('PAYMENT_CASE_DB' in sinkEnv,false);assert.equal(rows[0].metric_json.includes(ids.user),false);
});
test('source and inbox capability boundaries emit exactly one operation each alongside bounded queue aggregates',async t=>{
 const f=await deliveryFixture();t.after(()=>f.close());const o=observed(f.env),i=observed(f.sinkEnv);Object.assign(o.env,{DELIVERY_PRINCIPAL_ID:ids.outbox,DELIVERY_REVIEW_PRINCIPAL_ID:ids.other});
 const write=binding(source.AllocationEventSource,o),review=binding(source.AllocationDeliveryReview,o),accept=binding(inbox.AllocationEventInbox,i),reader=binding(inbox.AllocationInboxReader,i);
 const {event}=await write.take({clubId:24}),prepared=await write.readForDispatch({clubId:24,eventId:event.eventId,leaseId:event.leaseId});
 const receipt=await accept.accept(prepared.event);assert.equal((await reader.list({clubId:24,afterEventId:null,limit:20})).items.length,1);
 await write.finish({clubId:24,eventId:event.eventId,leaseId:event.leaseId,expectedRevision:event.revision,requestId:crypto.randomUUID(),outcome:'delivered',reason:'none',receiptId:receipt.receiptId});
 assert.equal((await review.health({clubId:24})).counts.delivered,1);
 assert.equal((await review.inspect({clubId:24,state:'delivered',afterEventId:null,limit:20})).items.length,1);
 await assert.rejects(review.redrive({clubId:24,eventId:event.eventId,expectedRevision:event.revision+1,requestId:crypto.randomUUID(),reason:'dependency_restored'}));
 await o.flush();await i.flush();const aggregate=o.records.filter(x=>x.metric.event==='service_queue');assert.equal(aggregate.length,5);
 for(const r of aggregate)assert.equal(r.metric.clubId,24);
 metrics({...o,records:o.records.filter(x=>x.metric.event==='service_operation')},['delivery_claim','delivery_read','delivery_acknowledge','queue_health','delivery_inspection','delivery_redrive'],'allocation_delivery',[event.eventId,event.leaseId,ids.user,f.receipt.orderId]);
 metrics(i,['delivery_accept','delivery_inspection'],'allocation_delivery',[event.eventId,ids.user,f.receipt.orderId]);
 assert.equal(o.records.at(-1).metric.outcome,'unknown');assert.equal(f.count('pa_ledger'),1);assert.equal(f.sinkDb.sql.prepare('SELECT count(*) n FROM adi_events').get().n,1);
});
test('all recovery capability methods observe once and do not double emit internal preparation or confirmation',async t=>{
 const f=await recoveryFixture();t.after(()=>f.close());const o=observed(f.recoveryEnv);Object.assign(o.env,{RECOVERY_MAKER_PRINCIPAL_ID:MAKER,RECOVERY_CHECKER_PRINCIPAL_ID:CHECKER});
 const maker=binding(recovery.AllocationRecoveryMaker,o),checker=binding(recovery.AllocationRecoveryChecker,o),event={clubId:24,eventId:f.request.eventId};
 await maker.inspectEvent(event);assert.equal((await maker.prepare(f.request)).state,'prepared');
 await maker.decision({clubId:24,decisionId:f.request.decisionId});await checker.inspectEvent(event);
 await checker.decision({clubId:24,decisionId:f.request.decisionId});assert.equal((await checker.confirm(f.confirm)).committed,true);
 await o.flush();metrics(o,['delivery_inspection','delivery_prepare','delivery_inspection','delivery_inspection','delivery_inspection','delivery_confirm'],'allocation_delivery',
  [f.request.eventId,f.request.decisionId,f.request.operationId,f.request.evidenceRef,f.request.evidenceSha256,MAKER,CHECKER]);
 assert.equal(f.db.sql.prepare("SELECT count(*) n FROM pa_delivery_commands WHERE action='redrive'").get().n,1);
 assert.equal(f.count('pa_ledger'),1);assert.equal(f.sinkDb.sql.prepare('SELECT count(*) n FROM adi_events').get().n,0);
});
test('sender receipt validation failure before dispatch records one unknown observation with no provider call',async t=>{
 const f=senderFixture();t.after(()=>f.close());const o=observed(f.env);
 await assert.rejects(f.service.deliverWithReceipt({...f.input,template:'wrong_template'}));await o.flush();
 metrics(o,['credential_delivery'],'auth_code_delivery',[f.input.phone,f.input.code,f.input.challengeId,f.env.WA_ACCESS_TOKEN]);
 assert.equal(f.calls.length,0);assert.equal(o.records[0].metric.outcome,'unknown');
});
test('status-aware sender observes binding and receipt exactly once without nested sender emissions',async t=>{
 const f=receiptFixture(t),o=observed(f.env);
 assert.equal((await f.tracked.deliver(f.input)).accepted,true);
 assert.equal((await f.tracked.deliverWithReceipt({...f.input,template:f.route.templateName})).accepted,true);await o.flush();
 metrics(o,['credential_delivery','credential_delivery'],'auth_code_delivery',[f.input.phone,f.input.code,f.input.challengeId,'wamid.SYNTHETIC',f.env.WA_ACCESS_TOKEN]);
 assert.equal(f.calls.filter(x=>x.init.method==='POST').length,1);assert.equal(f.count('delivery_dispatches'),1);assert.equal(f.count('delivery_receipt_bindings'),1);
});
test('status-aware receipt-binding denial is observed before dispatch and cannot send',async t=>{
 const f=receiptFixture(t),o=observed(f.env);f.env.RECEIPT_BINDING_ENABLED='false';
 await assert.rejects(f.tracked.deliver(f.input));await o.flush();assert.equal(f.calls.length,0);assert.equal(o.records.length,1);
 assert.equal(o.records[0].metric.outcome,'unknown');assert.equal(f.count('delivery_dispatches'),0);
});
