import {test} from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';
import {validateTemplates} from '../scripts/check-deployment.mjs';
const load=()=>[JSON.parse(readFileSync(new URL('../wrangler.staging.jsonc',import.meta.url))),JSON.parse(readFileSync(new URL('../../supporter-auth/wrangler.browser-identity.staging.jsonc',import.meta.url)))];
test('all supplied browser templates are disabled and narrowly bound',()=>assert(validateTemplates(...load()).passed));
for(const [label,mutate] of [
 ['browser enabled',a=>a.vars.BROWSER_API_ENABLED='true'],['checkout enabled',a=>a.vars.BROWSER_CHECKOUT_ENABLED='true'],
 ['public route',a=>a.routes.push('example.invalid/*')],['worker.dev route',a=>a.workers_dev=true],
 ['raw secret',a=>a.vars.BROWSER_RATE_KEY='example'],['SQL exposed',a=>a.d1_databases=[{binding:'DB'}]],
 ['provider binding',a=>a.services.push({binding:'PROVIDER',entrypoint:'Send'})],
 ['duplicate binding',a=>a.services[1]={...a.services[0]}],['missing limiter',a=>a.ratelimits.pop()],
 ['live schedule',a=>a.triggers={crons:['* * * * *']}],['logging enabled',a=>a.observability.enabled=true]
])test('template check rejects '+label,()=>{const [a,b]=load();mutate(a);assert.throws(()=>validateTemplates(a,b));});
test('private identity entrypoint does not expose dynamic invoke or public HTTP authority',()=>{
 const text=readFileSync(new URL('../../supporter-auth/src/browser-identity-worker.mjs',import.meta.url),'utf8');
 assert(!text.includes(' async invoke('));assert(text.includes('fetch(){return hidden();}'));
 assert(text.includes('status:404'));
});
test('contract includes browser session, recovery and read-only owned history',()=>{
 const c=JSON.parse(readFileSync(new URL('../contracts/browser-v1.json',import.meta.url)));
 assert.equal(c.routes.length,15);assert.ok(c.routes.some(r=>r.method==='GET'&&r.path==='/v1/browser/membership/offers'));assert.equal(new Set(c.routes.map(r=>r.method+r.path)).size,15);
 for(const path of ['/v1/browser/membership/history','/v1/browser/membership/history/{orderId}']) {
  const routes=c.routes.filter(r=>r.path===path); assert.equal(routes.length,1); assert.equal(routes[0].method,'GET');
 }
 assert(c.routes.some(r=>r.path.endsWith('/operations/{requestId}')));assert.equal(c.notObserved.mayRetryWithNewKey,false);
});

for(const [label,mutate] of [
 ['gateway alternate main',a=>a.main='unreviewed.mjs'],
 ['identity alternate main',(_a,b)=>b.main='unreviewed.mjs'],
 ['gateway queue authority',a=>a.queues={producers:[{binding:'PROVIDER'}]}],
 ['identity durable objects',(_a,b)=>b.durable_objects={bindings:[{name:'PROVIDER'}]}],
 ['gateway extra var',a=>a.vars.PAYMENT_PROVIDER_ENABLED='true'],
 ['identity raw health credential',(_a,b)=>b.vars.HEALTH_DATABASE_PASSWORD='example'],
 ['identity health DB authority',(_a,b)=>b.d1_databases[0].binding='HEALTH_DB'],
 ['gateway alternate entrypoint',a=>a.services[0].entrypoint='SupporterIdentity'],
 ['identity cron hidden control',(_a,b)=>b.triggers.extra='unreviewed'],
 ['gateway live account',a=>a.account_id='1'.repeat(32)]
])test('browser template rejects unreviewed capability '+label,()=>{
 const [a,b]=load();mutate(a,b);assert.throws(()=>validateTemplates(a,b));
});
