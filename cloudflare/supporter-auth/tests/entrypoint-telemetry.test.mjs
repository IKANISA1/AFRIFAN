import {test} from 'node:test';import assert from 'node:assert/strict';
import gateway from '../src/index.mjs';
import {fixture,PHONE,USER} from './support/fixture.mjs';
import {fixture as browserFixture} from '../../supporter-browser-api/tests/support/fixture.mjs';
import {invokeNativeIdentityCurrent,invokeBrowserIdentity} from '../src/entrypoint-rpc.mjs';
import {observeIdentityMaintenance,rpcOutcome} from '../src/entrypoint-telemetry.mjs';
import {readDeliveryHealth} from '../src/delivery-health.mjs';
const TRACE='90000000-0000-4000-8000-000000000001';
function metrics(f,record){const records=[],waits=[];Object.assign(f.env,{PRIVATE_METRICS_ENABLED:'true',PRIVATE_METRICS_RETENTION_MS:'86400000',PRIVATE_METRICS_POLICY_REF:'SYNTHETIC_AUTH_TEST',PRIVATE_METRICS:{record:record??(v=>records.push(v))}});
 return {records,waits,ctx:{waitUntil:p=>waits.push(p)},async settle(){await Promise.allSettled(waits);await new Promise(resolve=>setTimeout(resolve,0));}};}
function request(f,suffix,{body,token,club=24,headers={}}={}){const r=new Request(`${f.env.AUTH_ORIGIN}/v1/auth/clubs/${club}/${suffix}`,{method:body?'POST':'GET',headers:{'x-africlub-client':'native-v1','cf-connecting-ip':'203.0.113.10',...(body?{'content-type':'application/json','idempotency-key':f.key()}:{}),...(token?{authorization:`Bearer ${token}`}:{}) ,...headers},...(body?{body:JSON.stringify(body)}:{})});Object.defineProperty(r,'cf',{value:{colo:'TEST'}});return r;}
function privateFieldsAbsent(records,values=[]){const raw=JSON.stringify(records);for(const value of [PHONE,USER,'accessToken','refreshToken','sessionId','csrfToken','authorization','cookie','203.0.113.10',...values])assert.equal(raw.includes(value),false);}

