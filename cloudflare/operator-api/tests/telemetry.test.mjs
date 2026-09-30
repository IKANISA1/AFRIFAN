import test from 'node:test';import assert from 'node:assert/strict';import {requestMetric,emitRequestMetric} from '../src/telemetry.mjs';import {createOperatorGateway} from '../src/index.mjs';import {fixture} from '../../payment-exceptions/tests/fixture.mjs';
const request=()=>new Request('https://operator.example.invalid/v1/admin/clubs/24/payment-exceptions/10000000-0000-4000-8000-000000000001/commands?secret=PRIVATE',{method:'POST',headers:{authorization:'Bearer PRIVATE',cookie:'PRIVATE','cf-connecting-ip':'1.2.3.4'},body:'{"phone":"PRIVATE","sms":"PRIVATE"}'});
test('metrics contain only fixed vocabulary, status, timing and generated request id',()=>{const id=crypto.randomUUID(),r=requestMetric(request(),new Response(null,{status:200}),id,12.6);assert.deepEqual(r,{schemaVersion:1,event:'operator_http_response',requestId:id,route:'case_command',method:'POST',responseStatus:200,durationMs:13});assert.doesNotMatch(JSON.stringify(r),/PRIVATE|cookie|phone|sms|operator\.example/);});
for(const enabled of [undefined,false,true,'false','TRUE',1])test(`telemetry disabled without exact opt-in ${String(enabled)}`,()=>{assert.equal(emitRequestMetric({OPERATOR_METRICS_ENABLED:enabled},request(),new Response(),crypto.randomUUID(),0,()=>{throw Error('must not run');}),false);});
test('sink failure does not alter a response or propagate data',()=>{assert.equal(emitRequestMetric({OPERATOR_METRICS_ENABLED:'true'},request(),new Response(),crypto.randomUUID(),0,()=>{throw Error('sensitive-sink');}),false);});
test('unknown paths and malformed timings are normalized',()=>{const r=requestMetric(new Request('https://a.invalid/phone/PRIVATE'),new Response(),crypto.randomUUID(),Infinity);assert.equal(r.route,'other');assert.equal(r.durationMs,null);assert.doesNotMatch(JSON.stringify(r),/PRIVATE/);});
test('invalid request correlation id is rejected',()=>assert.equal(requestMetric(request(),new Response(),'PRIVATE',0),null));
test('real case gateway response and metric use same request correlation',async t=>{const f=fixture(t),lines=[],g=createOperatorGateway({sink:x=>lines.push(JSON.parse(x)),clock:()=>50});const r=await g.fetch(new Request(f.httpEnv.OPERATOR_API_ORIGIN+'/v1/admin/clubs/24/payment-exceptions/session'),{...f.httpEnv,OPERATOR_METRICS_ENABLED:'true'},f.context());const body=await r.json();assert.equal(r.status,200);assert.equal(lines.length,1);assert.equal(lines[0].requestId,body.requestId);assert.equal(lines[0].route,'case_session');assert.equal(lines[0].durationMs,0);assert.equal('subject' in lines[0],false);});
test('Access rejection is measured without sensitive diagnostics',async t=>{const f=fixture(t),lines=[],g=createOperatorGateway({sink:x=>lines.push(JSON.parse(x))});const r=await g.fetch(new Request(f.httpEnv.OPERATOR_API_ORIGIN+'/v1/admin/clubs/24/payment-exceptions/session'),{...f.httpEnv,OPERATOR_METRICS_ENABLED:'true'},{});assert.equal(r.status,401);assert.equal(lines[0].responseStatus,401);assert.equal(Object.hasOwn(lines[0],'error'),false);});
function observation(env,record){const values=[],pending=[];Object.assign(env,{PRIVATE_METRICS_ENABLED:'true',PRIVATE_METRICS_RETENTION_MS:'3600000',PRIVATE_METRICS_POLICY_REF:'SYNTHETIC_TEST_POLICY',PRIVATE_METRICS:{record:record??(async x=>values.push(x))}});
 return {env,values,context:f=>({...f.context(),waitUntil(p){pending.push(p);}}),flush:async()=>{for(const p of pending)await p;await new Promise(r=>setTimeout(r,0));}};}
function commandRequest(f,v){return new Request(f.httpEnv.OPERATOR_API_ORIGIN+'/v1/admin/clubs/24/payment-exceptions/'+v.caseId+'/commands',
 {method:'POST',headers:{'content-type':'application/json',origin:f.httpEnv.OPERATOR_API_ORIGIN,'x-africlub-action':'payment-case-review','idempotency-key':v.operationId},
 body:JSON.stringify({expectedRevision:v.expectedRevision,action:v.action,detail:v.detail})});}
