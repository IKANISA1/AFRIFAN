import {test} from 'node:test';import assert from 'node:assert/strict';
import {fixture,PHONE,PHONE2,rejectsCode,rotating} from './support/fixture.mjs';
import {rotatedEnv,rotate,login,issue,verificationInput} from './support/key-rotation-fixture.mjs';
import {POLICY} from '../src/identity-service.mjs';
const CLUBS=[24,6,44,26,1001];
function clubs(f){f.db.sqlite.exec("INSERT INTO auth_clubs VALUES(6,'as_vita_fixture',1,1,'synthetic_auth',1),(44,'vitalo_fixture',1,1,'synthetic_auth',1),(1001,'costa_fixture',1,1,'synthetic_auth',1)");
 f.env.AUTH_ISSUANCE_POLICY_JSON=JSON.stringify({version:1,globalPerMinute:50,perIpPerMinute:10,phonePer15Minutes:3,clubs:Object.fromEntries(CLUBS.map(id=>[id,10]))});}
async function fiveSessions(f,s,phone){const sessions=[];for(const club of CLUBS){
 // Independent authorization setup, explicitly clearing fixture abuse counters.
 // Production budgets are separately tested and never changed by service code.
 f.db.sqlite.exec('DELETE FROM auth_rate_windows');sessions.push(await login(f,s,{phone,club}));}return sessions;}

