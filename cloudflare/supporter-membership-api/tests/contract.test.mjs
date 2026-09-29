import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';import {fixture,json} from './fixture.mjs';
const spec=JSON.parse(readFileSync(new URL('../contracts/openapi.json',import.meta.url),'utf8'));
function shape(name,value){const s=spec.components.schemas[name];assert.deepEqual(Object.keys(value).sort(),[...s.required].sort());for(const [k,v] of Object.entries(value)){const p=s.properties[k];if('const'in p)assert.equal(v,p.const);if(p.type==='integer')assert.equal(Number.isSafeInteger(v),true);if(p.pattern)assert.match(v,new RegExp(p.pattern));}}
test('eleven explicitly authenticated operations and no financial mutation endpoint',()=>{assert.equal(spec.openapi,'3.1.0');assert.equal(Object.keys(spec.paths).length,11);for(const p of Object.values(spec.paths))for(const [method,op] of Object.entries(p))if(['get','post'].includes(method))assert.deepEqual(op.security??spec.security,[{SupporterBearer:[]}]);assert.equal(JSON.stringify(Object.keys(spec.paths)).includes('/allocate'),false);});
test('actual session, preparation and current response have exact documented fields',async t=>{const f=await fixture(t);shape('Session',await json(await f.call('session')));const p=await f.prepare();shape('Prepared',p);shape('CheckoutStatus',await json(await f.call(`membership/checkouts/${p.orderId}`)));});
test('actual historical receipt has documented minimized shape',async t=>{const f=await fixture(t),p=await f.prepare();await f.allocate(p.orderId);const r=await json(await f.call(`membership/checkouts/${p.orderId}/receipt`));shape('PaymentReceipt',r);shape('MembershipAtAllocation',r.membershipAtAllocation);assert.equal(r.historical,true);});
test('unknown invoked prepare has exact documented response',async t=>{const f=await fixture(t);f.env.CHECKOUT.prepare=async()=>{throw Error('failed');};shape('UnknownPrepareOutcome',await json(await f.call(),503));});

test('release endpoint is explicit POST with original key and no payment command',()=>{const p=spec.paths['/v1/supporter/clubs/{clubId}/membership/handoffs/releases'];assert.deepEqual(Object.keys(p),['post']);assert.ok(p.post.parameters.some(x=>x.$ref==='#/components/parameters/RequestKey'));assert.equal(spec.components.parameters.RequestKey.name.toLowerCase(),'idempotency-key');assert.equal(spec.components.parameters.RequestKey.required,true);assert.match(p.post.summary,/not a cancellation, refund/);});

test('history list and receipt routes are GET-only and retain native authentication',()=>{for (const tail of ['history','history/{orderId}']){const path=spec.paths['/v1/supporter/clubs/{clubId}/membership/'+tail]; assert.deepEqual(Object.keys(path),['get']);assert.deepEqual(path.get.security??spec.security,[{SupporterBearer:[]}]);}const list=spec.paths['/v1/supporter/clubs/{clubId}/membership/history'].get; assert.ok(list.parameters.some(p=>p.name==='X-Africlub-History-Cursor'||p.name==='x-africlub-history-cursor'||p.$ref==='#/components/parameters/HistoryCursor'));});

test('every owned read has a documented success schema and denied response schema',()=>{
 for(const [path,operations] of Object.entries(spec.paths))for(const [method,operation] of Object.entries(operations)){
  if(!['get','post'].includes(method))continue;
  assert.ok(operation.responses['200'].content?.['application/json'].schema,path);
  for(const status of ['401','503'])assert.ok(operation.responses[status]?.content?.['application/json'].schema,`${path}:${status}`);
 }
});
test('actual historical page and imported receipt have exact documented minimized shapes',async t=>{
 const f=await fixture(t),r=await f.allocate(f.payment.createOrder().order_id);
 const page=await json(await f.call('membership/history'));shape('MembershipHistoryPage',page);shape('MembershipHistoryItem',page.items[0]);
 const detail=await json(await f.call(`membership/history/${r.orderId}`));shape('HistoricalMembershipReceipt',detail);shape('PaymentReceipt',detail.receipt);
 assert.equal(spec.components.schemas.MembershipHistoryPage.properties.items.maxItems,20);
 for(const tail of ['history','history/{orderId}'])assert.ok(spec.paths['/v1/supporter/clubs/{clubId}/membership/'+tail].get.parameters.some(p=>p.$ref==='#/components/parameters/ExpectedSession'));
});
test('disabled handoff error is a documented sanitized error',async t=>{
 const f=await fixture(t),error=await json(await f.call('membership/handoffs/current'),503);
 shape('Error',error);assert.ok(spec.components.schemas.Error.properties.error.enum.includes(error.error));
 assert.ok(spec.components.schemas.Error.properties.error.enum.includes('handoff_unavailable'));
});
