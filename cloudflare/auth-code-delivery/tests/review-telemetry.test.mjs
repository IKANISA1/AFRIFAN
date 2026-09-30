import test from 'node:test';import assert from 'node:assert/strict';
import {fixture} from './fixture.mjs';import {AuthenticationDispatchReview} from '../src/review.mjs';
const metrics=(record)=>({PRIVATE_METRICS_ENABLED:'true',PRIVATE_METRICS_RETENTION_MS:'86400000',PRIVATE_METRICS_POLICY_REF:'SYNTHETIC_TEST_POLICY',PRIVATE_METRICS:{record}});
function review(f,patch={}){
 const db={withSession(mode){assert.equal(mode,'first-primary');return this;},prepare(sql){return {args:[],bind(...args){return {...this,args};},
  async first(){return f.db.sql.prepare(sql).get(...this.args)??null;},async all(){return {results:f.db.sql.prepare(sql).all(...this.args)};}};}};
 return new AuthenticationDispatchReview({DELIVERY_DB:db,AUTH_DISPATCH_REVIEW_ENABLED:'true',AUTH_DISPATCH_REVIEW_ENVIRONMENT:'isolated-staging',AUTH_DISPATCH_REVIEW_CLUB_IDS:'[24]',...patch},{clock:f.now});
}
async function use(t,fn){const f=fixture();t.after(()=>f.close());await fn(f);}
test('actual dispatch completes once when the metrics sink rejects; no provider or request data appears in metrics',t=>use(t,async f=>{
 const records=[];Object.assign(f.env,metrics(v=>{records.push(v);throw Error('private sink');}));
 assert.equal((await f.service.deliver(f.input)).accepted,true);assert.equal((await f.service.deliver(f.input)).accepted,true);
 await new Promise(resolve=>setTimeout(resolve,1));assert.equal(f.calls.filter(x=>x.init.method==='POST').length,1);assert.equal(records.length,2);
 const encoded=JSON.stringify(records);for(const value of [f.input.phone,f.input.code,f.env.WA_ACCESS_TOKEN,'graph.facebook.com','challengeId','messageId','request_commitment'])assert.ok(!encoded.includes(value));
}));
test('reserved and unknown dispatch inspections never contact provider or authorize replay',t=>use(t,async f=>{
 f.override(async()=>{throw Error('synthetic unreachable');});assert.equal((await f.service.deliver(f.input)).accepted,false);
 const before=f.calls.length,r=review(f);const health=await r.health({clubId:24});assert.equal(health.counts.unknown,1);
 const page=await r.inspect({clubId:24,state:'unknown',afterChallengeId:null,limit:1});assert.equal(page.items[0].replayAllowed,false);assert.equal(page.replayAllowed,false);
 assert.equal(page.items[0].challengeId,f.input.challengeId);assert.ok(!JSON.stringify(page).includes(f.input.phone));assert.equal(f.calls.length,before);
 assert.ok(!('redrive' in r));assert.ok(!('deliver' in r));
}));
test('unknown backlog age and bounded aggregates emit no challenge or provider identifiers',t=>use(t,async f=>{
 f.override(async()=>{throw Error('synthetic unreachable');});await f.service.deliver(f.input);f.advance(5000);const records=[];
 const health=await review(f,metrics(v=>records.push(v))).health({clubId:24});await new Promise(resolve=>setTimeout(resolve,1));
 assert.equal(health.oldestAgeMs.unknown,5000);const queued=records.find(x=>x.metric.state==='unknown');assert.equal(queued.metric.oldestAgeMs,5000);
 assert.ok(!JSON.stringify(records).includes(f.input.challengeId));assert.ok(!JSON.stringify(records).includes(f.input.phone));
}));
for(const patch of [{AUTH_DISPATCH_REVIEW_ENABLED:'false'},{AUTH_DISPATCH_REVIEW_ENVIRONMENT:'production'},
 {AUTH_DISPATCH_REVIEW_CLUB_IDS:'[24,24]'},{AUTH_DISPATCH_REVIEW_CLUB_IDS:'[]'},{AUTH_DISPATCH_REVIEW_CLUB_IDS:'[1,2,3,4,5,6]'}])
 test(`review denies unsafe configuration ${Object.keys(patch)[0]}`,t=>use(t,async f=>assert.rejects(()=>review(f,patch).health({clubId:24}))));
test('review rejects cross-club, arbitrary selected state and extra private query fields',t=>use(t,async f=>{
 const r=review(f);await assert.rejects(()=>r.health({clubId:25}));await assert.rejects(()=>r.health({clubId:24,phone:'secret'}));
 await assert.rejects(()=>r.inspect({clubId:24,state:['unknown'],afterChallengeId:null,limit:1}));
}));
test('hung telemetry sink cannot change provider acceptance or cause a second post',t=>use(t,async f=>{
 let sinks=0;Object.assign(f.env,metrics(()=>{sinks++;return new Promise(()=>{});}));const start=performance.now();
 assert.equal((await f.service.deliver(f.input)).accepted,true);assert.ok(performance.now()-start<500);
 await new Promise(resolve=>setTimeout(resolve,30));assert.equal(sinks,1);assert.equal(f.calls.filter(x=>x.init.method==='POST').length,1);
}));
