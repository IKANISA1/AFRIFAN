import test from 'node:test';import assert from 'node:assert/strict';
import {fixture} from './fixture.mjs';import {drain} from '../src/dispatcher.mjs';
const metrics=(record)=>({PRIVATE_METRICS_ENABLED:'true',PRIVATE_METRICS_RETENTION_MS:'86400000',PRIVATE_METRICS_POLICY_REF:'SYNTHETIC_TEST_POLICY',PRIVATE_METRICS:{record}});
async function use(t,fn){const f=await fixture();t.after(()=>f.close());await fn(f);}
test('sink failure cannot alter the real inbox record or acknowledgment and metrics separate each configured club',t=>use(t,async f=>{
 const records=[];Object.assign(f.runner,metrics(v=>{records.push(v);throw Error('sink failed');}));
 assert.equal((await drain(f.runner)).stored,1);assert.equal((await drain(f.runner)).examined,0);await new Promise(resolve=>setTimeout(resolve,1));
 assert.equal(f.sinkDb.sql.prepare('SELECT count(*) n FROM adi_events').get().n,1);
 assert.ok(records.some(x=>x.metric.clubId===24&&x.metric.outcome==='completed'));assert.ok(records.some(x=>x.metric.clubId===25&&x.metric.outcome==='no_work'));
 for(const field of ['eventId','userId','orderId','providerReference','receiptId','phone','envelope'])assert.ok(!JSON.stringify(records).includes(field));
}));
test('lost source acknowledgment remains visibly unknown, with no metric-triggered retry or duplicate effect',t=>use(t,async f=>{
 const records=[];Object.assign(f.runner,metrics(v=>records.push(v)));let finishes=0;
 f.runner.SOURCE={take:x=>f.source.take(x),readForDispatch:x=>f.source.readForDispatch(x),finish:async x=>{finishes++;await f.source.finish(x);throw Error('lost ack');}};
 assert.equal((await drain(f.runner)).unknown,1);await new Promise(resolve=>setTimeout(resolve,1));assert.equal(finishes,1);
 assert.ok(records.some(x=>x.metric.clubId===24&&x.metric.outcome==='unknown'));assert.equal(f.sinkDb.sql.prepare('SELECT count(*) n FROM adi_events').get().n,1);
}));
test('health reports actual queue age and dead count without exposing event IDs',t=>use(t,async f=>{
 f.runner.INBOX={accept:async()=>{throw Error('unavailable');}};await drain(f.runner);f.advance(1000);await drain(f.runner);f.advance(2000);await drain(f.runner);
 const records=[];Object.assign(f.env,metrics(v=>records.push(v)));const health=await f.review.health({clubId:24});
 await new Promise(resolve=>setTimeout(resolve,5));assert.equal(health.counts.dead,1);
 const value=records.find(x=>x.metric.state==='dead');assert.ok(value);assert.equal(value.metric.oldestAgeMs,3000);assert.ok(!JSON.stringify(records).includes(f.receipt.allocationId));
}));
