import test from 'node:test';
import assert from 'node:assert/strict';
import { fixture, rejectsCode, PHONE } from './support/fixture.mjs';
import { IdentityService } from '../src/identity-service.mjs';
import { otpRatePolicy, issuanceWindows } from '../src/otp-rate-policy.mjs';
import { randomSecret } from '../src/crypto.mjs';

const phone = n => '+250700'+String(n).padStart(6,'0');
test('one club exhausting its quota does not consume another club quota',async t=>{
 const f=fixture(t);for(let i=0;i<10;i++)await f.issue({phone:phone(i)});
 await rejectsCode(f.issue({phone:phone(999)}),'rate_limited');
 const other=await f.issue({club:26,phone:phone(998)});assert.equal(other.clubId,26);
 assert.equal(f.sql("SELECT count FROM auth_rate_windows WHERE rate_key='issue:global'")[0].count,11);
});
test('all five approved clubs have a reserved issuance quota',async t=>{
 const f=fixture(t);for(const id of [6,44,1001]) f.db.sqlite.prepare('INSERT INTO auth_clubs(club_id,club_slug,enabled,allow_signup,auth_template) VALUES(?,?,1,1,?)').run(id,'test_'+id,'synthetic_auth');
 let number=0;
 for(const id of [6,24,26,44,1001])for(let i=0;i<10;i++){
   const r=await f.service.challenge(id,{phone:phone(number++),clientSecret:randomSecret()},f.key(),String(id).padStart(64,'a'));
   assert.equal(r.clubId,id);
 }
 assert.equal(f.count('auth_challenges'),50);
 await rejectsCode(f.issue({phone:phone(999)}),'rate_limited');
});
test('same-phone guessing and issuance budgets remain shared across clubs',async t=>{
 const f=fixture(t);await f.issue();await f.issue({club:26});await f.issue();
 await rejectsCode(f.issue({club:26}),'rate_limited');assert.equal(f.count('auth_challenges'),3);
});
test('duplicate request does not spend another quota slot',async t=>{
 const f=fixture(t),c=await f.issue();
 await f.service.challenge(24,{phone:PHONE,clientSecret:c.secret},c.requestKey,'c'.repeat(64));
 assert.equal(f.sql("SELECT count FROM auth_rate_windows WHERE rate_key='issue:club:24'")[0].count,1);
});
test('failed club quota rolls back increments to all other counters',async t=>{
 const f=fixture(t);for(let i=0;i<10;i++)await f.issue({phone:phone(i)});
 const before=f.sql('SELECT * FROM auth_rate_windows ORDER BY rate_key,window_start_ms');
 await rejectsCode(f.issue({phone:phone(999)}),'rate_limited');
 assert.deepEqual(f.sql('SELECT * FROM auth_rate_windows ORDER BY rate_key,window_start_ms'),before);
});
test('quota resets only on the original time window',async t=>{
 const f=fixture(t);for(let i=0;i<10;i++)await f.issue({phone:phone(i)});
 f.clock.now+=60_001;await f.issue({phone:phone(999)});assert.equal(f.count('auth_challenges'),11);
});
test('unapproved clubs fail before a challenge is persisted',async t=>{
 const f=fixture(t);f.db.sqlite.exec("INSERT INTO auth_clubs(club_id,club_slug,enabled,allow_signup,auth_template) VALUES(999,'test999',1,1,'synthetic_auth')");
 await rejectsCode(f.issue({club:999}),'club_not_available');assert.equal(f.count('auth_challenges'),0);
});
for(const bad of [null,[],{},'',false,'{',JSON.stringify({...otpRatePolicy(),globalPerMinute:49}),
 JSON.stringify({...otpRatePolicy(),clubs:[24,24]}),JSON.stringify({...otpRatePolicy(),clubs:[999]}),
 JSON.stringify({...otpRatePolicy(),perPhonePer15Minutes:4}),JSON.stringify({...otpRatePolicy(),perClubPerMinute:0}),
 JSON.stringify({...otpRatePolicy(),globalPerMinute:Infinity}),JSON.stringify({...otpRatePolicy(),extra:1})]){
 test('reject malformed/unfair policy '+JSON.stringify(bad),()=>assert.throws(()=>otpRatePolicy({AUTH_OTP_RATE_POLICY_JSON:bad}),e=>e.code==='otp_rate_policy_unconfigured'));
}
test('config changes cannot change identity of quota keys',()=>{
 const one=otpRatePolicy(),two=otpRatePolicy({AUTH_OTP_RATE_POLICY_JSON:JSON.stringify({...one,globalPerMinute:100,perClubPerMinute:20})});
 assert.deepEqual(issuanceWindows(one,24,'a'.repeat(64),'b'.repeat(64)).map(x=>x[0]),issuanceWindows(two,24,'a'.repeat(64),'b'.repeat(64)).map(x=>x[0]));
});
test('policy cannot be mutated after validation',()=>{
 const p=otpRatePolicy();assert.throws(()=>p.clubs.push(999));assert.throws(()=>p.globalPerMinute=999);
});
test('invalid hashes cannot inject arbitrary quota namespaces',()=>assert.throws(()=>issuanceWindows(otpRatePolicy(),24,'raw-phone','x')));
test('policy validation is applied by the actual service constructor',t=>{
 const f=fixture(t);assert.throws(()=>new IdentityService({...f.env,AUTH_OTP_RATE_POLICY_JSON:'{}'}),e=>e.status===503);
});

test('delivery drain interleaves tenants without expanding any club issuance quota',async t=>{
 const {dispatchOtp}=await import('../src/delivery.mjs');const f=fixture(t);
 for(let i=0;i<10;i++)await f.issue({phone:phone(i)});
 for(let i=10;i<20;i++)await f.issue({club:26,phone:phone(i)});
 const seen=[];
 const result=await dispatchOtp(f.env,{clock:()=>f.clock.now,sender:async(_env,p)=>{
   seen.push(p.clubId);return {accepted:true,messageId:'wamid.'+p.challengeId};
 }});
 assert.equal(result.accepted,20);assert.deepEqual(seen.slice(0,6),[24,26,24,26,24,26]);
 assert.equal(seen.filter(c=>c===24).length,10);assert.equal(seen.filter(c=>c===26).length,10);
});

test('forward index supports tenant-scoped delivery without enabling accounts',async t=>{
 const {readFileSync}=await import('node:fs');const f=fixture(t),before=f.sql('SELECT * FROM auth_clubs ORDER BY club_id');
 const sql=readFileSync(new URL('../migrations/0002_club_delivery_index.sql',import.meta.url),'utf8');f.db.sqlite.exec(sql);f.db.sqlite.exec(sql);
 const rows=f.sql("EXPLAIN QUERY PLAN SELECT challenge_id FROM auth_challenges WHERE club_id=24 AND state='open' AND delivery_cipher IS NOT NULL AND delivery_attempts<3 ORDER BY next_attempt_ms,challenge_id LIMIT 10");
 assert.ok(rows.some(r=>r.detail.includes('auth_club_delivery_due')));assert.deepEqual(f.sql('SELECT * FROM auth_clubs ORDER BY club_id'),before);
});
