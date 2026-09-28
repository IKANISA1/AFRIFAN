import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {fixture} from './support/fixture.mjs';
import {expireTransientSecrets} from '../src/delivery.mjs';
import {runIdentityMaintenance} from '../src/maintenance.mjs';
import {readDeliveryHealth} from '../src/delivery-health.mjs';
import {checkHealthConfiguration} from '../scripts/check-reliable-delivery.mjs';
import gateway from '../src/index.mjs';
const config=()=>JSON.parse(readFileSync(new URL('../wrangler.delivery-health.staging.jsonc',import.meta.url),'utf8'));
test('cleanup executes even when sender rejects and scheduled status remains failure',async()=>{
 const seen=[];await assert.rejects(runIdentityMaintenance({AUTH_SERVICE_ENABLED:'true'}, {
  drain:async()=>{seen.push('drain');throw Error('PRIVATE PHONE CODE');},expire:async()=>{seen.push('expiry');return {disabled:false};}
 }),e=>e.message==='identity_maintenance_incomplete');assert.deepEqual(seen.sort(),['drain','expiry']);
});
test('expiry rejection is not hidden by delivery success',async()=>{
 let called=false;await assert.rejects(runIdentityMaintenance({AUTH_SERVICE_ENABLED:'true'}, {
  drain:async()=>{called=true;return {};},expire:async()=>{throw Error('SQL TOKEN');}
 }),/identity_maintenance_incomplete/);assert.equal(called,true);
});
test('synchronous task exceptions do not suppress the other task',async()=>{
 let called=false;await assert.rejects(runIdentityMaintenance({AUTH_SERVICE_ENABLED:'true'}, {
  drain:()=>{called=true;return {};},expire:()=>{throw Error('SQL');}
 }));assert.equal(called,true);
});
test('disabled identity performs no maintenance',async()=>{
 const r=await runIdentityMaintenance({}, {drain:()=>assert.fail(),expire:()=>assert.fail()});assert.equal(r.disabled,true);
});
test('expired encrypted code is cleared while delivery is paused',async t=>{
 const f=fixture(t);await f.issue();f.clock.now+=700000;f.env.AUTH_DELIVERY_ENABLED='false';
 const r=await runIdentityMaintenance(f.env);assert.equal(r.delivery.disabled,true);assert.equal(f.sql('SELECT delivery_cipher FROM auth_challenges')[0].delivery_cipher,null);
});
test('scheduled entrypoint registers expiry task even with delivery paused',async t=>{
 const f=fixture(t);await f.issue();f.clock.now+=700000;f.env.AUTH_DELIVERY_ENABLED='false';const waits=[];
 await gateway.scheduled({},f.env,{waitUntil:p=>waits.push(p)});assert.equal(waits.length,1);await waits[0];assert.equal(f.sql('SELECT delivery_cipher FROM auth_challenges')[0].delivery_cipher,null);
});
test('health reader needs neither sender binding nor encryption/HMAC secrets',async t=>{
 const f=fixture(t);await f.issue();const env={AUTH_DB:f.db,AUTH_DELIVERY_HEALTH_ENABLED:'true',AUTH_DELIVERY_MODE:'private-deduplicated',AUTH_DELIVERY_POLICY_JSON:f.env.AUTH_DELIVERY_POLICY_JSON};
 const x=await readDeliveryHealth(env);assert.equal(x.ok,true);assert.equal(x.data.clubs[0].states.queued.count,1);
});
for(const value of [null,[],{clubId:26},{sql:'SELECT *'},{userId:'x'},{deliver:true}])test('health rejects caller-selected input '+JSON.stringify(value),async()=>{
 const r=await readDeliveryHealth({},value);assert.equal(r.ok,false);assert.equal(r.error.status,400);
});
test('health SQL/provider errors remain fixed private envelope',async t=>{
 const f=fixture(t);f.db.withSession=()=>{throw Error('SECRET');};assert.deepEqual(await readDeliveryHealth(f.env),{ok:false,error:{code:'delivery_health_unavailable',status:503}});
});
test('health configuration is disabled and has no sender or exposed HTTP',()=>{
 const c=config();assert.equal(checkHealthConfiguration(c).configuration,'disabled');assert.equal(c.services,undefined);assert.equal(c.routes.length,0);
});
for(const [label,edit] of [
 ['public ingress',c=>c.workers_dev=true],['preview',c=>c.preview_urls=true],['route',c=>c.routes.push('public.example/*')],
 ['sender binding',c=>c.services=[{binding:'OTP_DELIVERY'}]],['cron',c=>c.triggers={crons:['* * * * *']}],
 ['logs',c=>c.observability.enabled=true],['key',c=>c.vars.AUTH_ENCRYPTION_KEY='secret'],['wrong DB',c=>c.d1_databases[0].binding='PAYMENTS'],
 ['second DB',c=>c.d1_databases.push({...c.d1_databases[0]})]
])test('health config rejects '+label,()=>{const c=config();edit(c);assert.throws(()=>checkHealthConfiguration(c),/invalid_health_configuration/);});
test('ready configuration validation is shape only, never access acceptance',t=>{const f=fixture(t),c=config();c.account_id='a'.repeat(32);c.d1_databases[0].database_id=crypto.randomUUID();c.vars.AUTH_DELIVERY_HEALTH_ENABLED='true';c.vars.AUTH_DELIVERY_POLICY_JSON=f.env.AUTH_DELIVERY_POLICY_JSON;assert.equal(checkHealthConfiguration(c,{ready:true}).operatorAuthorizationVerified,false);});
test('aggregate state counts use covering tenant/state index',t=>{const f=fixture(t);const plan=f.sql("EXPLAIN QUERY PLAN SELECT COUNT(*) FROM(SELECT 1 FROM auth_challenges WHERE club_id=24 AND delivery_state='queued' LIMIT 1001)");assert.ok(plan.some(x=>x.detail.includes('auth_delivery_health_state')));});

test('secret expiry does not require decryption keys or a sender binding',async t=>{const f=fixture(t);await f.issue();f.clock.now+=700000;const env={AUTH_SERVICE_ENABLED:'true',AUTH_DB:f.db};await expireTransientSecrets(env);assert.equal(f.sql('SELECT delivery_cipher FROM auth_challenges')[0].delivery_cipher,null);});
test('secret expiry failure exposes no database diagnostic',async()=>{const db={prepare:()=>({}),batch:()=>{throw Error('PRIVATE SQL');}};await assert.rejects(expireTransientSecrets({AUTH_SERVICE_ENABLED:'true',AUTH_DB:db}),e=>e.message==='secret_expiry_unavailable');});
