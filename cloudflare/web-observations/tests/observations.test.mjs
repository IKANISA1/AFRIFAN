import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {VITAL_NAMES,PWA_EVENTS,normalizeObservation,projectWebVital,projectPwaEvent,
 parseObservationJson,observationConfiguration} from '../contracts.mjs';
import {handleWebObservation} from '../http.mjs';
import {PrivateWebObservationStore} from '../sink.mjs';
import {validate} from '../scripts/check-deployment.mjs';

const NOW=1790800000000,NOW_SQL="CAST(unixepoch('subsec') * 1000 AS INTEGER)";
const vital={schemaVersion:1,event:'web_vital',name:'LCP',value:1200,rating:'good'};
const pwa={schemaVersion:1,event:'pwa_event',eventType:'install-completed',surface:'site',displayMode:'standalone'};
function configuration(clubId=24){return {WEB_OBSERVATIONS_ENABLED:'true',WEB_OBSERVATIONS_STORE_ENABLED:'true',
 WEB_OBSERVATIONS_ENVIRONMENT:'isolated-staging',WEB_OBSERVATIONS_ORIGIN:'https://synthetic.invalid',
 WEB_OBSERVATIONS_CLUB_ID:String(clubId),WEB_OBSERVATIONS_RETENTION_MS:'3600000',
 WEB_OBSERVATIONS_POLICY_REF:'SYNTHETIC_TEST_POLICY'};}
function request(observation=vital,{headers={},body,event=observation.event}={}){
 return new Request('https://synthetic.invalid'+(event==='web_vital'?'/api/telemetry/vitals':'/api/pwa/events'),{
  method:'POST',headers:{origin:'https://synthetic.invalid','content-type':'application/json',...headers},
  body:body??JSON.stringify(observation)});
}
function fixture(t,clubId=24){
 const sql=new DatabaseSync(':memory:');let now=NOW;sql.function('test_now_ms',()=>now);
 sql.exec(readFileSync(new URL('../migrations/0001_private_web_observations.sql',import.meta.url),'utf8'));
 t.after(()=>sql.close());
 const db={prepare(raw){const query=raw.replaceAll(NOW_SQL,'test_now_ms()');return {args:[],
  bind(...args){return {...this,args};},async run(){return {meta:{changes:Number(sql.prepare(query).run(...this.args).changes)}};}};}};
 const env={...configuration(clubId),WEB_OBSERVATIONS_DB:db},store=new PrivateWebObservationStore(env);
 let calls=0;env.WEB_OBSERVATIONS={record(input){calls++;return store.record(input);}};
 return {sql,env,store,calls:()=>calls,count:()=>sql.prepare('SELECT count(*) n FROM private_web_observations').get().n,
  input:observation=>({observation,clubId,retentionMs:3600000,policyRef:'SYNTHETIC_TEST_POLICY'}),advance(ms){now+=ms;}};
}
test('projection never reads private identifiers, locations or DOM performance entries',()=>{
 const raw={name:'LCP',value:1234.567,rating:'good'};
 for(const key of ['id','navigationType','entries','path','phone','token'])
  Object.defineProperty(raw,key,{get(){throw Error('private property inspected');},enumerable:true});
 assert.deepEqual(projectWebVital(raw),{...vital,value:1230});
 const input={eventType:pwa.eventType,surface:pwa.surface,displayMode:pwa.displayMode};
 for(const key of ['path','payload','userId','userAgent'])Object.defineProperty(input,key,{get(){throw Error('private');}});
 assert.deepEqual(projectPwaEvent(input),pwa);
});
for(const patch of [{name:'private'}, {rating:'private'}, {value:NaN}, {value:Infinity},
 {value:-1},{value:600001},{name:'CLS',value:10.001}])
 test('invalid metric projection '+JSON.stringify(Object.keys(patch)),()=>assert.equal(projectWebVital({...vital,...patch}),null));
test('CLS is rounded independently from bounded time metrics',()=>{
 assert.equal(projectWebVital({...vital,name:'CLS',value:.123456}).value,.123);
 assert.equal(normalizeObservation({...vital,value:1234}),null);
});
for(const secret of ['phone','token','userId','user_agent','path','payload','id','navigationType'])
 test('server refuses extra observation field '+secret,()=>assert.equal(normalizeObservation({...vital,[secret]:'synthetic-private'}),null));
