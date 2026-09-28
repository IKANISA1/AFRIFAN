import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {fixture,imported} from './support/fixture.mjs';
const spec=JSON.parse(readFileSync(new URL('../contracts/openapi.json',import.meta.url),'utf8'));
/** Bounded shape checker for this contract; not a general OpenAPI validator. */
function shape(schema,value) {
 if(schema.$ref)return shape(spec.components.schemas[schema.$ref.split('/').at(-1)],value);
 if(schema.oneOf){assert.equal(schema.oneOf.filter(s=>{try{shape(s,value);return true}catch{return false}}).length,1);return;}
 if(schema.const!==undefined)assert.equal(value,schema.const);
 if(schema.enum)assert.ok(schema.enum.includes(value));
 if(schema.type==='array'){assert.ok(Array.isArray(value));if(schema.maxItems!==undefined)assert.ok(value.length<=schema.maxItems);for(const item of value)shape(schema.items,item);}
 else if(schema.type==='object'){
  assert.ok(value&&typeof value==='object'&&!Array.isArray(value));
  for(const key of schema.required??[])assert.ok(Object.hasOwn(value,key),key);
  if(schema.additionalProperties===false)assert.ok(Object.keys(value).every(k=>Object.hasOwn(schema.properties,k)));
  for(const [key,v] of Object.entries(value))if(schema.properties[key])shape(schema.properties[key],v);
 } else if(schema.type==='integer'){assert.ok(Number.isSafeInteger(value));if(schema.minimum!==undefined)assert.ok(value>=schema.minimum);}
 else if(schema.type==='number'){assert.ok(typeof value==='number'&&Number.isFinite(value));}
 else if(schema.type==='null')assert.equal(value,null);
 else if(schema.type)assert.equal(typeof value,schema.type);
 if(schema.pattern)assert.match(value,new RegExp(schema.pattern));
 if(schema.format==='date-time')assert.ok(Number.isFinite(Date.parse(value)));
 if(schema.format==='uuid')assert.match(value,/^[a-f0-9]{8}-(?:[a-f0-9]{4}-){3}[a-f0-9]{12}$/);
}
test('all declared local schema references resolve',()=>{
 function walk(value){if(!value||typeof value!=='object')return;if(value.$ref)assert.ok(spec.components.schemas[value.$ref.split('/').at(-1)]);for(const v of Object.values(value))walk(v)}
 walk(spec);assert.equal(spec.openapi,'3.1.0');assert.equal(Object.keys(spec.paths).length,9);
});
test('actual head/review/publication/receipt responses match declared field shapes',async t=>{
 const f=fixture(t),s=await imported(f);shape(spec.components.schemas.HeadResponse,await(await f.call('head')).json());
 const r=await(await f.call('reviews',{body:{snapshotId:s.id,expectedPreviousId:null,reviewRef:'synthetic:contract'}})).json();shape(spec.components.schemas.ReviewResponse,r);
 const p=await(await f.call('publications',{body:{reviewId:r.data.reviewId},headers:{'idempotency-key':'contract_test_12345678'}})).json();shape(spec.components.schemas.PublicationResponse,p);
 shape(spec.components.schemas.PublicationResponse,await(await f.call(`publications/${p.data.operationId}`)).json());
});
test('error responses match declared nested request ID shape',async t=>{const f=fixture(t);shape(spec.components.schemas.Error,await(await f.call('head',{context:{}})).json());});

test('inspection and recovery HTTP responses match the extended contract',async t=>{
 const f=fixture(t),s=await imported(f);
 for(const [path,schema] of [['session','SessionResponse'],['candidates','CandidateListResponse'],[`candidates/${s.id}`,'CandidateResponse']])shape(spec.components.schemas[schema],await(await f.call(path)).json());
 const review=await f.review(s);shape(spec.components.schemas.ReviewStatusResponse,await(await f.call(`reviews/${review.reviewId}`)).json());
 for(const route of ['fixtures','news','squad','fanclubs','partners','shop','tickets','membership-tiers','predict-pools']){
  const res=await f.call(`candidates/${s.id}/preview/${route}`);assert.equal(res.status,200);shape(spec.components.schemas.PreviewResponse,await res.json());
 }
 await f.publish(review);shape(spec.components.schemas.ReviewStatusResponse,await(await f.call(`reviews/${review.reviewId}`)).json());
});
