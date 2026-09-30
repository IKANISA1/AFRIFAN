import test from 'node:test';import assert from 'node:assert/strict';import {DatabaseSync} from 'node:sqlite';import {readFileSync} from 'node:fs';
import {PrivateMetricsStore} from '../sink.mjs';import {operationMetric,queueMetric,emitMetric} from '../telemetry.mjs';
import {validate} from '../scripts/check-deployment.mjs';
const NOW=Date.UTC(2026,8,30),traceId='90000000-0000-4000-8000-000000000001',NOW_SQL="CAST(unixepoch('subsec') * 1000 AS INTEGER)";
function fixture(t){
 const sql=new DatabaseSync(':memory:');let time=NOW;sql.function('test_now_ms',()=>time);sql.exec(readFileSync(new URL('../migrations/0001_private_metrics.sql',import.meta.url),'utf8'));t.after(()=>sql.close());
 const db={withSession(mode){assert.equal(mode,'first-primary');return this;},prepare(raw){const query=raw.replaceAll(NOW_SQL,'test_now_ms()');return {args:[],bind(...args){return {...this,args};},async first(){return sql.prepare(query).get(...this.args);},async all(){return {results:sql.prepare(query).all(...this.args)};},async run(){return {meta:{changes:Number(sql.prepare(query).run(...this.args).changes)}};}};}};
 const env={PRIVATE_METRICS_STORE_ENABLED:'true',PRIVATE_METRICS_ENVIRONMENT:'isolated-staging',PRIVATE_METRICS_RETENTION_MS:'3600000',PRIVATE_METRICS_POLICY_REF:'SYNTHETIC_TEST_POLICY',METRICS_DB:db};
 const store=new PrivateMetricsStore(env),producer={PRIVATE_METRICS_ENABLED:'true',PRIVATE_METRICS_RETENTION_MS:env.PRIVATE_METRICS_RETENTION_MS,PRIVATE_METRICS_POLICY_REF:env.PRIVATE_METRICS_POLICY_REF,PRIVATE_METRICS:store};
 const metric=operationMetric({service:'auth_code_delivery',operation:'credential_delivery',traceId,clubId:24,observedAt:NOW,durationMs:5,outcome:'unknown'});
 return {sql,env,store,producer,metric,input:{metric,retentionMs:3600000,policyRef:'SYNTHETIC_TEST_POLICY'},advance(ms){time+=ms;}};
}
test('actual SQLite sink stores only the bounded projection with configured expiry and private readback',async t=>{
 const f=fixture(t);assert.equal(await emitMetric(f.producer,f.metric),true);const row=f.sql.prepare('SELECT * FROM private_metrics').get();assert.equal(row.expires_at_ms,NOW+3600000);
 assert.deepEqual(JSON.parse(row.metric_json),f.metric);assert.deepEqual((await f.store.readTrace({traceId,limit:1})).items,[f.metric]);
 assert.deepEqual(f.sql.prepare('PRAGMA foreign_key_check').all(),[]);assert.equal(f.sql.prepare('PRAGMA integrity_check').get().integrity_check,'ok');
});
for(const patch of [{retentionMs:1},{retentionMs:31622400001},{policyRef:'DIFFERENT_POLICY'},{phone:'private'},{metric:{token:'private'}}])
 test(`sink rejects unapproved or sensitive input ${Object.keys(patch)[0]}`,async t=>{const f=fixture(t);await assert.rejects(()=>f.store.record({...f.input,...patch}));assert.equal(f.sql.prepare('SELECT count(*) n FROM private_metrics').get().n,0);});
for(const patch of [{PRIVATE_METRICS_STORE_ENABLED:'false'},{PRIVATE_METRICS_ENVIRONMENT:'production'},{PRIVATE_METRICS_RETENTION_MS:''},{PRIVATE_METRICS_POLICY_REF:''}])
 test(`sink requires explicit configured ${Object.keys(patch)[0]}`,async t=>{const f=fixture(t);Object.assign(f.env,patch);await assert.rejects(()=>f.store.record(f.input));assert.equal(f.sql.prepare('SELECT count(*) n FROM private_metrics').get().n,0);});
test('expired traces are absent from reads; explicit expiry removes only bounded expired observations',async t=>{
 const f=fixture(t);await f.store.record(f.input);await f.store.record(f.input);f.advance(3600000);
 assert.deepEqual((await f.store.readTrace({traceId,limit:1})).items,[]);assert.equal((await f.store.expire({limit:1})).removed,1);assert.equal(f.sql.prepare('SELECT count(*) n FROM private_metrics').get().n,1);
 await f.store.record({...f.input,metric:{...f.metric,observedAt:NOW+3600000}});assert.equal((await f.store.expire({limit:1000})).removed,1);assert.equal(f.sql.prepare('SELECT count(*) n FROM private_metrics').get().n,1);
});
test('future/stale timestamps, extra trace fields and unbounded expiry requests are refused',async t=>{
 const f=fixture(t);for(const observedAt of [NOW+5001,NOW-86400001])await assert.rejects(()=>f.store.record({...f.input,metric:{...f.metric,observedAt}}));
 await assert.rejects(()=>f.store.readTrace({traceId,limit:51}));await assert.rejects(()=>f.store.readTrace({traceId,limit:1,token:'private'}));await assert.rejects(()=>f.store.expire({limit:1001}));
});
test('immutable stored observations reject correction; queue aggregate records contain no object identifiers',async t=>{
 const f=fixture(t),metric=queueMetric({service:'allocation_delivery',clubId:24,observedAt:NOW,state:'dead',count:1,oldestAt:NOW-1000,capped:false});
 await f.store.record({...f.input,metric});assert.throws(()=>f.sql.exec("UPDATE private_metrics SET service='supporter_auth'"));
 const row=f.sql.prepare('SELECT metric_json FROM private_metrics').get();for(const name of ['eventId','userId','orderId','phone','token'])assert.ok(!row.metric_json.includes(name));
});
test('sink configuration has no HTTP route, schedule, producer domain database or provider credential',()=>{
 const config=JSON.parse(readFileSync(new URL('../wrangler.staging.jsonc',import.meta.url),'utf8'));
 assert.equal(config.workers_dev,false);assert.equal(config.preview_urls,false);assert.deepEqual(config.routes,[]);assert.equal(config.observability.enabled,false);
 assert.equal(config.d1_databases.length,1);assert.equal(config.d1_databases[0].binding,'METRICS_DB');assert.equal(config.vars.PRIVATE_METRICS_STORE_ENABLED,'false');
 assert.ok(!config.services&&!config.queues&&!config.triggers);assert.ok(!JSON.stringify(config).includes('WA_ACCESS_TOKEN'));
 assert.deepEqual(validate(config),[]);for(const patch of [{unsafe:{bindings:[]}},{services:[]},{tail_consumers:[]}])assert.ok(validate({...config,...patch}).includes('unknown_configuration_field'));
});
