import {test} from 'node:test';
import assert from 'node:assert/strict';
import {fixture,PHONE2,creating,rotating,loggingOut,ORIGIN} from './support/fixture.mjs';
import {BrowserSessionService,expireBrowserSecrets} from '../../supporter-auth/src/browser-session-service.mjs';
const rejects=(p,code)=>assert.rejects(p,e=>e?.code===code);
const rotateArgs=(f,s,key=f.key())=>({sessionCookie:s.sessionCookie,csrfToken:s.view.csrfToken,requestId:key});

test('bootstrap is encrypted, time-bound and does not create an account or session',async t=>{
 const f=fixture(t),b=await f.start();assert.equal(f.count('auth_sessions'),0);assert.equal(f.count('auth_browser_sessions'),0);
 assert.equal(b.view.clubId,24);assert.equal(b.view.expiresAt,f.clock.now+600000);assert(!b.bootstrapCookie.includes('clientSecret'));
 assert.deepEqual(await f.browser().bootstrapView(b.bootstrapCookie),b.view);
});
test('OTP login returns cookie identity but no native access or refresh credentials',async t=>{
 const f=fixture(t),{s}=await f.browserLogin();assert.equal(s.sessionCookie.length,80);
 assert.equal(s.view.role,'supporter');assert.equal(s.view.phoneVerified,true);assert.equal(f.count('auth_accounts'),1);
 assert.equal(f.count('auth_browser_sessions'),1);assert.equal(f.count('auth_sessions'),1);
 assert(!JSON.stringify(s.view).match(/accessToken|refreshToken|phoneHash|code|cipher/i));
 assert.deepEqual(await f.browser().current(s.sessionCookie),s.view);
});
test('a live existing login must log out before starting another login',async t=>{
 const f=fixture(t),{s}=await f.browserLogin();await rejects(f.browser().start({sessionCookie:s.sessionCookie}),'already_authenticated');
});
test('expired login may start a fresh OTP bootstrap without reviving the old session',async t=>{
 const f=fixture(t),{s}=await f.browserLogin();f.clock.now=s.view.expiresAt;
 const b=await f.browser().start({sessionCookie:s.sessionCookie});assert(b.bootstrapCookie);
 await rejects(f.browser().current(s.sessionCookie),'unauthenticated');
});
test('bootstrap expires at the exact boundary',async t=>{
 const f=fixture(t),b=await f.start();f.clock.now=b.view.expiresAt;await rejects(f.browser().bootstrapView(b.bootstrapCookie),'bootstrap_required');
});
for(const variation of ['csrf','cipher','wrong-origin','wrong-club'])test(`bootstrap rejects ${variation}`,async t=>{
 const f=fixture(t),b=await f.start();
 if(variation==='wrong-origin'){f.env.BROWSER_ORIGIN='https://other.example.invalid';f.db.sqlite.exec("INSERT INTO auth_browser_origins VALUES('https://other.example.invalid',24,1,1)");}
 if(variation==='wrong-club'){f.env.BROWSER_CLUB_ID='26';f.db.sqlite.exec('UPDATE auth_browser_origins SET club_id=26');}
 await assert.rejects(f.browser().challenge({bootstrapCookie:variation==='cipher'?b.bootstrapCookie.slice(0,-2)+'xx':b.bootstrapCookie,
  csrfToken:variation==='csrf'?'0'.repeat(64):b.view.csrfToken,requestId:f.key(),ipKey:'c'.repeat(64),input:{phone:PHONE2}}));
 assert.equal(f.count('auth_challenges'),0);
});
test('one bootstrap binds one issuance key and exact phone; repeated issue is the same challenge',async t=>{
 const f=fixture(t),b=await f.start(),c=await f.challenge(b),d=await f.challenge(b,{key:c.key});assert.equal(d.challengeId,c.challengeId);
 await rejects(f.challenge(b,{key:f.key()}),'idempotency_conflict');
 await rejects(f.challenge(b,{key:c.key,phone:PHONE2}),'idempotency_conflict');assert.equal(f.count('auth_challenges'),1);
});
test('a challenge from a different bootstrap cannot be verified here',async t=>{
 const f=fixture(t),b=await f.start(),c=await f.challenge(b),other=await f.start();await f.challenge(other);
 await rejects(f.verify(other,c),'invalid_code');assert.equal(f.count('auth_browser_sessions'),0);
});
test('incorrect OTP cannot create browser access; corrected code remains possible',async t=>{
 const f=fixture(t),b=await f.start(),c=await f.challenge(b);await rejects(f.verify(b,c,{code:c.code==='000000'?'000001':'000000'}),'invalid_code');
 assert.equal(f.count('auth_browser_sessions'),0);await f.verify(b,c);assert.equal(f.count('auth_browser_sessions'),1);
});
test('consumed bootstrap cannot send a further code',async t=>{
 const f=fixture(t),{b,c}=await f.browserLogin();await rejects(f.challenge(b,{key:c.key}),'bootstrap_consumed');
});
test('login response loss recovers exact original cookie without another native session',async t=>{
 const f=fixture(t),b=await f.start(),c=await f.challenge(b),key=f.key();f.setHook({when:creating,after:true});
 const s=await f.verify(b,c,{key});f.clearHook();const r=await f.verify(b,c,{key});
 assert.equal(s.sessionCookie,r.sessionCookie);assert.equal(f.count('auth_sessions'),1);assert.equal(f.count('auth_browser_sessions'),1);
});
test('same login operation supports a cookie already set when only the response body was lost',async t=>{
 const f=fixture(t),{b,c,s}=await f.browserLogin();const r=await f.verify(b,c,{key:s.args.requestId,sessionCookie:s.sessionCookie});
 assert.equal(r.sessionCookie,s.sessionCookie);
});
test('changed login key or code cannot recover a cookie',async t=>{
 const f=fixture(t),{b,c,s}=await f.browserLogin();await rejects(f.verify(b,c),'idempotency_conflict');
 await rejects(f.verify(b,c,{key:s.args.requestId,code:c.code==='999999'?'999998':'999999'}),'idempotency_conflict');
});
test('parallel exact verification produces one browser and one native session',async t=>{
 const f=fixture(t),b=await f.start(),c=await f.challenge(b),key=f.key();const [a,z]=await Promise.all([f.verify(b,c,{key}),f.verify(b,c,{key})]);
 assert.equal(a.sessionCookie,z.sessionCookie);assert.equal(f.count('auth_browser_sessions'),1);assert.equal(f.count('auth_sessions'),1);
});
test('failed browser persistence can recover same already-verified native operation',async t=>{
 const f=fixture(t),b=await f.start(),c=await f.challenge(b),key=f.key();f.setHook({when:creating,failAt:1});
 await assert.rejects(f.verify(b,c,{key}));assert.equal(f.count('auth_browser_sessions'),0);assert.equal(f.count('auth_sessions'),1);
 f.clearHook();await f.verify(b,c,{key});assert.equal(f.count('auth_browser_sessions'),1);assert.equal(f.count('auth_sessions'),1);
});
test('browser and native access tokens are not interchangeable',async t=>{
 const f=fixture(t),{s}=await f.browserLogin();await rejects(f.service.current(24,s.sessionCookie),'unauthenticated');
 const native=await f.login();await rejects(f.browser().current(native.tokens.accessToken),'unauthenticated');
});
test('browser lifetime is explicit and independent of the five-minute native access token',async t=>{
 const f=fixture(t),{s}=await f.browserLogin();f.clock.now+=300001;await f.browser().current(s.sessionCookie);
 f.clock.now=s.view.expiresAt;await rejects(f.browser().current(s.sessionCookie),'unauthenticated');
});
for(const change of ["UPDATE auth_accounts SET status='suspended'","UPDATE auth_accounts SET status='deletion_pending'",
 "UPDATE auth_sessions SET revoked_at_ms=1","UPDATE auth_clubs SET enabled=0 WHERE club_id=24",
 "UPDATE auth_browser_origins SET enabled=0","UPDATE auth_browser_control SET enabled=0",
 "UPDATE auth_settings SET import_ready=0"])test(`session immediately denies after ${change.split(' SET')[0]+' '+change.split(' SET')[1]}`,async t=>{
 const f=fixture(t),{s}=await f.browserLogin();f.db.sqlite.exec(change);await assert.rejects(f.browser().current(s.sessionCookie));
});
test('disable/re-enable and origin reassignment do not revive old cookie epochs',async t=>{
 const f=fixture(t),{s}=await f.browserLogin();f.db.sqlite.exec('UPDATE auth_browser_control SET enabled=0;UPDATE auth_browser_control SET enabled=1');
 await rejects(f.browser().current(s.sessionCookie),'unauthenticated');
});
test('wrong origin denies the same cookie even when both origins serve this club',async t=>{
 const f=fixture(t),{s}=await f.browserLogin();f.env.BROWSER_ORIGIN='https://second.example.invalid';
 f.db.sqlite.exec("INSERT INTO auth_browser_origins VALUES('https://second.example.invalid',24,1,1)");
 await rejects(f.browser().current(s.sessionCookie),'unauthenticated');
});
test('atomic rotation replaces cookie and csrf; old cookie authorizes no reads',async t=>{
 const f=fixture(t),{s}=await f.browserLogin();const r=await f.browser().rotate(rotateArgs(f,s));
 assert.notEqual(r.sessionCookie,s.sessionCookie);assert.notEqual(r.view.csrfToken,s.view.csrfToken);
 assert.equal(r.view.sessionId,s.view.sessionId);await rejects(f.browser().current(s.sessionCookie),'unauthenticated');
 await f.browser().current(r.sessionCookie);assert.equal(f.count('auth_browser_rotations'),1);
});
test('same-key parallel rotation converges on one head and one retained outcome',async t=>{
 const f=fixture(t),{s}=await f.browserLogin(),args=rotateArgs(f,s);const [a,b]=await Promise.all([f.browser().rotate(args),f.browser().rotate(args)]);
 assert.deepEqual(a,b);assert.equal(f.count('auth_browser_rotations'),1);
});
test('different-key rotation race cannot both advance the original head',async t=>{
 const f=fixture(t),{s}=await f.browserLogin();const r=await Promise.allSettled([f.browser().rotate(rotateArgs(f,s)),f.browser().rotate(rotateArgs(f,s))]);
 assert.equal(r.filter(x=>x.status==='fulfilled').length,1);assert.equal(f.sql('SELECT generation FROM auth_browser_sessions')[0].generation,1);
});
test('rotation response loss recovers with the original cookie and original key',async t=>{
 const f=fixture(t),{s}=await f.browserLogin(),args=rotateArgs(f,s);f.setHook({when:rotating,after:true});
 const a=await f.browser().rotate(args);f.clearHook();assert.deepEqual(await f.browser().rotate(args),a);
});
test('rotation recovery accepts already-set new cookie with refreshed csrf and same key',async t=>{
 const f=fixture(t),{s}=await f.browserLogin(),args=rotateArgs(f,s),r=await f.browser().rotate(args);
 assert.deepEqual(await f.browser().rotate(rotateArgs(f,r,args.requestId)),r);assert.equal(f.count('auth_browser_rotations'),1);
});
test('wrong-key reuse of a retired cookie is denied without revoking the good head',async t=>{
 const f=fixture(t),{s}=await f.browserLogin(),r=await f.browser().rotate(rotateArgs(f,s));
 await rejects(f.browser().rotate(rotateArgs(f,s)),'unauthenticated');await f.browser().current(r.sessionCookie);
});
test('older rotation result cannot overwrite a newer generation',async t=>{
 const f=fixture(t),{s}=await f.browserLogin(),args=rotateArgs(f,s),a=await f.browser().rotate(args),b=await f.browser().rotate(rotateArgs(f,a));
 await rejects(f.browser().rotate(args),'reauthentication_required');await f.browser().current(b.sessionCookie);
});
test('rotation replay expires without killing the valid current cookie',async t=>{
 const f=fixture(t),{s}=await f.browserLogin(),args=rotateArgs(f,s),r=await f.browser().rotate(args);f.clock.now+=60001;
 await rejects(f.browser().rotate(args),'reauthentication_required');await f.browser().current(r.sessionCookie);
});
test('rotation extends idle expiry but never extends the original absolute deadline',async t=>{
 const f=fixture(t);f.db.sqlite.exec('UPDATE auth_browser_control SET idle_ms=60000,absolute_ms=120000');
 const {s}=await f.browserLogin();f.clock.now+=59000;const a=await f.browser().rotate(rotateArgs(f,s));
 assert.equal(a.view.expiresAt,s.view.authenticatedAt+119000);f.clock.now+=59000;
 const b=await f.browser().rotate(rotateArgs(f,a));assert.equal(b.view.expiresAt,s.view.absoluteExpiresAt);
 f.clock.now=s.view.absoluteExpiresAt;await rejects(f.browser().current(b.sessionCookie),'unauthenticated');
});
for(const change of ["UPDATE auth_accounts SET status='suspended'","UPDATE auth_browser_origins SET enabled=0","UPDATE auth_browser_control SET enabled=0"])
 test(`rotation SQL rechecks ${change} after asynchronous work`,async t=>{
  const f=fixture(t),{s}=await f.browserLogin();f.setHook({when:rotating,before:()=>f.db.sqlite.exec(change)});
  await assert.rejects(f.browser().rotate(rotateArgs(f,s)));assert.equal(f.count('auth_browser_rotations'),0);
 });
