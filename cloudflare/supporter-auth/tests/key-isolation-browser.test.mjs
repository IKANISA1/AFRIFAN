import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Worker} from 'node:worker_threads';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fixture,ORIGIN,PHONE,PHONE2} from '../../supporter-browser-api/tests/support/fixture.mjs';
import {Database,rejectsCode} from './support/fixture.mjs';
import {rotatedEnv,rotate,replaceEnv,rotationOptions,pause} from './support/key-rotation-fixture.mjs';
import {BrowserSessionService} from '../src/browser-session-service.mjs';
import {identityKeyRetirementReadiness,revokeRetiringBrowserCredentials} from '../src/key-rotation.mjs';

async function changed(f){const env=rotatedEnv(f);await rotate(f,env);replaceEnv(f,env);return env;}
const args=(f,s,key=f.key())=>({sessionCookie:s.sessionCookie,csrfToken:s.view.csrfToken,requestId:key});

test('old bootstrap and original browser login receipt survive retained key rotation',async t=>{
 const f=fixture(t),{b,c,s}=await f.browserLogin(),key=s.args.requestId;await changed(f);
 const oldView=await f.browser().bootstrapView(b.bootstrapCookie);assert.notEqual(oldView.csrfToken,b.view.csrfToken);
 const replay=await f.browser().verify({...s.args,requestId:key});assert.equal(replay.sessionCookie,s.sessionCookie);assert.equal(replay.view.authenticatedAt,s.view.authenticatedAt);
 assert.equal(f.count('auth_browser_sessions'),1);assert.equal(f.count('auth_accounts'),1);
 const current=await f.browser().current(s.sessionCookie);assert.equal(current.userId,s.view.userId);assert.equal(current.csrfToken,replay.view.csrfToken);
 await rejectsCode(f.browser().verify({...s.args,requestId:f.key()}),'idempotency_conflict');
 await rejectsCode(f.browser().verify({...s.args,input:{challengeId:c.challengeId,code:c.code==='000000'?'000001':'000000'}}),'idempotency_conflict');
});
test('original browser issuance retry survives key rotation without a second OTP',async t=>{
 const f=fixture(t),b=await f.start(),c=await f.challenge(b);await changed(f);
 const replay=await f.browser().challenge({bootstrapCookie:b.bootstrapCookie,csrfToken:b.view.csrfToken,requestId:c.key,ipKey:'c'.repeat(64),input:{phone:PHONE}});
 assert.equal(replay.challengeId,c.challengeId);assert.equal(f.count('auth_challenges'),1);
});
test('new browser rotation uses the current key while preserving original-cookie recovery',async t=>{
 const f=fixture(t),{s}=await f.browserLogin();await changed(f);const original=args(f,s),r=await f.browser().rotate(original);
 assert.equal(f.sql('SELECT cookie_key_version FROM auth_browser_sessions')[0].cookie_key_version,'2');assert.notEqual(r.sessionCookie,s.sessionCookie);
 assert.equal((await f.browser().rotate(original)).sessionCookie,r.sessionCookie);
 assert.equal((await f.browser().rotate({...original,sessionCookie:r.sessionCookie,csrfToken:r.view.csrfToken})).sessionCookie,r.sessionCookie);
 await rejectsCode(f.browser().current(s.sessionCookie),'unauthenticated');assert.equal(r.view.authenticatedAt,s.view.authenticatedAt);
});
test('pre-change rotation receipt recovers after ciphertext rewrap without rolling back a later generation',async t=>{
 const f=fixture(t),{s}=await f.browserLogin(),original=args(f,s),first=await f.browser().rotate(original);await changed(f);
 assert.equal((await f.browser().rotate(original)).sessionCookie,first.sessionCookie);
 const next=await f.browser().rotate(args(f,first));await rejectsCode(f.browser().rotate(original),'reauthentication_required');await f.browser().current(next.sessionCookie);
});
test('pre-change logout receipt accepts only its original cookie and operation after rotation',async t=>{
 const f=fixture(t),{s}=await f.browserLogin(),original=args(f,s),r=await f.browser().logout(original);await changed(f);
 assert.deepEqual(await f.browser().logout(original),r);await rejectsCode(f.browser().logout({...original,requestId:f.key()}),'unauthenticated');
 await rejectsCode(f.browser().current(s.sessionCookie),'unauthenticated');
});
test('cross-cookie CSRF remains rejected across old and current key versions',async t=>{
 const f=fixture(t),a=await f.browserLogin(),b=await f.browserLogin();await changed(f);const before=f.state();
 for(const [cookie,csrf] of [[a.s.sessionCookie,b.s.view.csrfToken],[b.s.sessionCookie,a.s.view.csrfToken]])await rejectsCode(f.browser().rotate({sessionCookie:cookie,csrfToken:csrf,requestId:f.key()}),'csrf_rejected');
 assert.deepEqual(f.state(),before);
});
test('other-origin and other-club services cannot read, rotate or replay a cookie',async t=>{
 const f=fixture(t),{b,s}=await f.browserLogin();await changed(f);
 const otherOrigin='https://other-browser.example.invalid';f.db.sqlite.prepare('INSERT INTO auth_browser_origins VALUES(?,?,?,?)').run(otherOrigin,26,1,1);
 const other=new BrowserSessionService({...f.env,BROWSER_ORIGIN:otherOrigin,BROWSER_CLUB_ID:'26'},{clock:()=>f.clock.now}),before=f.state();
 await rejectsCode(other.current(s.sessionCookie),'unauthenticated');await rejectsCode(other.rotate(args(f,s)),'unauthenticated');
 await rejectsCode(other.bootstrapView(b.bootstrapCookie),'bootstrap_required');assert.deepEqual(f.state(),before);await f.browser().current(s.sessionCookie);
});
test('cookie key-version tampering fails authentication',async t=>{
 const f=fixture(t),{s}=await f.browserLogin();await changed(f);f.db.sqlite.exec("UPDATE auth_browser_sessions SET cookie_key_version='2'");
 await rejectsCode(f.browser().current(s.sessionCookie),'unauthenticated');
});
test('suspended then restored accounts never revive browser cookies or original rotation receipts',async t=>{
 const f=fixture(t),{s}=await f.browserLogin();await changed(f);const original=args(f,s),r=await f.browser().rotate(original);
 f.db.sqlite.exec("UPDATE auth_accounts SET status='suspended';UPDATE auth_accounts SET status='active'");
 await rejectsCode(f.browser().current(r.sessionCookie),'unauthenticated');await rejectsCode(f.browser().rotate(original),'reauthentication_required');
});
test('retirement requires resolving live old-HMAC browser credentials and never silently recreates them',async t=>{
 const f=fixture(t),{s}=await f.browserLogin(),env=await changed(f);let r=await identityKeyRetirementReadiness(env,{retiringVersion:'1',clock:()=>f.clock.now});
 assert.equal(r.liveBrowserCredentials,1);assert.equal(r.retainedCiphertexts,0);assert.equal(r.retirementAllowed,false);
 f.clock.now+=900000;r=await identityKeyRetirementReadiness(env,{retiringVersion:'1',clock:()=>f.clock.now});assert.equal(r.deadlineReached,true);assert.equal(r.retirementAllowed,false);
 pause(f,env);replaceEnv(f,env);const outcome=await revokeRetiringBrowserCredentials(env,{retiringVersion:'1',confirmation:'REVOKE OLD BROWSER CREDENTIALS',evidence:'synthetic-retirement',clock:()=>f.clock.now});
 assert.equal(outcome.processed,1);assert.equal(outcome.complete,true);r=await identityKeyRetirementReadiness(env,{retiringVersion:'1',clock:()=>f.clock.now});assert.equal(r.retirementAllowed,true);
 assert.equal(f.count('auth_accounts'),1);assert.equal(f.count('auth_browser_sessions'),1);assert.notEqual(f.sql('SELECT revoked_ms FROM auth_browser_sessions')[0].revoked_ms,null);
 assert.equal((await revokeRetiringBrowserCredentials(env,{retiringVersion:'1',confirmation:'REVOKE OLD BROWSER CREDENTIALS',evidence:'synthetic-retirement',clock:()=>f.clock.now})).processed,0);
});
test('retirement revocation requires an explicit confirmation and paused controls',async t=>{
 const f=fixture(t);await f.browserLogin();const env=await changed(f),before=f.state();
 await rejectsCode(revokeRetiringBrowserCredentials(env,{retiringVersion:'1',confirmation:'yes',evidence:'synthetic',clock:()=>f.clock.now}),'invalid_key_retirement');
 await rejectsCode(revokeRetiringBrowserCredentials(env,{retiringVersion:'1',confirmation:'REVOKE OLD BROWSER CREDENTIALS',evidence:'synthetic',clock:()=>f.clock.now}),'key_rotation_requires_pause');assert.deepEqual(f.state(),before);
});
test('a credential rotated to the current key remains valid after old-key removal',async t=>{
 const f=fixture(t),{s}=await f.browserLogin(),env=await changed(f),r=await f.browser().rotate(args(f,s));f.clock.now+=900000;
 const p=JSON.parse(env.AUTH_KEY_POLICY_JSON);p.versions.shift();const ring=JSON.parse(env.AUTH_KEYRING_JSON);delete ring.keys['1'];
 replaceEnv(f,{...env,AUTH_KEY_POLICY_JSON:JSON.stringify(p),AUTH_KEYRING_JSON:JSON.stringify(ring)});const current=await f.browser().current(r.sessionCookie);
 assert.equal(current.userId,s.view.userId);assert.equal(current.authenticatedAt,s.view.authenticatedAt);assert.equal((await identityKeyRetirementReadiness(env,{retiringVersion:'1',clock:()=>f.clock.now})).retirementAllowed,true);
});
for(const scenario of ['same-key rotations','rotation versus logout'])test(`retained old cookie under current keys, independent SQLite connections: ${scenario}`,async t=>{
 const f=fixture(t),{s}=await f.browserLogin();await changed(f);const dir=mkdtempSync(join(tmpdir(),'africlub-key-cookie-race-')),file=join(dir,'identity.sqlite');t.after(()=>rmSync(dir,{recursive:true,force:true}));f.db.sqlite.prepare('VACUUM INTO ?').run(file);
 const barrier=new SharedArrayBuffer(4),flag=new Int32Array(barrier),workers=[],key=f.key();let ready=0;
 const env=Object.fromEntries(Object.entries(f.env).filter(([,v])=>typeof v==='string'));
 const jobs=[0,1].map(i=>new Promise((resolve,reject)=>{const w=new Worker(new URL('../../supporter-browser-api/tests/support/race-worker.mjs',import.meta.url),{workerData:{file,now:f.clock.now,barrier,env,
  method:scenario==='rotation versus logout'&&i===1?'logout':'rotate',args:args(f,s,scenario==='same-key rotations'?key:f.key())}});workers.push(w);
  w.on('message',m=>{if(m.ready&&++ready===2){Atomics.store(flag,0,1);Atomics.notify(flag,0);}if(m.done)resolve(m);});w.on('error',reject);}));
 t.after(async()=>Promise.all(workers.map(w=>w.terminate())));const results=await Promise.all(jobs),db=new Database(f.clock,{file,initialize:false});t.after(()=>db.sqlite.close());
 const service=new BrowserSessionService({...f.env,AUTH_DB:db},{clock:()=>f.clock.now});
 if(scenario==='same-key rotations'){assert.equal(results.filter(r=>r.ok).length,2);assert.equal(results[0].result.sessionCookie,results[1].result.sessionCookie);await service.current(results[0].result.sessionCookie);}
 else assert.equal(results.filter(r=>r.ok).length,1);
 await rejectsCode(service.current(s.sessionCookie),'unauthenticated');assert.equal(db.sqlite.prepare('SELECT count(*) n FROM auth_assertions').get().n,0);
});
