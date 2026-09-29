import {test} from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';import vm from 'node:vm';
const origin='https://browser.example.invalid';const source=readFileSync(new URL('../../../apps/rayon_sports/web/public/sw.js',import.meta.url),'utf8');
function fixture(){const handlers={},stores=new Map(),calls=[],writes=[];let offline=false;
 const caches={async keys(){return [...stores.keys()];},async delete(k){return stores.delete(k);},async open(k){if(!stores.has(k))stores.set(k,new Map());const m=stores.get(k);return {
  async match(r){return m.get(typeof r==='string'?r:r.url)?.clone();},async put(r,v){const key=typeof r==='string'?r:r.url;writes.push({cache:k,key});m.set(key,v.clone());},async addAll(){}};},
  async match(r){const key=typeof r==='string'?r:r.url;for(const m of stores.values())if(m.has(key))return m.get(key).clone();}};
 const context={URL,Request,Response,Headers,Set,Promise,console,caches,self:{location:{origin},clients:{claim:async()=>{}},navigator:{},addEventListener:(k,v)=>handlers[k]=v},
  fetch:async(r,init)=>{calls.push({url:typeof r==='string'?r:r.url,init});if(offline)throw Error('offline');return new Response('SYNTHETIC-NETWORK',{headers:{'cache-control':'public, max-age=60'}});}};
 vm.createContext(context);vm.runInContext(source,context);
 const run=async(path,{headers={},mode='cors',destination=''}={})=>{const request=new Request(origin+path,{headers});Object.defineProperties(request,{mode:{value:mode},destination:{value:destination}});let result;
  handlers.fetch({request,respondWith:p=>result=p});return result?await result:undefined;};
 return {context,handlers,stores,caches,calls,writes,run,setOffline:v=>offline=v};}
for(const path of ['/membership','/membership/renew','/auth/callback','/operator/cases','/v1/browser/session','/api/account','/%6dembership'])test('service worker never caches protected path '+path,async()=>{
 const f=fixture(),r=await f.run(path,{mode:'navigate'});assert.equal(await r.text(),'SYNTHETIC-NETWORK');assert.equal(f.writes.length,0);assert.equal(f.calls[0].init.cache,'no-store');});
for(const headers of [{authorization:'Bearer test'},{rsc:'1'},{'next-router-prefetch':'1'},{'next-action':'test'}])test('private/prefetch headers bypass public cache '+Object.keys(headers)[0],async()=>{
 const f=fixture();await f.run('/news',{headers,mode:'navigate'});assert.equal(f.writes.length,0);});
test('offline private navigation does not serve an old cached member document',async()=>{const f=fixture();const c=await f.caches.open('gikundiro-pages-v9');await c.put(new Request(origin+'/membership'),new Response('PRIVATE-OLD'));f.setOffline(true);const r=await f.run('/membership',{mode:'navigate'});assert.equal(r.status,503);assert(!(await r.text()).includes('PRIVATE-OLD'));});
test('offline private API does not return a cached success',async()=>{const f=fixture();f.setOffline(true);const r=await f.run('/v1/browser/session');assert.equal(r.status,503);assert.deepEqual(await r.json(),{error:'connection_required'});});
test('public periodic refresh excludes membership and every protected path',async()=>{const f=fixture();let wait;f.handlers.periodicsync({tag:'public-content-refresh',waitUntil:p=>wait=p});await wait;assert(f.calls.length>0);assert(f.calls.every(c=>!c.url.includes('/membership')));});
test('legacy mutation queues are neither replayed nor deleted',async()=>{const f=fixture();let wait;f.handlers.sync({tag:'admin-mutation-sync',waitUntil:p=>wait=p});await wait;assert.equal(f.calls.length,0);assert.equal(f.writes.length,0);});
test('protocol handshake purges only owned dynamic caches and preserves other storage',async()=>{const f=fixture();for(const k of ['gikundiro-pages-v8','gikundiro-api-v9','gikundiro-static-v9','another-app'])await f.caches.open(k);let wait,answer;
 f.handlers.message({data:{type:'AFRICLUB_PRIVATE_CACHE_CHECK'},source:{url:origin+'/membership'},ports:[{postMessage:v=>answer=v}],waitUntil:p=>wait=p});await wait;
 assert.equal(answer.protocol,'africlub-private-cache-v1');assert.equal(answer.purged,true);assert.deepEqual([...f.stores.keys()],['gikundiro-static-v9','another-app']);});
test('untrusted handshake cannot purge caches',async()=>{const f=fixture();await f.caches.open('gikundiro-pages-v9');f.handlers.message({data:{type:'AFRICLUB_PRIVATE_CACHE_CHECK'},source:{url:'https://evil.invalid'},ports:[],waitUntil(){throw Error('unexpected purge');}});assert(f.stores.has('gikundiro-pages-v9'));});
test('activation removes old owned caches but preserves unrelated caches',async()=>{const f=fixture();for(const k of ['gikundiro-assets-v8','gikundiro-static-v8','gikundiro-static-v9','unrelated'])await f.caches.open(k);let wait;f.handlers.activate({waitUntil:p=>wait=p});await wait;assert.deepEqual([...f.stores.keys()],['gikundiro-static-v9','unrelated']);});
test('ordinary public response remains cacheable when explicitly public',async()=>{const f=fixture();await f.run('/news',{mode:'navigate'});assert.equal(f.writes.length,1);});
test('public response without explicit public cache permission is not stored',async()=>{const f=fixture();f.context.fetch=async()=>new Response('dynamic');await f.run('/news',{mode:'navigate'});assert.equal(f.writes.length,0);});
test('Vary Cookie cannot be stored even with accidental public policy',async()=>{const f=fixture();f.context.fetch=async()=>new Response('dynamic',{headers:{vary:'Accept, Cookie','cache-control':'public'}});await f.run('/news',{mode:'navigate'});assert.equal(f.writes.length,0);});