test('creation SQL rechecks identity before granting a cookie',async t=>{
 const f=fixture(t),b=await f.start(),c=await f.challenge(b);f.setHook({when:creating,before:()=>f.db.sqlite.exec("UPDATE auth_accounts SET status='suspended'")});
 await assert.rejects(f.verify(b,c));assert.equal(f.count('auth_browser_sessions'),0);
});
test('logout revokes linked identity session and is exact-key recoverable',async t=>{
 const f=fixture(t),{s}=await f.browserLogin(),args=rotateArgs(f,s);const a=await f.browser().logout(args);
 assert.equal(a.loggedOut,true);assert(f.sql('SELECT revoked_at_ms FROM auth_sessions')[0].revoked_at_ms);
 await rejects(f.browser().current(s.sessionCookie),'unauthenticated');assert.deepEqual(await f.browser().logout(args),a);
 await rejects(f.browser().logout(rotateArgs(f,s)),'unauthenticated');
});
test('logout response loss does not produce duplicate audit events',async t=>{
 const f=fixture(t),{s}=await f.browserLogin(),args=rotateArgs(f,s);f.setHook({when:loggingOut,after:true});
 await f.browser().logout(args);f.clearHook();await f.browser().logout(args);
 assert.equal(f.sql("SELECT count(*) AS n FROM auth_audit WHERE kind='browser_session_revoked'")[0].n,1);
});
test('expired cookie may still revoke its own session',async t=>{
 const f=fixture(t),{s}=await f.browserLogin();f.clock.now=s.view.expiresAt;
 assert.equal((await f.browser().logout(rotateArgs(f,s))).loggedOut,true);
});
test('logout does not revoke another session of the same user',async t=>{
 const f=fixture(t),{s}=await f.browserLogin(),other=await f.browserLogin();await f.browser().logout(rotateArgs(f,s));
 await f.browser().current(other.s.sessionCookie);
});
test('logout and rotation racing cannot both use the same credential; no valid old cookie',async t=>{
 const f=fixture(t),{s}=await f.browserLogin();const r=await Promise.allSettled([f.browser().rotate(rotateArgs(f,s)),f.browser().logout(rotateArgs(f,s))]);
 assert.equal(r.filter(x=>x.status==='fulfilled').length,1);await rejects(f.browser().current(s.sessionCookie),'unauthenticated');
});
test('logout and account revocation forbid replaying earlier rotation credentials',async t=>{
 const f=fixture(t),{s}=await f.browserLogin(),args=rotateArgs(f,s),r=await f.browser().rotate(args);
 await f.browser().logout(rotateArgs(f,r));await rejects(f.browser().rotate(args),'reauthentication_required');
});
for(const group of ['rotate','logout'])test(`${group} rollback is atomic at every statement position`,async t=>{
 const probe=fixture(t),p=await probe.browserLogin();await probe.browser()[group](rotateArgs(probe,p.s));const n=probe.db.lastBatch.length;
 for(let i=0;i<n;i++){
  const f=fixture(t),{s}=await f.browserLogin(),before=f.state();f.setHook({when:group==='rotate'?rotating:loggingOut,failAt:i});
  await assert.rejects(f.browser()[group](rotateArgs(f,s)));assert.deepEqual(f.state(),before,`${group} failure ${i}`);
  assert.equal(f.count('auth_assertions'),0);
 }
});
test('secret expiry runs without keys/login or deleting audit and operation metadata',async t=>{
 const f=fixture(t),{s}=await f.browserLogin(),args=rotateArgs(f,s);await f.browser().rotate(args);
 const original=f.count('auth_browser_rotations'),audits=f.count('auth_audit');f.clock.now+=60001;
 await expireBrowserSecrets(f.db);assert.equal(f.count('auth_browser_rotations'),original);assert.equal(f.count('auth_audit'),audits);
 assert.equal(f.sql('SELECT response_cipher FROM auth_browser_rotations')[0].response_cipher,null);
 assert.equal(f.sql('SELECT cookie_response_cipher FROM auth_browser_sessions')[0].cookie_response_cipher,null);
});
test('retained identities and revocation cannot be rewritten by ordinary SQL updates',async t=>{
 const f=fixture(t),{s}=await f.browserLogin();await f.browser().rotate(rotateArgs(f,s));
 assert.throws(()=>f.db.sqlite.exec('DELETE FROM auth_browser_rotations'));
 assert.throws(()=>f.db.sqlite.exec('UPDATE auth_browser_sessions SET absolute_ms=absolute_ms+1000'));
});
test('templates and origin control fail closed',async t=>{
 const f=fixture(t);f.env.AUTH_BROWSER_ENABLED='false';assert.throws(()=>f.browser());
 f.env.AUTH_BROWSER_ENABLED='true';f.db.sqlite.exec('UPDATE auth_browser_origins SET enabled=0');await rejects(f.browser().start(),'browser_disabled');
});
test('native signup and auth roles cannot be supplied in a browser challenge',async t=>{
 const f=fixture(t),b=await f.start();await rejects(f.browser().challenge({bootstrapCookie:b.bootstrapCookie,csrfToken:b.view.csrfToken,
  requestId:f.key(),ipKey:'c'.repeat(64),input:{phone:PHONE2,role:'admin'}}),'invalid_request');
});
