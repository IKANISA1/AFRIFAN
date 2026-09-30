import {test} from 'node:test';import assert from 'node:assert/strict';
import {fixture,withPayments,PHONE,ORIGIN} from './support/fixture.mjs';
import {SESSION_COOKIE} from '../src/http.mjs';
import {createBrowserGateway} from '../src/index.mjs';
const TRACE='90000000-0000-4000-8000-000000000001';
function metrics(f,record){const records=[],waits=[];Object.assign(f.env,{PRIVATE_METRICS_ENABLED:'true',PRIVATE_METRICS_RETENTION_MS:'86400000',PRIVATE_METRICS_POLICY_REF:'SYNTHETIC_BROWSER_TEST',PRIVATE_METRICS:{record:record??(v=>records.push(v))}});
 return {records,waits,ctx:{waitUntil:p=>waits.push(p)},async settle(){await Promise.allSettled(waits);await new Promise(resolve=>setTimeout(resolve,0));}};}
async function call(f,m,path,{s,method='GET',body,key,headers={}}={}){const r=new Request(ORIGIN+path,{method,headers:{'x-africlub-browser-intent':'browser-v1','sec-fetch-site':'same-origin','cf-connecting-ip':'203.0.113.20',...(s?{cookie:`${SESSION_COOKIE}=${s.sessionCookie}`,'x-africlub-browser-session':s.view.sessionId}:{}),...(method==='POST'?{origin:ORIGIN,'content-type':'application/json','x-africlub-csrf':s?.view.csrfToken}:{}),...(key?{'idempotency-key':key}:{}),...headers},...(method==='POST'?{body:JSON.stringify(body??{})}:{})});Object.defineProperty(r,'cf',{value:{colo:'TEST'}});return createBrowserGateway({clock:()=>f.clock.now}).fetch(r,f.env,m.ctx);}
function privacy(records,values=[]){const raw=JSON.stringify(records);for(const v of [PHONE,'authorization','cookie','csrfToken','userId','sessionId','203.0.113.20',ORIGIN,...values])assert.equal(raw.includes(v),false);}

test('browser gateway emits one finite session-read metric without cookie or caller trace',async t=>{
 const f=fixture(t),{s}=await f.browserLogin(),m=metrics(f),r=await call(f,m,'/v1/browser/session',{s,headers:{'x-trace-id':TRACE,'x-request-id':s.args.requestId}});assert.equal(r.status,200);await m.settle();assert.equal(m.records.length,1);
 assert.equal(m.records[0].metric.service,'supporter_browser');assert.equal(m.records[0].metric.operation,'session_read');assert.equal(m.records[0].metric.clubId,24);assert.notEqual(m.records[0].metric.traceId,TRACE);privacy(m.records,[s.sessionCookie,s.view.csrfToken,s.view.userId,s.args.requestId]);
});
test('browser start and bootstrap labels do not claim an OTP was delivered',async t=>{
 const f=fixture(t),m=metrics(f),r=await call(f,m,'/v1/browser/session/start',{method:'POST'});assert.equal(r.status,200);await m.settle();assert.equal(m.records[0].metric.operation,'session_start');assert.equal(f.count('auth_challenges'),0);privacy(m.records);
});
test('malformed and denied browser ingress have bounded outcomes and no private URL',async t=>{
 const f=fixture(t),m=metrics(f);assert.equal((await call(f,m,'/v1/browser/session')).status,401);assert.equal((await call(f,m,'/private-phone-secret')).status,404);await m.settle();assert.deepEqual(m.records.map(v=>v.metric.outcome),['denied','rejected']);privacy(m.records,['private-phone-secret']);
});
test('unknown checkout response stays unknown and does not trigger another domain write',async t=>{
 const f=await withPayments(t),{s}=await f.browserLogin(),m=metrics(f);let writes=0;const actual=f.env.CHECKOUT.prepare;f.env.CHECKOUT.prepare=async v=>{writes++;await actual(v);throw Error('PRIVATE PAYMENT TOKEN');};
 const key=f.key(),r=await call(f,m,'/v1/browser/membership/checkouts',{s,method:'POST',body:{tier:'gold'},key});assert.equal(r.status,503);assert.equal((await r.json()).outcome,'unknown');await m.settle();assert.equal(writes,1);assert.equal(m.records.length,1);assert.equal(m.records[0].metric.operation,'checkout_create');assert.equal(m.records[0].metric.outcome,'unknown');privacy(m.records,[key,s.sessionCookie,s.view.userId,'PRIVATE PAYMENT TOKEN']);
});
for(const failure of ['throw','reject','hung'])test(`browser response is independent of a ${failure} metrics sink`,async t=>{
 const f=fixture(t),{s}=await f.browserLogin();let calls=0;const m=metrics(f,()=>{calls++;if(failure==='throw')throw Error('PRIVATE sink');if(failure==='reject')return Promise.reject(Error('PRIVATE sink'));return new Promise(()=>{});});
 const start=performance.now(),r=await call(f,m,'/v1/browser/session',{s});assert.equal(r.status,200);assert(performance.now()-start<500);await m.settle();assert.equal(calls,1);assert.equal(f.count('auth_browser_sessions'),1);
});
test('absent telemetry policy and throwing context cannot change browser identity',async t=>{
 const f=fixture(t),{s}=await f.browserLogin();let calls=0;const m=metrics(f,()=>{calls++;});delete f.env.PRIVATE_METRICS_RETENTION_MS;m.ctx.waitUntil=()=>{throw Error('PRIVATE context');};
 const r=await call(f,m,'/v1/browser/session',{s});assert.equal(r.status,200);await m.settle();assert.equal(calls,0);
});
