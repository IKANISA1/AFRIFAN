import test from 'node:test';import assert from 'node:assert/strict';
import {fixture,SUBJECTS} from './fixture.mjs';
async function error(response,status,code){assert.equal(response.status,status);const r=await response.json();assert.equal(r.error.code,code);return r;}
function post(input){return {expectedRevision:input.expectedRevision,action:input.action,detail:input.detail};}
test('real gateway opens, reads and lists cases through private service',async t=>{
 const f=fixture(t),i=f.command(),r=await f.call(`/${i.caseId}/commands`,{body:post(i),headers:{'idempotency-key':i.operationId}});
 assert.equal(r.status,200);assert.equal((await r.json()).data.currentCase.caseId,i.caseId);
 assert.equal((await f.call(`/${i.caseId}`)).status,200);assert.equal((await f.call(`/${i.caseId}/history`)).status,200);
 const list=await f.call();assert.equal((await list.json()).data.cases.length,1);
});
test('missing Access context rejects forged headers',async t=>{
 const f=fixture(t);await error(await f.call('',{context:{},headers:{'cf-access-authenticated-user-email':'admin@example.invalid','x-user-id':SUBJECTS.maker}}),401,'authentication_required');
});
test('service identities cannot enter the human case workflow',async t=>{
 const f=fixture(t),c=f.context();const original=c.access.getIdentity;c.access.getIdentity=async()=>({...await original(),service_token_id:'synthetic'});
 await error(await f.call('',{context:c}),401,'human_operator_required');
});
for(const [name,headers] of [['no Origin',{origin:''}],['wrong intent',{'x-africlub-action':'publish-review'}],['cross-site',{'sec-fetch-site':'cross-site'}],['foreign Origin',{origin:'https://untrusted.example.invalid'}]])
 test(`${name} rejects mutation before writing`,async t=>{
 const f=fixture(t),i=f.command();await error(await f.call(`/${i.caseId}/commands`,{body:post(i),headers}),403,'origin_not_allowed');assert.equal(f.count(),0);
});
test('identity, role and club fields cannot be supplied by a browser',async t=>{
 const f=fixture(t),i=f.command();for(const key of ['identity','clubId','actor','role'])
  await error(await f.call(`/${i.caseId}/commands`,{body:{...post(i),[key]:'forged'}}),400,'invalid_request');
 assert.equal(f.count(),0);
});
test('unsafe JSON and oversized bodies are bounded by the existing gateway',async t=>{
 const f=fixture(t),i=f.command(),path=`/${i.caseId}/commands`;
 await error(await f.call(path,{body:'{'}),400,'invalid_json');
 await error(await f.call(path,{body:'x'.repeat(4097)}),413,'request_too_large');
 await error(await f.call(path,{body:post(i),headers:{'content-type':'text/plain'}}),415,'json_required');
 await error(await f.call(path,{body:post(i),headers:{'content-encoding':'gzip'}}),415,'content_encoding_not_supported');
});
test('method, route and query allowlists reject ambiguous requests',async t=>{
 const f=fixture(t);
 await error(await f.call('',{method:'POST'}),405,'method_not_allowed');
 await error(await f.call('?limit=1&limit=2'),400,'invalid_query');
 await error(await f.call('?identity=forged'),400,'invalid_query');
 await error(await f.call('?limit=51'),400,'invalid_limit');
 await error(await f.call('/not-a-uuid'),404,'not_found');
 await error(await f.call('/'+crypto.randomUUID()+'/history?after=-1'),400,'invalid_cursor');
});
test('operator switch and service availability fail closed independently',async t=>{
 const f=fixture(t);
 await error(await f.call('',{env:{OPERATOR_CASES_ENABLED:'false'}}),503,'operator_cases_disabled');
 await error(await f.call('',{env:{PAYMENT_EXCEPTION_CASES:null}}),503,'case_service_unavailable');
});
test('SQL and provider errors are not reflected to the browser',async t=>{
 const f=fixture(t);const r=await f.call('',{env:{PAYMENT_EXCEPTION_CASES:{list(){throw Error('SYNTHETIC-PASSWORD-RAW-SMS')}}}});
 assert.equal(r.status,503);const text=await r.text();assert.ok(!text.includes('PASSWORD'));assert.ok(!text.includes('RAW-SMS'));
});
test('successful and failed responses are private no-store with no wildcard CORS',async t=>{
 const f=fixture(t);for(const r of [await f.call(),await f.call('',{context:{}})]){
  assert.equal(r.headers.get('cache-control'),'no-store');assert.equal(r.headers.get('access-control-allow-origin'),null);assert.equal(r.headers.get('x-content-type-options'),'nosniff');
 }
});
test('stale browser approval returns 409 instead of reviewing a newer proposal',async t=>{
 const f=fixture(t),{input}=await f.open();await f.transition(input.caseId,'propose');await f.transition(input.caseId,'reject','checker');await f.transition(input.caseId,'propose');
 const body={expectedRevision:2,action:'approve',detail:{reasonCode:'review_complete',evidenceDigest:null}};
 await error(await f.call(`/${input.caseId}/commands`,{who:'checker',body}),409,'stale_revision');assert.equal(f.count(),4);
});
test('known key replay through HTTP preserves operation and event identity',async t=>{
 const f=fixture(t),i=f.command(),options={body:post(i),headers:{'idempotency-key':i.operationId}},path=`/${i.caseId}/commands`;
 const a=await(await f.call(path,options)).json(),b=await(await f.call(path,options)).json();
 assert.equal(a.data.outcome.eventId,b.data.outcome.eventId);assert.equal(b.data.replayed,true);assert.equal(f.count(),1);
});
