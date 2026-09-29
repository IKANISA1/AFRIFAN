import {test} from 'node:test';import assert from 'node:assert/strict';
import {createWebRouter} from '../src/index.mjs';
const origin='https://browser.example.invalid';
function fixture(){const api=[],next=[];const env={WEB_ROUTER_ENABLED:'true',WEB_ORIGIN:origin,
 BROWSER_API:{async fetch(r){api.push(r);return new Response('{}',{headers:{'content-type':'application/json','set-cookie':'__Host-a=1; Secure; Path=/'}});}},
 NEXT_APP:{async fetch(r){next.push(r);return new Response('site',{headers:{'cache-control':'public, max-age=999','cdn-cache-control':'public, max-age=999'}});}}};
 return {api,next,env,run:(path,init={})=>createWebRouter().fetch(new Request(origin+path,init),env)};}
test('browser API receives the original Request with its edge context',async()=>{const f=fixture(),request=new Request(origin+'/v1/browser/session');Object.defineProperty(request,'cf',{value:{colo:'TEST'}});
 const r=await createWebRouter().fetch(request,f.env);assert.equal(f.api[0],request);assert.equal(f.api[0].cf.colo,'TEST');assert.equal(f.next.length,0);assert.match(r.headers.get('cache-control'),/no-store/);});
test('browser Set-Cookie headers are preserved separately',async()=>{const f=fixture();f.env.BROWSER_API.fetch=async()=>{const h=new Headers({'content-type':'application/json'});h.append('set-cookie','__Host-a=1; Path=/; Secure; HttpOnly');h.append('set-cookie','__Host-b=2; Path=/; Secure; HttpOnly');return new Response('{}',{headers:h});};const r=await f.run('/v1/browser/session');assert.equal(r.headers.getSetCookie().length,2);});
test('forwarded host cannot turn the Next app into another tenant or admin host',async()=>{const f=fixture();await f.run('/membership',{headers:{'x-forwarded-host':'admin.evil.invalid',forwarded:'host=evil.invalid','x-original-host':'evil.invalid'}});const h=f.next[0].headers;assert.equal(h.get('host'),'browser.example.invalid');assert.equal(h.get('x-forwarded-host'),null);assert.equal(h.get('forwarded'),null);});
for(const path of ['/membership','/membership/renew','/operator/cases','/admin','/auth','/api/account','/supporters'])test('private app response is not CDN cacheable: '+path,async()=>{const f=fixture(),r=await f.run(path);assert.equal(await r.text(),'site');assert.equal(r.headers.get('cdn-cache-control'),'no-store');assert.match(r.headers.get('cache-control'),/private, no-store/);assert.match(r.headers.get('vary'),/Cookie/);});
for(const path of ['/v1/allocator','/v1/browser','/v1%2fbrowser/session'])test('unknown/encoded API cannot fall through to Next: '+path,async()=>{const f=fixture(),r=await f.run(path);assert.equal(r.status,404);assert.equal(f.next.length+f.api.length,0);});
test('wrong host is rejected without upstream calls',async()=>{const f=fixture(),r=await createWebRouter().fetch(new Request('https://other.invalid/membership'),f.env);assert.equal(r.status,404);assert.equal(f.next.length,0);});
test('disabled router does not invoke a backend',async()=>{const f=fixture();f.env.WEB_ROUTER_ENABLED='false';assert.equal((await f.run('/membership')).status,503);assert.equal(f.next.length,0);});
test('API failure is redacted and unknown POST is not retried',async()=>{const f=fixture();let n=0;f.env.BROWSER_API.fetch=async()=>{n++;throw Error('SECRET-DIAGNOSTIC');};const r=await f.run('/v1/browser/membership/checkouts',{method:'POST',body:'{}'});assert.equal(r.status,503);assert.deepEqual(await r.json(),{error:'service_unavailable',outcome:'unknown'});assert.equal(n,1);});
test('public content retains the Next app cache policy',async()=>{const f=fixture(),r=await f.run('/news');assert.equal(r.headers.get('cache-control'),'public, max-age=999');});

for(const path of ['/%6dembership','/membership%2frenew','/%256dembership','/%61dmin'])test('encoded application path cannot retain public cache policy: '+path,async()=>{
 const f=fixture(),r=await f.run(path);assert.equal(r.headers.get('cache-control'),'private, no-store');
 assert.equal(r.headers.get('cdn-cache-control'),'no-store');
});
for(const path of ['/v%31/browser/session','/%761/browser/session','/v1/browser/session%zz'])test('encoded or malformed API namespace never falls through: '+path,async()=>{
 const f=fixture(),r=await f.run(path);assert.equal(r.status,404);assert.equal(f.next.length+f.api.length,0);
});
test('stalled browser POST has one dispatch and an unknown bounded response',async()=>{
 const f=fixture();let calls=0;f.env.BROWSER_API.fetch=()=>{calls++;return new Promise(()=>{});};
 const r=await createWebRouter({rpcMs:15}).fetch(new Request(origin+'/v1/browser/membership/checkouts',{method:'POST',body:'{}'}),f.env);
 assert.equal(r.status,503);assert.deepEqual(await r.json(),{error:'service_unavailable',outcome:'unknown'});assert.equal(calls,1);
});
test('stalled Next read has a bounded private response without fallback or retry',async()=>{
 const f=fixture();let calls=0;f.env.NEXT_APP.fetch=()=>{calls++;return new Promise(()=>{});};
 const r=await createWebRouter({rpcMs:15}).fetch(new Request(origin+'/membership'),f.env);
 assert.equal(r.status,503);assert.equal(r.headers.get('cache-control'),'private, no-store');assert.equal(calls,1);
});