test('native HTTP observes exactly once without inbound trace authority or credential fields',async t=>{
 const f=fixture(t),a=await f.login(),m=metrics(f);const response=await gateway.fetch(request(f,'session',{token:a.tokens.accessToken,headers:{'x-trace-id':TRACE,'x-request-id':a.key}}),f.env,m.ctx);
 assert.equal(response.status,200);assert.equal((await response.json()).userId,a.tokens.userId);await m.settle();assert.equal(m.records.length,1);
 const value=m.records[0].metric;assert.equal(value.service,'supporter_auth');assert.equal(value.operation,'session_read');assert.equal(value.clubId,null);assert.equal(value.outcome,'completed');assert.notEqual(value.traceId,TRACE);
 privateFieldsAbsent(m.records,[a.tokens.accessToken,a.tokens.refreshToken,a.c.code,a.c.secret,a.key]);
});
test('untrusted native club path and route values never become telemetry identifiers',async t=>{
 const f=fixture(t),m=metrics(f),r=await gateway.fetch(request(f,'session',{club:700000001}),f.env,m.ctx);assert.equal(r.status,401);await m.settle();assert.equal(m.records[0].metric.clubId,null);
 privateFieldsAbsent(m.records,['700000001','https://identity.example.invalid']);
});
test('native denial and malformed routes have finite outcomes and no raw diagnostics',async t=>{
 const f=fixture(t),m=metrics(f);assert.equal((await gateway.fetch(request(f,'session'),f.env,m.ctx)).status,401);
 const r=new Request(`${f.env.AUTH_ORIGIN}/private/phone-and-secret`);assert.equal((await gateway.fetch(r,f.env,m.ctx)).status,404);await m.settle();
 assert.deepEqual(m.records.map(v=>[v.metric.operation,v.metric.outcome]),[['session_read','denied'],['route','rejected']]);privateFieldsAbsent(m.records,['phone-and-secret']);
});
test('native refresh reuse revokes its family once and the 401 observation remains unknown',async t=>{
 const f=fixture(t),a=await f.login(),m=metrics(f);await f.service.refresh(24,{refreshToken:a.tokens.refreshToken},f.key());
 const r=await gateway.fetch(request(f,'sessions/refresh',{body:{refreshToken:a.tokens.refreshToken}}),f.env,m.ctx);
 assert.equal(r.status,401);assert.equal((await r.json()).error,'reauthentication_required');await m.settle();
 assert.equal(f.sql("SELECT count(*) AS n FROM auth_audit WHERE kind='refresh_reuse_detected'")[0].n,1);
 assert.notEqual(f.sql('SELECT revoked_at_ms FROM auth_sessions')[0].revoked_at_ms,null);
 assert.equal(m.records.length,1);assert.equal(m.records[0].metric.outcome,'unknown');privateFieldsAbsent(m.records,[a.tokens.refreshToken]);
});
test('native lost acknowledgement after revoke keeps the original 503 and never repeats the commit',async t=>{
 const f=fixture(t),a=await f.login(),m=metrics(f);f.setHook({when:s=>s.some(v=>v.sql.includes('UPDATE auth_sessions SET revoked_at')),after:true});
 const r=await gateway.fetch(request(f,'sessions/revoke',{token:a.tokens.accessToken,body:{scope:'current'}}),f.env,m.ctx);
 assert.equal(r.status,503);assert.equal((await r.json()).error,'service_unavailable');await m.settle();
 assert.equal(f.sql("SELECT count(*) AS n FROM auth_audit WHERE kind='sessions_revoked_current'")[0].n,1);
 assert.equal(m.records.length,1);assert.equal(m.records[0].metric.outcome,'unknown');privateFieldsAbsent(m.records,[a.tokens.accessToken]);
});
for(const failure of ['throw','reject','hung'])test(`native response is independent of a ${failure} metrics sink`,async t=>{
 const f=fixture(t),a=await f.login();let calls=0;const m=metrics(f,()=>{calls++;if(failure==='throw')throw Error('PRIVATE SQL TOKEN');if(failure==='reject')return Promise.reject(Error('PRIVATE SQL TOKEN'));return new Promise(()=>{});});
 const start=performance.now(),r=await gateway.fetch(request(f,'session',{token:a.tokens.accessToken}),f.env,m.ctx);assert.equal(r.status,200);assert(performance.now()-start<500);await m.settle();assert.equal(calls,1);assert.equal(f.count('auth_sessions'),1);
});
test('disabled metrics and a broken context leave the exact HTTP result intact',async t=>{
 const f=fixture(t),a=await f.login();let sinks=0;metrics(f,()=>{sinks++;});delete f.env.PRIVATE_METRICS_ENABLED;
 const r=await gateway.fetch(request(f,'session',{token:a.tokens.accessToken}),f.env,{waitUntil(){throw Error('PRIVATE context');}});assert.equal(r.status,200);await new Promise(resolve=>setTimeout(resolve,0));assert.equal(sinks,0);
});
test('private verifier delegates one actual identity read and emits one projected result',async t=>{
 const f=fixture(t),a=await f.login(),m=metrics(f),value=await invokeNativeIdentityCurrent(f.env,{clubId:24,accessToken:a.tokens.accessToken},{clock:()=>f.clock.now,ctx:m.ctx});
 assert.equal(value.ok,true);assert.deepEqual(value.value,await f.service.current(24,a.tokens.accessToken));await m.settle();assert.equal(m.records.length,1);assert.equal(m.records[0].metric.clubId,null);privateFieldsAbsent(m.records,[a.tokens.accessToken,a.tokens.sessionId]);
});
test('private browser capability observes only one server-configured club and no cookie/CSRF',async t=>{
 const f=browserFixture(t),{s}=await f.browserLogin(),m=metrics(f),value=await invokeBrowserIdentity(f.env,'current',s.sessionCookie,{clock:()=>f.clock.now,ctx:m.ctx});
 assert.equal(value.ok,true);assert.deepEqual(value.value,await f.browser().current(s.sessionCookie));await m.settle();assert.equal(m.records.length,1);assert.equal(m.records[0].metric.clubId,24);privateFieldsAbsent(m.records,[s.sessionCookie,s.view.csrfToken,s.view.sessionId]);
});
test('unknown private method and bad credentials preserve sanitized errors without logging input',async t=>{
 const f=browserFixture(t),m=metrics(f);const value=await invokeBrowserIdentity(f.env,'private-phone-cookie','private-secret',{clock:()=>f.clock.now,ctx:m.ctx});
 assert.equal(value.ok,false);assert.equal(value.status,503);await m.settle();assert.equal(m.records.length,1);assert.equal(m.records[0].metric.operation,'route');privateFieldsAbsent(m.records,['private-phone-cookie','private-secret']);
});
test('private browser mutation denial retains its response and is conservatively unknown',async t=>{
 const f=browserFixture(t),{s}=await f.browserLogin(),m=metrics(f);
 const value=await invokeBrowserIdentity(f.env,'logout',{sessionCookie:s.sessionCookie,csrfToken:'private-wrong-csrf',requestId:f.key()},{clock:()=>f.clock.now,ctx:m.ctx});
 assert.equal(value.ok,false);assert.equal(value.status,403);await m.settle();assert.equal(m.records.length,1);
 assert.equal(m.records[0].metric.outcome,'unknown');assert.equal(f.sql('SELECT revoked_ms FROM auth_browser_sessions')[0].revoked_ms,null);privateFieldsAbsent(m.records,['private-wrong-csrf',s.sessionCookie]);
});
test('native scheduled maintenance registers work once and telemetry never repeats cleanup or delivery',async t=>{
 const f=fixture(t);await f.issue();f.clock.now+=700000;f.env.AUTH_DELIVERY_ENABLED='false';const m=metrics(f);
 await gateway.scheduled({},f.env,m.ctx);assert.equal(m.waits.length,1);await m.settle();assert.equal(f.sql('SELECT delivery_cipher FROM auth_challenges')[0].delivery_cipher,null);
 assert.equal(m.records.length,1);assert.equal(m.records[0].metric.operation,'identity_maintenance');privateFieldsAbsent(m.records);
});
test('disabled maintenance is recorded as no work without inventing a successful delivery',async()=>{
 const f={env:{AUTH_SERVICE_ENABLED:'false'}},m=metrics(f);await gateway.scheduled({},f.env,m.ctx);await m.settle();assert.equal(m.records.length,1);assert.equal(m.records[0].metric.outcome,'no_work');
});
test('maintenance preserves its original failure object while omitting private diagnostics',async()=>{
 const f={env:{}},m=metrics(f),error=Object.assign(Error('PRIVATE PHONE TOKEN'),{code:'identity_maintenance_incomplete'});let work=0;
 await assert.rejects(observeIdentityMaintenance(f.env,()=>{work++;throw error;},{ctx:m.ctx}),e=>e===error);await m.settle();assert.equal(work,1);assert.equal(m.records.length,1);privateFieldsAbsent(m.records,['PRIVATE PHONE TOKEN']);
});
test('health wrapper records one aggregate observation without requiring identity keys',async t=>{
 const f=fixture(t),m=metrics(f);delete f.env.AUTH_HMAC_KEY;delete f.env.AUTH_ENCRYPTION_KEY;
 const value=await observeIdentityMaintenance(f.env,()=>readDeliveryHealth(f.env),{ctx:m.ctx,operation:'queue_health',selectOutcome:rpcOutcome});assert.equal(value.ok,true);await m.settle();assert.equal(m.records.length,1);assert.equal(m.records[0].metric.operation,'queue_health');privateFieldsAbsent(m.records);
});
