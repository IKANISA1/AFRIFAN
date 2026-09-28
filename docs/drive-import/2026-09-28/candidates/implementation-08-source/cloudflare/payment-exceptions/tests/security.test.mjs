import test from 'node:test';import assert from 'node:assert/strict';
import {fixture,SUBJECTS,NOW,rejects} from './fixture.mjs';
for(const [name,sql] of [
 ['operator disabled',`UPDATE px_operators SET enabled=0 WHERE subject='${SUBJECTS.maker}'`],
 ['grant disabled',`UPDATE px_grants SET enabled=0 WHERE subject='${SUBJECTS.maker}'`],
 ['club disabled','UPDATE px_clubs SET enabled=0 WHERE club_id=24'],
 ['settings disabled','UPDATE px_settings SET enabled=0'],
 ['operator expired',`UPDATE px_operators SET expires_at_ms=${NOW} WHERE subject='${SUBJECTS.maker}'`],
])test(`${name} blocks both reads and writes`,async t=>{
 const f=fixture(t),{input}=await f.open();f.db.sql.exec(sql);
 await rejects(()=>f.service.get({identity:f.identity(),clubId:24,caseId:input.caseId}),'forbidden');
 await rejects(()=>f.service.command(f.command()),'forbidden');assert.equal(f.count(),1);
});
for(const [name,sql,code] of [
 ['revoke grant',`UPDATE px_grants SET enabled=0 WHERE subject='${SUBJECTS.maker}'`,'forbidden'],
 ['disable club','UPDATE px_clubs SET enabled=0 WHERE club_id=24','forbidden'],
 ['disable service','UPDATE px_settings SET enabled=0','forbidden'],
 ['expire actor',`UPDATE px_operators SET expires_at_ms=${NOW} WHERE subject='${SUBJECTS.maker}'`,'forbidden'],
 ['switch environment',"UPDATE px_settings SET environment='production'",'forbidden'],
])test(`${name} between preflight and INSERT cannot create an event`,async t=>{
 const f=fixture(t);f.db.beforeRun=()=>f.db.sql.exec(sql);await rejects(()=>f.service.command(f.command()),code);assert.equal(f.count(),0);
});
test('revocation after commit withholds response without pretending to undo history',async t=>{
 const f=fixture(t);f.db.afterRun=()=>f.db.sql.prepare('UPDATE px_operators SET enabled=0 WHERE subject=?').run(SUBJECTS.maker);
 await rejects(()=>f.service.command(f.command()),'forbidden');assert.equal(f.count(),1);
});
test('wrong tenant does not disclose case existence',async t=>{
 const f=fixture(t),{input}=await f.open();await rejects(()=>f.service.get({identity:f.identity('other'),clubId:26,caseId:input.caseId}),'not_found');
 await rejects(()=>f.service.get({identity:f.identity('other'),clubId:24,caseId:input.caseId}),'forbidden');
});
test('reader cannot create or approve cases',async t=>{
 const f=fixture(t);await rejects(()=>f.service.command(f.command({identity:f.identity('reader')})),'forbidden');
 const {input}=await f.open();assert.equal((await f.service.get({identity:f.identity('reader'),clubId:24,caseId:input.caseId})).state,'open');
});
test('checker cannot create or rewrite case classification',async t=>{
 const f=fixture(t);await rejects(()=>f.service.command(f.command({identity:f.identity('checker')})),'forbidden');
});
for(const [name,mutate,code] of [
 ['forged body role',i=>{i.identity.role='checker'},'invalid_request'],
 ['unexpected phone',i=>{i.detail.phone='+250000000000'},'invalid_request'],
 ['freeform raw SMS',i=>{i.detail.rawSms='sensitive'},'invalid_request'],
 ['invalid category',i=>{i.detail.category='auto_refund'},'invalid_category'],
 ['no references',i=>{i.detail.orderId=null;i.detail.evidenceId=null},'reference_required'],
 ['unsafe integer',i=>{i.clubId=Number.MAX_SAFE_INTEGER+1},'invalid_club_id'],
 ['negative revision',i=>{i.expectedRevision=-1},'invalid_revision'],
 ['wrong initial revision',i=>{i.expectedRevision=3},'invalid_revision'],
 ['SQL-shaped ID',i=>{i.caseId="';DROP TABLE px_cases;--"},'invalid_case_id'],
 ['invalid evidence digest',i=>{i.detail.evidenceDigest='receipt-raw'},'invalid_evidence_digest'],
 ['body financial action',i=>{i.detail.refundAmount=10},'invalid_request'],
 ['bad operation UUID',i=>{i.operationId='a'},'invalid_operation_id'],
 ['unknown action',i=>{i.action='refund'},'invalid_action'],
])test(`rejects ${name}`,async t=>{
 const f=fixture(t),input=f.command();mutate(input);await rejects(()=>f.service.command(input),code);assert.equal(f.count(),0);
});
test('wrong account and audience cannot match grants',async t=>{
 const f=fixture(t);for(const identity of [{...f.identity(),accountId:'c'.repeat(32)},{...f.identity(),audience:'c'.repeat(64)}])
  await rejects(()=>f.service.command(f.command({identity})),'forbidden');
});
for(const sql of ["UPDATE px_events SET reason_code='new_evidence'","DELETE FROM px_events","DELETE FROM px_cases","UPDATE px_cases SET state='closed'","UPDATE px_cases SET disposition='refer_refund_review'"])
 test(`SQL journal/projection rejects direct tampering: ${sql.split(' ').slice(0,3).join(' ')}`,async t=>{
  const f=fixture(t);await f.open();assert.throws(()=>f.db.sql.exec(sql),/px_immutable/);assert.equal(f.count(),1);
 });
test('runtime disabled switch cannot be bypassed with SQL enablement',async t=>{
 const f=fixture(t);f.env.PAYMENT_CASES_ENABLED='false';await rejects(()=>f.service.command(f.command()),'case_service_disabled');
});
test('replaying a known key after revocation reveals no prior outcome',async t=>{
 const f=fixture(t),{input}=await f.open();f.db.sql.prepare('UPDATE px_grants SET enabled=0 WHERE subject=?').run(SUBJECTS.maker);
 await rejects(()=>f.service.command(input),'forbidden');assert.equal(f.count(),1);
});
test('case ID cannot be reused by a different club',async t=>{
 const f=fixture(t),{input}=await f.open();await rejects(()=>f.service.command(f.command({caseId:input.caseId,identity:f.identity('other'),clubId:26})),'case_conflict');
});
test('bounded list rejects invalid limits and cursors',async t=>{
 const f=fixture(t),base={identity:f.identity(),clubId:24,afterCaseId:null,state:null,limit:25};
 for(const limit of [0,-1,51,1.5])await rejects(()=>f.service.list({...base,limit}),'invalid_limit');
 await rejects(()=>f.service.list({...base,afterCaseId:'not-a-cursor'}),'invalid_cursor');
 await rejects(()=>f.service.list({...base,state:'paid'}),'invalid_state');
});
