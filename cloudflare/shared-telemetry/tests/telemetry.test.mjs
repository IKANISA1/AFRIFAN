import test from 'node:test';import assert from 'node:assert/strict';
import {operationMetric,queueMetric,emitMetric,traceOperation,telemetryConfiguration} from '../telemetry.mjs';
const NOW=Date.UTC(2026,8,30),traceId='90000000-0000-4000-8000-000000000001';
const input=()=>({service:'auth_code_delivery',operation:'credential_delivery',traceId,clubId:24,observedAt:NOW,durationMs:12.3,outcome:'unknown'});
const env=(record)=>({PRIVATE_METRICS_ENABLED:'true',PRIVATE_METRICS_RETENTION_MS:'86400000',PRIVATE_METRICS_POLICY_REF:'SYNTHETIC_TEST_POLICY',PRIVATE_METRICS:{record}});
test('finite schema emits no sensitive request fields and rounds bounded duration',()=>{
 const value=operationMetric(input());assert.deepEqual(Object.keys(value),['schemaVersion','event','service','operation','traceId','clubId','observedAt','durationMs','outcome']);
 assert.equal(value.durationMs,12);assert.ok(Object.isFrozen(value));
 assert.equal(operationMetric({...input(),durationMs:Infinity}).durationMs,null);
 assert.equal(operationMetric({...input(),durationMs:999999999}).durationMs,3600000);
});
for(const patch of [{phone:'+250700000001'},{body:'secret'},{service:'unbounded-customer-name'},{operation:'/secret?token=abc'},{outcome:['completed']},
 {traceId:'phone-number'},{traceId:['90000000-0000-4000-8000-000000000001']},{clubId:'24'},{clubId:0},{observedAt:Infinity},{observedAt:true}])
 test(`rejects sensitive or malformed metric ${Object.keys(patch)[0]}`,()=>assert.equal(operationMetric({...input(),...patch}),null));
test('queue ages/counts are bounded and dead/unknown backlog remains visible',()=>{
 const value=queueMetric({service:'allocation_delivery',clubId:24,observedAt:NOW,state:'dead',count:1000,oldestAt:NOW-5000,capped:true});
 assert.equal(value.oldestAgeMs,5000);assert.equal(value.capped,true);assert.ok(!JSON.stringify(value).includes('eventId'));
 assert.equal(queueMetric({service:'auth_code_delivery',clubId:24,observedAt:NOW,state:'unknown',count:1,oldestAt:NOW+1,capped:false}),null);
});
test('no enabled metrics without explicit retention, policy reference and private binding',()=>{
 for(const patch of [{PRIVATE_METRICS_ENABLED:'false'},{PRIVATE_METRICS_RETENTION_MS:undefined},{PRIVATE_METRICS_RETENTION_MS:'0'},
  {PRIVATE_METRICS_POLICY_REF:'https://private.test/person'},{PRIVATE_METRICS:null}])assert.equal(telemetryConfiguration({...env(()=>{}),...patch}),null);
});
test('sink cannot receive fields smuggled around the metric constructor',async()=>{
 let calls=0;assert.equal(await emitMetric(env(()=>{calls++;}),{...operationMetric(input()),phone:'secret'}),false);
 assert.equal(await emitMetric(env(()=>{calls++;}),{...queueMetric({service:'allocation_delivery',clubId:24,observedAt:NOW,state:'retry',count:1,oldestAt:null,capped:false}),token:'secret'}),false);
 assert.equal(calls,0);
});
test('sink rejection never retries or changes a successful command',async()=>{
 let writes=0,sinks=0;const result=await traceOperation(env(()=>{sinks++;throw Error('private diagnostic');}),{service:'payment_allocation',operation:'payment_allocate',clubId:24},
  async()=>{writes++;return {committed:true};},{clock:()=>NOW});
 await new Promise(resolve=>setTimeout(resolve,30));assert.deepEqual(result,{committed:true});assert.equal(writes,1);assert.equal(sinks,1);
});
test('hung sink is bounded and an ignored timeout never invokes it again',async()=>{
 let calls=0;const start=performance.now();assert.equal(await emitMetric(env(()=>{calls++;return new Promise(()=>{});}),operationMetric(input()),{deadlineMs:10}),false);
 assert.ok(performance.now()-start<500);assert.equal(calls,1);
});
test('operation uses random local trace and a bounded outcome instead of request values',async()=>{
 const emitted=[];await traceOperation(env(x=>emitted.push(x)),{service:'supporter_auth',operation:'session_read',clubId:24},async()=>({token:'private'}),
  {clock:()=>NOW,selectOutcome:()=>'/private-secret'});await new Promise(resolve=>setTimeout(resolve,0));
 assert.equal(emitted.length,1);assert.equal(emitted[0].metric.outcome,'unknown');assert.notEqual(emitted[0].metric.traceId,traceId);
 assert.ok(!JSON.stringify(emitted).includes('private-secret'));assert.ok(!JSON.stringify(emitted).includes('token'));
});
test('original thrown object is preserved without logging it or introducing another attempt',async()=>{
 const values=[],error=Object.assign(Error('token=private'),{code:'permission_denied'});let calls=0;
 await assert.rejects(()=>traceOperation(env(v=>values.push(v)),{service:'supporter_membership',operation:'membership_read'},()=>{calls++;throw error;},{clock:()=>NOW}),e=>e===error);
 await new Promise(resolve=>setTimeout(resolve,0));assert.equal(calls,1);assert.equal(values[0].metric.outcome,'denied');assert.ok(!JSON.stringify(values).includes('token'));
});
test('invalid outer schema cannot be silently normalized into an accepted metric',async()=>{
 let calls=0;assert.equal(await emitMetric(env(()=>{calls++;}),{...operationMetric(input()),schemaVersion:2}),false);assert.equal(calls,0);
});
test('classifier, clock, waitUntil and configuration failures cannot override committed work',async()=>{
 let writes=0;const brokenEnv=Object.defineProperty({},'PRIVATE_METRICS_ENABLED',{get(){throw Error('private');}});
 const result=await traceOperation(brokenEnv,{service:'payment_allocation',operation:'payment_allocate'},async()=>{writes++;return 'committed';},
  {clock:()=>{throw Error('clock');},selectOutcome:()=>{throw Error('classification');},ctx:{waitUntil(){throw Error('context');}}});
 assert.equal(result,'committed');assert.equal(writes,1);assert.equal(await emitMetric(brokenEnv,operationMetric(input())),false);
});
test('mutating a queue metric after dispatch cannot alter the recorded projection',async()=>{
 const records=[],value={...queueMetric({service:'allocation_delivery',clubId:24,observedAt:NOW,state:'retry',count:1,oldestAt:null,capped:false})};
 const promise=emitMetric(env(v=>records.push(v)),value);value.state='phone-token';value.count=999999;await promise;
 assert.equal(records[0].metric.state,'retry');assert.equal(records[0].metric.count,1);assert.ok(Object.isFrozen(records[0].metric));
});
