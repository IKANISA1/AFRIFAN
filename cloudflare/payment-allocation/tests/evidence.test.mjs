import test from 'node:test';
import assert from 'node:assert/strict';
import {fixture} from './fixture.mjs';
import {canonical,hash,normalizeEvidence} from '../src/policy.mjs';
const cases=[
 ['missing request ID',v=>delete v.requestId],['caller role',v=>v.role='admin'],['caller principal',v=>v.principalId=crypto.randomUUID()],
 ['raw unknown field',v=>v.raw.code='PRIVATE'],['parsed unknown field',v=>v.parsed.confirmed=true],
 ['raw mock',v=>v.raw.isMock=true],['parsed mock',v=>v.parsed.isMock=true],['string mock flag',v=>v.raw.isMock='false'],
 ['review-needed parse',v=>v.parsed.parseStatus='needs_review'],['credit not debit',v=>v.parsed.direction='credit'],
 ['zero amount',v=>v.parsed.amount=0],['negative amount',v=>v.parsed.amount=-1],['decimal amount',v=>v.parsed.amount=10.25],
 ['string amount',v=>v.parsed.amount='10000'],['overflow amount',v=>v.parsed.amount=2147483648],
 ['NaN amount',v=>v.parsed.amount=NaN],['missing raw link',v=>v.parsed.rawId=crypto.randomUUID()],
 ['wrong owner',v=>v.parsed.userId=crypto.randomUUID()],['wrong club',v=>v.parsed.clubId=25],['wrong raw country',v=>v.raw.country='BI'],
 ['invalid recipient',v=>v.parsed.recipient='123+456'],['short recipient',v=>v.parsed.recipient='1'],
 ['invalid currency',v=>v.parsed.currency='RF'],['invalid country',v=>v.raw.country='RWA'],['invalid provider',v=>v.raw.provider='javascript:bad'],
 ['raw hash wrong length',v=>v.raw.sha256='b'.repeat(63)],['invalid time',v=>v.raw.receivedAt=-1],['fractional time',v=>v.parsed.transactionAt=10.5],
 ['empty provider reference',v=>v.parsed.providerReference=' '],['oversized provider reference',v=>v.parsed.providerReference='T'.repeat(129)],
 ['invalid attestation',v=>v.attestationRef='<script>'],['future out-of-range time',v=>v.parsed.transactionAt=Infinity]
];
for(const [name,change] of cases)test(`ingestion rejects ${name}`,async t=>{const f=fixture();t.after(()=>f.close());change(f.input);await assert.rejects(f.ingestion.ingest(f.input));assert.equal(f.count('pa_commands'),0);assert.equal(f.count('pa_raw_evidence'),0);assert.equal(f.count('pa_evidence'),0);});
test('canonical MTN aliases and country/currency case match normalized order',async t=>{const f=fixture();t.after(()=>f.close());f.input.raw.provider=' MTN Rwanda ';f.input.raw.country='rw';f.input.parsed.country=' rw ';f.input.parsed.currency='rwf';f.input.parsed.providerReference=' '+f.input.parsed.providerReference+' ';await f.ingestion.ingest(f.input);const r=await f.allocator.allocate(f.allocation());assert.equal(r.businessTargetFulfilled,true);});
test('same evidence content and request retries without a new record',async t=>{const f=fixture();t.after(()=>f.close());const a=await f.ingestion.ingest(f.input);assert.deepEqual(await f.ingestion.ingest(f.input),a);assert.equal(f.count('pa_commands'),1);});
test('same evidence with new request ID is a readback not a second command',async t=>{const f=fixture();t.after(()=>f.close());await f.ingestion.ingest(f.input);f.input.requestId=crypto.randomUUID();await f.ingestion.ingest(f.input);assert.equal(f.count('pa_commands'),1);});
test('same request ID with different evidence is conflicting',async t=>{const f=fixture();t.after(()=>f.close());await f.ingestion.ingest(f.input);f.input.parsed.amount++;await assert.rejects(f.ingestion.ingest(f.input),{code:'idempotency_conflict'});assert.equal(f.count('pa_evidence'),1);});
test('same parsed ID with changed content cannot be aliased by another request',async t=>{const f=fixture();t.after(()=>f.close());await f.ingestion.ingest(f.input);f.input.requestId=crypto.randomUUID();f.input.parsed.amount++;await assert.rejects(f.ingestion.ingest(f.input),{code:'evidence_conflict'});assert.equal(f.count('pa_evidence'),1);});
test('one raw ID cannot produce two interpretations',async t=>{const f=fixture();t.after(()=>f.close());await f.ingestion.ingest(f.input);f.input.requestId=crypto.randomUUID();f.input.parsed.id=crypto.randomUUID();await assert.rejects(f.ingestion.ingest(f.input));assert.equal(f.count('pa_evidence'),1);assert.equal(f.count('pa_commands'),1);});
test('parallel ingestion replay commits one raw and one parsed record',async t=>{const f=fixture();t.after(()=>f.close());await Promise.all(Array.from({length:8},()=>f.ingestion.ingest(f.input)));assert.equal(f.count('pa_commands'),1);assert.equal(f.count('pa_raw_evidence'),1);assert.equal(f.count('pa_evidence'),1);});
test('canonical hash does not depend on object key order',async()=>{assert.equal(canonical({b:2,a:1}),canonical({a:1,b:2}));assert.equal(await hash({b:2,a:1}),await hash({a:1,b:2}));});
test('parsed acknowledgement does not expose raw data or make payment claims',async t=>{const f=fixture();t.after(()=>f.close());assert.deepEqual(Object.keys(await f.ingestion.ingest(f.input)).sort(),['clubId','evidenceId','recorded','schemaVersion']);assert.equal(f.count('pa_memberships'),0);assert.equal(f.count('pa_ledger'),0);});
test('original object remains unmodified by normalization',t=>{const f=fixture();t.after(()=>f.close());f.input.raw.provider='MTN';const copy=structuredClone(f.input);normalizeEvidence(f.input);assert.deepEqual(f.input,copy);});
test('SQL rejects fabricated parsed ownership even outside JavaScript parser',async t=>{const f=fixture();t.after(()=>f.close());await f.ingestion.ingest(f.input);const row=f.db.sql.prepare('SELECT * FROM pa_evidence').get();assert.throws(()=>f.db.sql.prepare('UPDATE pa_evidence SET user_id=?').run(crypto.randomUUID()));assert.equal(f.db.sql.prepare('SELECT user_id FROM pa_evidence').get().user_id,row.user_id);});
