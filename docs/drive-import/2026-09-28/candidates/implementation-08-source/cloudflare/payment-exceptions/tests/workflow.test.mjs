import test from 'node:test';
import assert from 'node:assert/strict';
import {fixture, SUBJECTS, NOW, rejects} from './fixture.mjs';
import {CATEGORIES} from '../src/policy.mjs';
for(const category of CATEGORIES)test(`open ${category} case is metadata only`,async t=>{
 const f=fixture(t),input=f.command();input.detail.category=category;
 const r=await f.service.command(input);assert.equal(r.currentCase.state,'open');assert.equal(r.currentCase.revision,1);
 assert.equal(r.currentCase.category,category);assert.equal(r.currentCase.financialEffect,'none');assert.equal(r.currentCase.referencesVerified,false);
 assert.equal(r.outcome.revision,1);assert.equal(f.count(),1);
});
test('full maker/checker lifecycle and reopening retain immutable history',async t=>{
 const f=fixture(t),o=await f.open(),id=o.input.caseId;
 await f.transition(id,'triage');await f.transition(id,'propose');
 const approved=await f.transition(id,'approve','checker');
 assert.equal(approved.result.currentCase.state,'reviewed');assert.equal(approved.result.currentCase.reviewerSubject,SUBJECTS.checker);
 assert.equal(approved.result.currentCase.proposerSubject,SUBJECTS.maker);
 const closed=await f.transition(id,'close');assert.equal(closed.result.currentCase.state,'closed');
 const reopened=await f.transition(id,'reopen');assert.equal(reopened.result.currentCase.state,'investigating');
 for(const k of ['disposition','proposerSubject','proposalDigest','reviewerSubject','reviewEventId'])assert.equal(reopened.result.currentCase[k],null);
 const h=await f.service.history({identity:f.identity(),clubId:24,caseId:id,afterRevision:0,limit:50});
 assert.deepEqual(h.events.map(x=>x.action),['open','triage','propose','approve','close','reopen']);assert.equal(f.count(),6);
});
test('rejection invalidates proposal and allows a fresh reviewed proposal',async t=>{
 const f=fixture(t),{input}=await f.open();await f.transition(input.caseId,'propose');
 const r=await f.transition(input.caseId,'reject','checker');assert.equal(r.result.currentCase.disposition,null);
 await f.transition(input.caseId,'propose');await f.transition(input.caseId,'approve','checker');
 assert.equal(f.count(),5);
});
test('same command replay does not append and returns original outcome plus current head',async t=>{
 const f=fixture(t),{input}=await f.open();await f.transition(input.caseId,'triage');
 const r=await f.service.command(input);assert.equal(r.replayed,true);assert.equal(r.outcome.revision,1);assert.equal(r.currentCase.revision,2);assert.equal(f.count(),2);
});
test('canonical hashing ignores property order on an exact retry',async t=>{
 const f=fixture(t),{input}=await f.open();const d=input.detail;input.detail={evidenceId:d.evidenceId,orderId:d.orderId,category:d.category,evidenceDigest:d.evidenceDigest,reasonCode:d.reasonCode};
 assert.equal((await f.service.command(input)).replayed,true);
});
test('idempotency key reuse for changed payload is a conflict',async t=>{
 const f=fixture(t),{input}=await f.open();input.detail.category='late';await rejects(()=>f.service.command(input),'idempotency_conflict');assert.equal(f.count(),1);
});
test('a committed response lost in transit recovers the same event',async t=>{
 const f=fixture(t),input=f.command();f.db.loseRun=true;const r=await f.service.command(input);
 assert.equal(r.replayed,true);assert.equal(f.count(),1);assert.equal((await f.service.command(input)).outcome.eventId,r.outcome.eventId);
});
test('pre-commit database failure is redacted and creates no projection',async t=>{
 const f=fixture(t);f.db.failRun=true;await rejects(()=>f.service.command(f.command()),'case_service_unavailable');
 assert.equal(f.count(),0);assert.equal(f.db.sql.prepare('SELECT count(*) n FROM px_cases').get().n,0);
});
test('projection failure rolls back event insertion atomically',async t=>{
 const f=fixture(t);f.db.sql.exec("CREATE TRIGGER synthetic_failure BEFORE INSERT ON px_cases BEGIN SELECT RAISE(ABORT,'SYNTHETIC-SECRET'); END;");
 await rejects(()=>f.service.command(f.command()),'case_service_unavailable');assert.equal(f.count(),0);
});
test('stale approval cannot approve a replaced proposal even after returning to awaiting_review',async t=>{
 const f=fixture(t),{input}=await f.open();await f.transition(input.caseId,'propose');
 const stale=f.command({identity:f.identity('checker'),caseId:input.caseId,expectedRevision:2,action:'approve',detail:{reasonCode:'review_complete',evidenceDigest:null}});
 await f.transition(input.caseId,'reject','checker');await f.transition(input.caseId,'propose');
 await rejects(()=>f.service.command(stale),'stale_revision');assert.equal(f.count(),4);
 const r=await f.service.get({identity:f.identity(),clubId:24,caseId:input.caseId});assert.equal(r.state,'awaiting_review');assert.equal(r.reviewerSubject,null);
});
test('two concurrent same-revision proposals produce exactly one event',async t=>{
 const f=fixture(t),{input}=await f.open();const cmd=()=>f.command({caseId:input.caseId,action:'propose',expectedRevision:1,detail:{reasonCode:'review_complete',evidenceDigest:'d'.repeat(64),disposition:'no_financial_change'}});
 const r=await Promise.allSettled([f.service.command(cmd()),f.service.command(cmd())]);
 assert.equal(r.filter(x=>x.status==='fulfilled').length,1);assert.equal(r.find(x=>x.status==='rejected').reason.code,'stale_revision');assert.equal(f.count(),2);
});
test('concurrent same-operation retries converge to one event',async t=>{
 const f=fixture(t),input=f.command();const r=await Promise.all([f.service.command(input),f.service.command(input)]);
 assert.equal(r[0].outcome.eventId,r[1].outcome.eventId);assert.equal(f.count(),1);
});
for(const [action,state] of [['approve','open'],['close','open'],['reopen','open'],['reject','open']])test(`invalid ${action} from ${state} is rejected`,async t=>{
 const f=fixture(t),{input}=await f.open();await rejects(()=>f.transition(input.caseId,action,['approve','reject'].includes(action)?'checker':'maker'),'invalid_transition');assert.equal(f.count(),1);
});
test('two-role operator still cannot approve their own proposal',async t=>{
 const f=fixture(t);f.db.sql.prepare("INSERT INTO px_grants VALUES(?,24,'checker',1)").run(SUBJECTS.maker);
 const {input}=await f.open();await f.transition(input.caseId,'propose');await rejects(()=>f.transition(input.caseId,'approve'),'self_review');assert.equal(f.count(),2);
});
test('close does not claim financial execution and requires an evidence digest',async t=>{
 const f=fixture(t),{input}=await f.open();await f.transition(input.caseId,'propose');await f.transition(input.caseId,'approve','checker');
 await rejects(()=>f.transition(input.caseId,'close','maker',{detail:{reasonCode:'review_complete',evidenceDigest:null}}),'evidence_digest_required');
 const r=await f.transition(input.caseId,'close');assert.equal(r.result.currentCase.financialEffect,'none');
});
test('case listing is tenant scoped and bounded with keyset pagination',async t=>{
 const f=fixture(t);for(let i=0;i<4;i++)await f.open();await f.open({identity:f.identity('other'),clubId:26});
 const args={identity:f.identity(),clubId:24,afterCaseId:null,limit:2,state:null};
 const a=await f.service.list(args),b=await f.service.list({...args,afterCaseId:a.nextCaseId});
 assert.equal(a.cases.length,2);assert.equal(b.cases.length,2);assert.equal(b.nextCaseId,null);
 assert.equal(new Set([...a.cases,...b.cases].map(x=>x.caseId)).size,4);assert.equal(a.snapshot,false);
});
test('history cursor returns each revision once',async t=>{
 const f=fixture(t),{input}=await f.open();await f.transition(input.caseId,'triage');await f.transition(input.caseId,'propose');
 const args={identity:f.identity(),clubId:24,caseId:input.caseId,afterRevision:0,limit:2};
 const a=await f.service.history(args),b=await f.service.history({...args,afterRevision:a.nextRevision});
 assert.deepEqual([...a.events,...b.events].map(x=>x.revision),[1,2,3]);assert.equal(b.nextRevision,null);
});
test('state-filtered list uses a dedicated bounded query',async t=>{
 const f=fixture(t),a=await f.open();await f.open();await f.transition(a.input.caseId,'triage');
 const r=await f.service.list({identity:f.identity(),clubId:24,afterCaseId:null,limit:50,state:'investigating'});
 assert.deepEqual(r.cases.map(x=>x.caseId),[a.input.caseId]);
});
test('all read sessions start primary and contain no provider I/O',async t=>{
 const f=fixture(t);await f.open();assert.ok(f.db.sessions.length>0);assert.ok(f.db.sessions.every(x=>x==='first-primary'));
 const tables=f.db.sql.prepare("SELECT name FROM sqlite_master WHERE type='table'").all().map(x=>x.name);
 assert.ok(tables.every(x=>x.startsWith('px_')));
});