test('one private event reuses generated response correlation and suppresses legacy duplicate emission',async t=>{
 const f=fixture(t),o=observation({...f.httpEnv,OPERATOR_METRICS_ENABLED:'true'});let legacy=0;
 const r=await createOperatorGateway({sink(){legacy++;}}).fetch(new Request(f.httpEnv.OPERATOR_API_ORIGIN+'/v1/admin/clubs/24/payment-exceptions/session',
 {headers:{cookie:'SENSITIVE_COOKIE','x-request-id':'SENSITIVE_INBOUND','cf-connecting-ip':'1.2.3.4'}}),o.env,o.context(f));
 const body=await r.json();await o.flush();assert.equal(r.status,200);assert.equal(legacy,0);assert.equal(o.values.length,1);
 const metric=o.values[0].metric;assert.equal(metric.traceId,body.requestId);assert.equal(metric.clubId,24);assert.equal(metric.operation,'case_read');assert.equal(metric.outcome,'completed');
 assert.doesNotMatch(JSON.stringify(o.values),/SENSITIVE|cookie|subject|operator\.example|1\.2\.3\.4/);
});
test('missing configured retention never falls back to a legacy or console destination',async t=>{
 const f=fixture(t),o=observation({...f.httpEnv,OPERATOR_METRICS_ENABLED:'true'});delete o.env.PRIVATE_METRICS_RETENTION_MS;let legacy=0;
 const r=await createOperatorGateway({sink(){legacy++;}}).fetch(new Request(f.httpEnv.OPERATOR_API_ORIGIN+'/v1/admin/clubs/24/payment-exceptions/session'),o.env,o.context(f));
 await o.flush();assert.equal(r.status,200);assert.equal(o.values.length,0);assert.equal(legacy,0);
 assert.equal(emitRequestMetric({OPERATOR_METRICS_ENABLED:'true'},request(),new Response(),crypto.randomUUID(),0),false);
});
test('throwing injected clock and private sink cannot change or retry a committed operator command',async t=>{
 const f=fixture(t),v=f.command();let calls=0,sinks=0;const original=f.httpEnv.PAYMENT_EXCEPTION_CASES.command;
 f.httpEnv.PAYMENT_EXCEPTION_CASES.command=input=>{calls++;return original(input);};
 const o=observation(f.httpEnv,()=>{sinks++;throw Error('SENSITIVE_SINK');});
 const r=await createOperatorGateway({clock(){throw Error('SENSITIVE_CLOCK');}}).fetch(commandRequest(f,v),o.env,o.context(f));
 assert.equal(r.status,200);assert.equal((await r.json()).data.currentCase.caseId,v.caseId);await o.flush();
 assert.equal(calls,1);assert.equal(sinks,1);assert.equal(f.count(),1);
});
test('lost commit acknowledgement and revoked permission emit unknown without another operator command',async t=>{
 const f=fixture(t),v=f.command(),o=observation(f.httpEnv);let calls=0;const original=f.httpEnv.PAYMENT_EXCEPTION_CASES.command;
 f.httpEnv.PAYMENT_EXCEPTION_CASES.command=input=>{calls++;return original(input);};
 f.db.afterRun=()=>f.db.sql.exec('UPDATE px_grants SET enabled=0');f.db.loseRun=true;
 const r=await createOperatorGateway().fetch(commandRequest(f,v),o.env,o.context(f));assert.equal(r.status,403);await o.flush();
 assert.equal(calls,1);assert.equal(f.count(),1);assert.equal(o.values.length,1);assert.equal(o.values[0].metric.outcome,'unknown');
 assert.equal(JSON.stringify(o.values).includes(v.caseId),false);assert.equal(JSON.stringify(o.values).includes(v.operationId),false);
});
test('legacy explicitly injected async sink rejection remains detached from the response',async t=>{
 const f=fixture(t);let calls=0;
 const r=await createOperatorGateway({sink(){calls++;return Promise.reject(Error('SENSITIVE'));}}).fetch(new Request(f.httpEnv.OPERATOR_API_ORIGIN+'/v1/admin/clubs/24/payment-exceptions/session'),{...f.httpEnv,OPERATOR_METRICS_ENABLED:'true'},f.context());
 assert.equal(r.status,200);await new Promise(r=>setTimeout(r,0));assert.equal(calls,1);
});