test('all five configured club paths reject a token from every other club without revoking its owner',async t=>{
 const f=fixture(t);clubs(f);const s=await rotate(f,rotatedEnv(f)),sessions=await fiveSessions(f,s,PHONE);
 for(let i=0;i<CLUBS.length;i++)for(let j=0;j<CLUBS.length;j++)if(i!==j){const a=sessions[i];await rejectsCode(s.current(CLUBS[j],a.tokens.accessToken),'unauthenticated');await rejectsCode(s.refresh(CLUBS[j],{refreshToken:a.tokens.refreshToken},f.key()),'unauthenticated');}
 for(let i=0;i<CLUBS.length;i++)assert.equal((await s.current(CLUBS[i],sessions[i].tokens.accessToken)).userId,sessions[0].tokens.userId);
 assert.equal(f.sql('SELECT count(*) n FROM auth_sessions WHERE revoked_at_ms IS NOT NULL')[0].n,0);
});
test('revoking others spans all five clubs for one user and preserves all sessions of another user',async t=>{
 const f=fixture(t);clubs(f);const s=await rotate(f,rotatedEnv(f)),a=await fiveSessions(f,s,PHONE),b=await fiveSessions(f,s,PHONE2);
 await s.revoke(24,a[0].tokens.accessToken,{scope:'others'});await s.current(24,a[0].tokens.accessToken);
 for(let i=1;i<CLUBS.length;i++)await rejectsCode(s.current(CLUBS[i],a[i].tokens.accessToken),'unauthenticated');for(let i=0;i<CLUBS.length;i++)await s.current(CLUBS[i],b[i].tokens.accessToken);
 assert.equal(f.sql('SELECT count(*) n FROM auth_sessions WHERE revoked_at_ms IS NOT NULL')[0].n,4);
});
test('revoking all spans one canonical user across five clubs without affecting other users',async t=>{
 const f=fixture(t);clubs(f);const s=await rotate(f,rotatedEnv(f)),a=await fiveSessions(f,s,PHONE),b=await fiveSessions(f,s,PHONE2);
 await s.revoke(44,a[2].tokens.accessToken,{scope:'all'});for(let i=0;i<CLUBS.length;i++){await rejectsCode(s.current(CLUBS[i],a[i].tokens.accessToken),'unauthenticated');await s.current(CLUBS[i],b[i].tokens.accessToken);}
});
test('refresh reuse revokes exactly its token family across key versions',async t=>{
 const f=fixture(t),a=await f.login(),b=await f.login({club:26}),other=await f.login({phone:PHONE2}),key=f.key(),first=await f.service.refresh(24,{refreshToken:a.tokens.refreshToken},key),s=await rotate(f,rotatedEnv(f));
 await rejectsCode(s.refresh(26,{refreshToken:a.tokens.refreshToken},f.key()),'unauthenticated');await s.current(24,first.accessToken);
 await rejectsCode(s.refresh(24,{refreshToken:a.tokens.refreshToken},f.key()),'reauthentication_required');await rejectsCode(s.current(24,first.accessToken),'unauthenticated');
 await s.current(26,b.tokens.accessToken);await s.current(24,other.tokens.accessToken);assert.equal(f.sql('SELECT count(*) n FROM auth_sessions WHERE revoked_at_ms IS NOT NULL')[0].n,1);
});
test('combining another user session ID with the wrong credential cannot authenticate or revoke that user',async t=>{
 const f=fixture(t),a=await f.login(),b=await f.login({phone:PHONE2}),s=await rotate(f,rotatedEnv(f)),forged=`${b.tokens.sessionId}.${a.tokens.refreshToken.split('.')[1]}`;
 await rejectsCode(s.refresh(24,{refreshToken:forged},f.key()),'unauthenticated');await rejectsCode(s.current(24,`${b.tokens.sessionId}.${a.tokens.accessToken.split('.')[1]}`),'unauthenticated');
 await s.current(24,b.tokens.accessToken);assert.equal(f.sql('SELECT count(*) n FROM auth_sessions WHERE revoked_at_ms IS NOT NULL')[0].n,0);
});
test('rotation never renews recent-phone verification or revives superseded receipts',async t=>{
 const f=fixture(t),a=await f.login(),s=await rotate(f,rotatedEnv(f));f.clock.now+=POLICY.freshMs+1;const next=await s.refresh(24,{refreshToken:a.tokens.refreshToken},f.key());
 assert.equal(next.authenticatedAt,a.tokens.authenticatedAt);await rejectsCode(s.revoke(24,next.accessToken,{scope:'all'}),'recent_verification_required');
 await rejectsCode(s.verify(24,verificationInput(a.c),a.key),'reauthentication_required');
});
test('account epoch revocation is rechecked during the refreshed credential transaction under new keys',async t=>{
 const f=fixture(t),a=await f.login(),s=await rotate(f,rotatedEnv(f));f.setHook({when:rotating,before:()=>f.db.sqlite.exec("UPDATE auth_accounts SET status='suspended';UPDATE auth_accounts SET status='active'")});
 await assert.rejects(s.refresh(24,{refreshToken:a.tokens.refreshToken},f.key()));assert.equal(f.count('auth_refresh_receipts'),0);await rejectsCode(s.current(24,a.tokens.accessToken),'unauthenticated');
});
test('one club revision epoch invalidates only that club and cannot revive an old challenge',async t=>{
 const f=fixture(t),a=await f.login(),b=await f.login({club:26}),pending=await f.issue(),s=await rotate(f,rotatedEnv(f));
 f.db.sqlite.exec('UPDATE auth_clubs SET enabled=0 WHERE club_id=24;UPDATE auth_clubs SET enabled=1 WHERE club_id=24');
 await rejectsCode(s.current(24,a.tokens.accessToken),'unauthenticated');await rejectsCode(s.verify(24,verificationInput(pending),f.key()),'invalid_code');await s.current(26,b.tokens.accessToken);
});
test('key lifecycle database rows and aliases cannot be rewritten or deleted to revive old configurations',async t=>{
 const f=fixture(t);await f.account();await rotate(f,rotatedEnv(f));
 for(const sql of ["UPDATE auth_key_versions SET hmac_fingerprint='0'","DELETE FROM auth_key_versions","UPDATE auth_key_rotations SET retained_versions_json='[]'","DELETE FROM auth_key_rotations","UPDATE auth_phone_aliases SET key_version='9'","DELETE FROM auth_phone_aliases","UPDATE auth_settings SET key_version='1'"])
  assert.throws(()=>f.db.sqlite.exec(sql));
 assert.equal(f.sql('SELECT key_version FROM auth_settings')[0].key_version,'2');
});
