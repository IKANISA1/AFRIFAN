import assert from 'node:assert/strict';
import test from 'node:test';
import {fixture, rejectsCode, PHONE} from './support/fixture.mjs';
import {issuancePolicy, issuanceWindows} from '../src/issuance-policy.mjs';
const policy = () => ({version:1, globalPerMinute:20, perIpPerMinute:10, phonePer15Minutes:3, clubs:{24:10,26:10}});
const config = value => JSON.stringify(value);
const bad = [undefined, null, '', '{', 'null', '[]', '{}', 'true', 123,
  config({...policy(),version:2}), config({...policy(),globalPerMinute:19}),
  config({...policy(),globalPerMinute:0}), config({...policy(),globalPerMinute:Infinity}),
  config({...policy(),globalPerMinute:20.5}), config({...policy(),extra:true}),
  config({...policy(),clubs:{}}),config({...policy(),clubs:{'024':1}}),
  config({...policy(),clubs:{'../24':1}}),config({...policy(),clubs:{24:-1}}),
  config({...policy(),clubs:{24:'10'}}),config({...policy(),phonePer15Minutes:4}),
  config({...policy(),perIpPerMinute:0})];
for (const [i, value] of bad.entries()) test(`issuance configuration rejects malformed/unsafe case ${i+1}`, () => {
  assert.throws(()=>issuancePolicy(value),e=>e.code==='issuance_policy_unconfigured'&&e.status===503);
});
test('policy is immutable and exact valid reservations are accepted',()=>{
 const p=issuancePolicy(config(policy()));assert.ok(Object.isFrozen(p)&&Object.isFrozen(p.clubs));assert.equal(p.clubs[24],10);
});
test('unsupported club does not borrow another tenant budget',()=>{
 assert.throws(()=>issuanceWindows({AUTH_ISSUANCE_POLICY_JSON:config(policy())},44,'c'.repeat(64),'d'.repeat(64)),e=>e.code==='issuance_policy_unconfigured');
});
test('one exhausted club does not starve a different club on the same shared IP',async t=>{
 const f=fixture(t); for(let n=0;n<10;n++)await f.issue({phone:'+25071000'+String(n).padStart(4,'0'),club:24});
 await rejectsCode(f.issue({phone:'+250710009999',club:24}),'rate_limited');
 const c=await f.issue({phone:'+250720000001',club:26});assert.equal(c.clubId,26);assert.equal(f.count('auth_challenges'),11);
 assert.equal(f.sql("SELECT count FROM auth_rate_windows WHERE rate_key='issue:global'")[0].count,11);
});
test('both tenants can consume only their own reserved allowance',async t=>{
 const f=fixture(t);for(const club of [24,26])for(let n=0;n<10;n++)await f.issue({club,phone:`+2507${club}${String(n).padStart(5,'0')}`});
 assert.equal(f.count('auth_challenges'),20);for(const club of [24,26])await rejectsCode(f.issue({club,phone:`+2507${club}99999`}),'rate_limited');
 assert.equal(f.sql("SELECT count FROM auth_rate_windows WHERE rate_key='issue:global'")[0].count,20);
});
test('phone anti-spam cap spans clubs and is not reset by tenant switching',async t=>{
 const f=fixture(t);await f.issue({club:24});await f.issue({club:26});await f.issue({club:24});
 await rejectsCode(f.issue({club:26}),'rate_limited');assert.equal(f.count('auth_challenges'),3);
});
test('policy absence blocks new challenge without any persistent side effect',async t=>{
 const f=fixture(t);delete f.env.AUTH_ISSUANCE_POLICY_JSON;await rejectsCode(f.issue(),'issuance_policy_unconfigured');
 assert.equal(f.count('auth_challenges'),0);assert.equal(f.count('auth_rate_windows'),0);
});
test('bad configured reservations do not invalidate existing verified sessions',async t=>{
 const f=fixture(t);const {tokens}=await f.login();delete f.env.AUTH_ISSUANCE_POLICY_JSON;
 assert.equal((await f.service.current(24,tokens.accessToken)).sessionId,tokens.sessionId);
});
test('same-key challenge recovery does not spend another reservation',async t=>{
 const f=fixture(t);const c=await f.issue();await f.issue({key:c.requestKey,secret:c.secret});
 assert.equal(f.sql("SELECT count FROM auth_rate_windows WHERE rate_key='issue:club:24'")[0].count,1);
});
test('new minute opens club allowance without resetting 15-minute phone protection',async t=>{
 const f=fixture(t);for(let n=0;n<10;n++)await f.issue({phone:'+25073000'+String(n).padStart(4,'0')});
 f.clock.now+=60001;await f.issue({phone:'+250730009999'});assert.equal(f.count('auth_challenges'),11);
});
