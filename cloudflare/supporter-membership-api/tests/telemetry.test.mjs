import test from 'node:test';
import assert from 'node:assert/strict';
import {fixture,json} from './fixture.mjs';

function metrics(env,record){
  Object.assign(env,{PRIVATE_METRICS_ENABLED:'true',PRIVATE_METRICS_RETENTION_MS:'3600000',
    PRIVATE_METRICS_POLICY_REF:'LOCAL_SYNTHETIC_TEST',PRIVATE_METRICS:{record}});
}
const flush=()=>new Promise(resolve=>setImmediate(resolve));

test('disabled native membership metrics make no sink call',async t=>{
  const f=await fixture(t);let calls=0;
  f.env.PRIVATE_METRICS={record(){calls++;}};
  await json(await f.call('session'));await flush();assert.equal(calls,0);
});

test('membership metric has generated trace and finite fields, never credentials or raw caller text',async t=>{
  const f=await fixture(t),seen=[];metrics(f.env,value=>{seen.push(value);});
  await json(await f.call('session',{headers:{'x-request-id':f.tokens.accessToken,
    traceparent:'synthetic-private-trace','x-debug-phone':'+250700000099'}}));
  await flush();assert.equal(seen.length,1);
  const {metric,retentionMs,policyRef}=seen[0];
  assert.deepEqual(Object.keys(metric).sort(),['schemaVersion','event','service','operation','traceId','clubId',
    'observedAt','durationMs','outcome'].sort());
  assert.equal(metric.service,'supporter_membership');assert.equal(metric.operation,'session_read');
  assert.equal(metric.clubId,24);assert.equal(metric.outcome,'completed');
  assert.match(metric.traceId,/^[0-9a-f-]{36}$/);assert.equal(retentionMs,3600000);
  assert.equal(policyRef,'LOCAL_SYNTHETIC_TEST');
  for(const privateValue of [f.tokens.accessToken,f.tokens.refreshToken,'+250700000099',
    'synthetic-private-trace',f.env.NATIVE_ORIGIN])assert.equal(JSON.stringify(seen).includes(privateValue),false);
});

for(const failure of ['throws','rejects','never settles']){
  test(`telemetry sink that ${failure} cannot repeat or prevent checkout`,async t=>{
    const f=await fixture(t);let attempts=0;
    metrics(f.env,()=>{attempts++;if(failure==='throws')throw Error('synthetic secret-bearing error');
      return failure==='rejects'?Promise.reject(Error('synthetic private error')):new Promise(()=>{});});
    const reply=await f.call();await json(reply);await flush();
    assert.equal(attempts,1);assert.equal(f.calls.filter(x=>x==='prepare').length,1);
    assert.equal(reply.headers.get('cache-control'),'no-store, private');
  });
}

test('unconfirmed mutation is traced unknown without request key or error details',async t=>{
  const f=await fixture(t),seen=[];metrics(f.env,value=>seen.push(value));
  f.env.CHECKOUT.prepare=async()=>{f.calls.push('prepare');throw Error('private upstream body');};
  const key=crypto.randomUUID();await json(await f.call(undefined,{key}),503);await flush();
  assert.equal(seen[0].metric.operation,'checkout_create');assert.equal(seen[0].metric.outcome,'unknown');
  assert.equal(f.calls.filter(x=>x==='prepare').length,1);
  assert.equal(JSON.stringify(seen).includes(key),false);
  assert.equal(JSON.stringify(seen).includes('private upstream body'),false);
});

test('rejected malformed route discloses no URL or query in metrics',async t=>{
  const f=await fixture(t),seen=[];metrics(f.env,value=>seen.push(value));
  await json(await f.call('session?secret=private-query'),404);await flush();
  assert.equal(seen[0].metric.operation,'route');assert.equal(seen[0].metric.clubId,null);
  assert.equal(seen[0].metric.outcome,'rejected');assert.equal(JSON.stringify(seen).includes('private-query'),false);
});