for(const raw of ['{"schemaVersion":1,"event":"web_vital","name":"LCP","name":"INP","value":1200,"rating":"good"}',
 '{"schemaVersion":1,"event":"web_vital","name":"LCP","n\\u0061me":"INP","value":1200,"rating":"good"}',
 'null','[]','"private"',JSON.stringify({...vital,payload:{note:'private'}})])
 test('strict observation JSON refuses duplicate, escaped duplicate or foreign structure '+raw.length,()=>{
  assert.equal(parseObservationJson(raw),null);
 });
test('finite JSON may vary key order and harmless whitespace',()=>{
 assert.deepEqual(parseObservationJson(JSON.stringify(vital,null,2)),vital);
 assert.deepEqual(parseObservationJson(JSON.stringify(pwa)),pwa);
});
for(const clubId of [6,24,26,44,1001])for(const name of VITAL_NAMES)
 test('actual SQLite ingress stores bounded '+clubId+'/'+name,async t=>{
 const f=fixture(t,clubId),observation={...vital,name,value:name==='CLS'?.1:1200};
 const response=await handleWebObservation(request(observation),f.env,'web_vital');
 assert.equal(response.status,201);assert.equal(response.headers.get('cache-control'),'no-store, private');
 assert.deepEqual(await response.json(),{schemaVersion:1,recorded:true});assert.equal(f.calls(),1);
 const row=f.sql.prepare('SELECT * FROM private_web_observations').get();
 assert.equal(row.club_id,clubId);assert.equal(row.expires_at_ms,NOW+3600000);
 assert.deepEqual(JSON.parse(row.observation_json),observation);
 assert.deepEqual(f.sql.prepare('PRAGMA foreign_key_check').all(),[]);
 assert.equal(f.sql.prepare('PRAGMA integrity_check').get().integrity_check,'ok');
});
for(const eventType of PWA_EVENTS)test('finite PWA event reaches only the private sink '+eventType,async t=>{
 const f=fixture(t),observation={...pwa,eventType};
 assert.equal((await handleWebObservation(request(observation),f.env,'pwa_event')).status,201);
 const row=f.sql.prepare('SELECT observation_json FROM private_web_observations').get();
 assert.deepEqual(JSON.parse(row.observation_json),observation);
 for(const key of ['user_id','user_agent','phone','path','payload','cookie','authorization'])
  assert.equal(row.observation_json.includes(key),false);
});
for(const headers of [{origin:'https://foreign.invalid','x-africlub-csrf':'1'},
 {'sec-fetch-site':'cross-site'},{authorization:'Bearer synthetic-private'},{cookie:'synthetic-private'},
 {'content-type':'text/plain'},{'content-encoding':'gzip'}])
 test('ingress refuses private/foreign transport '+Object.keys(headers)[0],async t=>{
 const f=fixture(t);const r=await handleWebObservation(request(vital,{headers}),f.env,'web_vital');
 assert.ok([403,415].includes(r.status));assert.equal(f.calls(),0);assert.equal(f.count(),0);
 assert.equal(JSON.stringify(await r.json()).includes('synthetic-private'),false);
});
test('server does not forward user agent, IP, inbound trace or session headers',async t=>{
 const f=fixture(t);const r=await handleWebObservation(request(vital,{headers:{
  'user-agent':'private-phone-model','cf-connecting-ip':'127.99.99.99',traceparent:'private-trace',
  'x-session-id':'private-session'}}),f.env,'web_vital');
 assert.equal(r.status,201);const row=f.sql.prepare('SELECT observation_json FROM private_web_observations').get();
 for(const word of ['private','127.99','session','trace','agent'])assert.equal(row.observation_json.includes(word),false);
});
test('a body that never arrives has a bounded read and is cancelled without storage',async t=>{
 const f=fixture(t);let cancelled=0;
 const body=new ReadableStream({cancel(){cancelled++;}});
 const r=new Request('https://synthetic.invalid/api/telemetry/vitals',{method:'POST',duplex:'half',
  headers:{origin:'https://synthetic.invalid','content-type':'application/json'},body});
 assert.equal((await handleWebObservation(r,f.env,'web_vital')).status,503);
 assert.equal(cancelled,1);assert.equal(f.calls(),0);
});
test('invalid UTF8 has no accepted observation or storage invocation',async t=>{
 const f=fixture(t),r=request(vital,{body:new Uint8Array([0xff])});
 assert.equal((await handleWebObservation(r,f.env,'web_vital')).status,400);assert.equal(f.calls(),0);
});
test('oversized, malformed, foreign-event and duplicate bodies never reach storage',async t=>{
 const f=fixture(t);
 for(const body of ['x'.repeat(1025),'{"bad":',JSON.stringify(pwa),
  JSON.stringify(vital).replace('"name":"LCP"','"name":"LCP","name":"INP"')]){
  const r=await handleWebObservation(request(vital,{body}),f.env,'web_vital');assert.equal(r.status,400);
 }
 assert.equal(f.calls(),0);assert.equal(f.count(),0);
});
for(const patch of [{WEB_OBSERVATIONS_ENABLED:'false'},{WEB_OBSERVATIONS_RETENTION_MS:''},
 {WEB_OBSERVATIONS_RETENTION_MS:'1'},{WEB_OBSERVATIONS_RETENTION_MS:'31622400001'},
 {WEB_OBSERVATIONS_POLICY_REF:'private/url'},{WEB_OBSERVATIONS_ORIGIN:'https://synthetic.invalid/path'},
 {WEB_OBSERVATIONS_CLUB_ID:'25'},{WEB_OBSERVATIONS_ENVIRONMENT:'production'}, {WEB_OBSERVATIONS:null}])
 test('unselected server configuration refuses all writes '+Object.keys(patch)[0],async t=>{
 const f=fixture(t);Object.assign(f.env,patch);
 assert.equal((await handleWebObservation(request(),f.env,'web_vital')).status,503);
 assert.equal(f.calls(),0);assert.equal(f.count(),0);
});
test('store independently denies mismatched club, retention, policy and sensitive envelopes',async t=>{
 const f=fixture(t);
 for(const patch of [{clubId:26},{retentionMs:86400000},{policyRef:'OTHER_POLICY'},{token:'private'},
  {observation:{...vital,id:'private'}}])await assert.rejects(()=>f.store.record({...f.input(vital),...patch}));
 assert.equal(f.count(),0);
 f.env.WEB_OBSERVATIONS_STORE_ENABLED='false';await assert.rejects(()=>f.store.record(f.input(vital)));
});
test('atomic volume quota retains exactly 300 observations and no client identifier',async t=>{
 const f=fixture(t);for(let i=0;i<300;i++)await f.store.record(f.input(vital));
 await assert.rejects(()=>f.store.record(f.input(vital)));assert.equal(f.count(),300);
 f.advance(60001);await f.store.record(f.input(vital));assert.equal(f.count(),301);
});
test('configured expiry is bounded and current observations are preserved',async t=>{
 const f=fixture(t);await f.store.record(f.input(vital));await f.store.record(f.input(pwa));
 f.advance(3600000);await f.store.record(f.input(vital));
 assert.deepEqual(await f.store.expire({limit:1}),{schemaVersion:1,removed:1});
 assert.equal(f.count(),2);assert.deepEqual(await f.store.expire({limit:1000}),{schemaVersion:1,removed:1});
 assert.equal(f.count(),1);await assert.rejects(()=>f.store.expire({limit:1001}));
 assert.throws(()=>f.sql.exec("UPDATE private_web_observations SET club_id=26"));
});
for(const acknowledgement of [null,{recorded:true},{schemaVersion:1,recorded:true,token:'private'}])
 test('invalid private acknowledgement cannot claim recorded '+JSON.stringify(acknowledgement),async t=>{
 const f=fixture(t);let calls=0;f.env.WEB_OBSERVATIONS.record=async()=>{calls++;return acknowledgement;};
 assert.equal((await handleWebObservation(request(),f.env,'web_vital')).status,503);assert.equal(calls,1);
});
test('a lost sink acknowledgement may commit once later and cannot trigger a second invocation',async t=>{
 const f=fixture(t);let release;const lost=new Promise(resolve=>{release=resolve;});let calls=0;
 f.env.WEB_OBSERVATIONS.record=async input=>{calls++;await lost;return f.store.record(input);};
 assert.equal((await handleWebObservation(request(),f.env,'web_vital')).status,503);
 assert.equal(calls,1);assert.equal(f.count(),0);release();await new Promise(resolve=>setTimeout(resolve,10));
 assert.equal(f.count(),1);assert.equal(calls,1);
});
test('disabled templates declare no public routes, automatic logging or provider capability',()=>{
 const config=JSON.parse(readFileSync(new URL('../wrangler.staging.jsonc',import.meta.url),'utf8'));
 assert.deepEqual(validate(config),[]);
 for(const patch of [{services:[]},{observability:{enabled:true}},{routes:[{pattern:'unsafe.invalid'}]},
  {vars:{...config.vars,WEB_OBSERVATIONS_STORE_ENABLED:'true'}}])assert.ok(validate({...config,...patch}).length);
 assert.equal(observationConfiguration(configuration()).clubId,24);
});
