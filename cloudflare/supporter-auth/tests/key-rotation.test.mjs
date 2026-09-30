import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fixture,PHONE,PHONE2,USER,rejectsCode } from './support/fixture.mjs';
import { Vault, KEY_RETENTION, randomSecret, publicKeyPolicy } from '../src/crypto.mjs';
import { IdentityService, POLICY } from '../src/identity-service.mjs';
import { prepareIdentityKeyRotation, activateIdentityKeyRotation, identityKeyRetirementReadiness, registerInitialIdentityKeys } from '../src/key-rotation.mjs';

import { rotatedEnv as envFor, rotate, pause, rotationOptions, issue, login, verificationInput as input } from './support/key-rotation-fixture.mjs';

test('current writes and retained reads bind AES ciphertext to the key version',async t=>{
 const f=fixture(t),old=await f.service.vault.seal({marker:'synthetic'},'scope'),env=envFor(f),v=new Vault(env,{clock:()=>f.clock.now});
 assert.deepEqual(await v.open(old,'scope'),{marker:'synthetic'});const next=await v.seal({marker:'next'},'scope');assert(next.startsWith('2.'));
 assert.deepEqual(await v.open(next,'scope'),{marker:'next'});await rejectsCode(v.open(next.replace(/^2\./,'1.'),'scope'),'service_unavailable');
 await rejectsCode(v.open(old.replace(/^1\./,'2.'),'scope'),'service_unavailable');await rejectsCode(v.open(next,'another-scope'),'service_unavailable');
 assert.equal(await v.verifyHash('phone',PHONE,await f.service.vault.hash('phone',PHONE)),true);
 assert.equal(await v.verifyHash('otp',PHONE,await f.service.vault.hash('phone',PHONE)),false);
});
test('old key retirement applies at the exact deadline even to an existing Vault',async t=>{
 const f=fixture(t),old=await f.service.vault.seal({marker:true},'scope'),env=envFor(f),v=new Vault(env,{clock:()=>f.clock.now}),hash=await f.service.vault.hash('phone',PHONE);
 f.clock.now+=KEY_RETENTION.minMs;await rejectsCode(v.open(old,'scope'),'service_unavailable');assert.equal(await v.verifyHash('phone',PHONE,hash),false);
 assert((await v.seal({current:true},'scope')).startsWith('2.'));
});
test('live retained key loss is unavailable and never silently replaced',t=>{
 const f=fixture(t);assert.throws(()=>new Vault(envFor(f,{missing:true}),{clock:()=>f.clock.now}),e=>e.code==='crypto_not_configured');
});
test('key rotation alias backfill preserves canonical imported UUID, phone hash and epochs',async t=>{
 const f=fixture(t);await f.account();const before=f.sql('SELECT * FROM auth_accounts')[0],env=envFor(f),s=await rotate(f,env);
 const after=f.sql('SELECT * FROM auth_accounts')[0];for(const field of ['user_id','phone_hash','status','auth_epoch','verified_at_ms','created_at_ms','source_project','source_user_id'])assert.equal(after[field],before[field]);
 assert(after.phone_cipher.startsWith('2.'));const alias=f.sql("SELECT * FROM auth_phone_aliases WHERE key_version='2'")[0];assert.equal(alias.user_id,USER);
 const secret=randomSecret(),c=await s.challenge(24,{phone:PHONE,clientSecret:secret},f.key(),'c'.repeat(64));
 const row=f.sql('SELECT * FROM auth_challenges WHERE challenge_id=?',c.challengeId)[0],payload=await s.vault.open(row.delivery_cipher,`challenge:${c.challengeId}`);
 const tokens=await s.verify(24,{challengeId:c.challengeId,code:payload.code,clientSecret:secret},f.key());
 assert.equal(tokens.userId,USER);assert.equal(f.count('auth_accounts'),1);
});

for(const [name,mutate] of [
 ['duplicate versions',p=>p.versions.push({...p.versions[0]})],['missing current version',p=>p.versions.pop()],
 ['unknown field',p=>p.versions[0].encryption='never-a-key'],['short retention',p=>p.versions[0].readUntil=p.activatedAt+899999],
 ['unbounded old retention',p=>p.versions[0].readUntil=null],['long retention',p=>p.versions[0].readUntil=p.activatedAt+KEY_RETENTION.maxMs+1],
 ['version type',p=>p.currentVersion=2],['boolean timestamp',p=>p.activatedAt=true],['future old version',p=>p.versions[0].version='3']
])test(`key policy rejects ${name}`,t=>{const f=fixture(t),env=envFor(f),p=JSON.parse(env.AUTH_KEY_POLICY_JSON);mutate(p);env.AUTH_KEY_POLICY_JSON=JSON.stringify(p);assert.throws(()=>new Vault(env,{clock:()=>f.clock.now}));});

test('same-version secret substitution cannot create a duplicate identity',async t=>{
 const f=fixture(t);await f.account();const env=envFor(f);await rotate(f,env);const ring=JSON.parse(env.AUTH_KEYRING_JSON);ring.keys['2']={hmac:'3'.repeat(64),encryption:'4'.repeat(64)};
 const bad=new IdentityService({...env,AUTH_KEYRING_JSON:JSON.stringify(ring)},{clock:()=>f.clock.now}),before=JSON.stringify(f.sql('SELECT * FROM auth_accounts'));
 await rejectsCode(issue(f,bad,{phone:PHONE}),'key_material_changed');assert.equal(JSON.stringify(f.sql('SELECT * FROM auth_accounts')),before);assert.equal(f.count('auth_accounts'),1);
});
test('legacy same-version secret substitution is refused before issuing a challenge',async t=>{
 const f=fixture(t);await f.account();const bad=new IdentityService({...f.env,AUTH_HMAC_KEY:'3'.repeat(64),AUTH_ENCRYPTION_KEY:'4'.repeat(64)},{clock:()=>f.clock.now});
 await rejectsCode(issue(f,bad,{phone:PHONE}),'key_material_changed');assert.equal(f.count('auth_challenges'),0);
});
test('registered read-policy removal or extension is refused before its deadline',async t=>{
 const f=fixture(t),env=envFor(f);const s=await rotate(f,env);const a=await login(f,s,{phone:PHONE});
 for(const change of ['remove','extend']){const p=JSON.parse(env.AUTH_KEY_POLICY_JSON);if(change==='remove')p.versions.shift();else p.versions[0].readUntil+=1;
  const ring=JSON.parse(env.AUTH_KEYRING_JSON);if(change==='remove')delete ring.keys['1'];
  const bad=new IdentityService({...env,AUTH_KEY_POLICY_JSON:JSON.stringify(p),AUTH_KEYRING_JSON:JSON.stringify(ring)},{clock:()=>f.clock.now});await rejectsCode(bad.current(24,a.tokens.accessToken),'key_policy_changed');}
});
test('expired old-key removal keeps canonical identity lookup working with the current alias',async t=>{
 const f=fixture(t);await f.account();const env=envFor(f),s=await rotate(f,env);f.clock.now+=KEY_RETENTION.minMs;
 const p=JSON.parse(env.AUTH_KEY_POLICY_JSON);p.versions.shift();const ring=JSON.parse(env.AUTH_KEYRING_JSON);delete ring.keys['1'];
 const current=new IdentityService({...env,AUTH_KEY_POLICY_JSON:JSON.stringify(p),AUTH_KEYRING_JSON:JSON.stringify(ring)},{clock:()=>f.clock.now});
 const a=await login(f,current,{phone:PHONE});assert.equal(a.tokens.userId,USER);assert.equal(f.count('auth_accounts'),1);
 assert.equal(f.sql('SELECT phone_hash FROM auth_accounts')[0].phone_hash,await f.service.vault.hash('phone',PHONE));
});
test('lost live old key cannot be regenerated by preparation and leaves accounts unchanged',async t=>{
 const f=fixture(t);await f.account();const env=envFor(f,{missing:true}),before=JSON.stringify(f.sql('SELECT * FROM auth_accounts'));pause(f,env);
 await rejectsCode(prepareIdentityKeyRotation(env,rotationOptions(f)),'crypto_not_configured');assert.equal(JSON.stringify(f.sql('SELECT * FROM auth_accounts')),before);
});
test('first key registration is explicit, paused and restricted to an empty database',async t=>{
 const {Database}=await import('./support/fixture.mjs');const f=fixture(t),db=new Database(f.clock);t.after(()=>db.sqlite.close());
 const env={...f.env,AUTH_DB:db,AUTH_DELIVERY_ENABLED:'false'},opts={clock:()=>f.clock.now,evidence:'synthetic-bootstrap'};
 const r=await registerInitialIdentityKeys(env,opts);assert.equal(r.registered,true);assert.equal(db.sqlite.prepare('SELECT count(*) n FROM auth_accounts').get().n,0);
 assert.deepEqual(await registerInitialIdentityKeys(env,opts),r);
 await rejectsCode(registerInitialIdentityKeys({...env,AUTH_HMAC_KEY:'3'.repeat(64)},opts),'key_material_changed');
 db.sqlite.exec("UPDATE auth_settings SET import_ready=1,import_evidence='synthetic' WHERE singleton=1");
 assert.equal((await new IdentityService({...env,AUTH_DB:db},{clock:()=>f.clock.now}).vault.fingerprint('1')).hmac.length,64);
});
test('bounded preparations are explicit and activation rejects a partial batch',async t=>{
 const f=fixture(t);await f.account();await f.account({phone:PHONE2,id:crypto.randomUUID()});await f.issue();const env=envFor(f);pause(f,env);const options=rotationOptions(f,{batchLimit:1});
 const first=await prepareIdentityKeyRotation(env,options);assert.equal(first.processed,1);assert.equal(first.complete,false);
 await rejectsCode(activateIdentityKeyRotation(env,options),'key_rotation_incomplete');assert.equal(f.sql('SELECT key_version FROM auth_settings')[0].key_version,'1');
 let batches=1,r=first;while(!r.complete){r=await prepareIdentityKeyRotation(env,options);assert(++batches<20);}assert(batches>1);
 const a=await activateIdentityKeyRotation(env,options);assert.equal(a.currentVersion,'2');assert.deepEqual(await activateIdentityKeyRotation(env,options),a);
 assert.equal(f.sql('SELECT import_ready FROM auth_settings')[0].import_ready,0);assert.equal(f.sql('SELECT enabled FROM auth_delivery_control')[0].enabled,0);
});
test('preparation rejects live import/delivery instead of making an online key switch',async t=>{
 const f=fixture(t);await f.account();const env=envFor(f),before=JSON.stringify(f.sql('SELECT * FROM auth_accounts'));
 await rejectsCode(prepareIdentityKeyRotation(env,rotationOptions(f)),'key_rotation_requires_pause');assert.equal(JSON.stringify(f.sql('SELECT * FROM auth_accounts')),before);
});
test('rewrap acknowledgement loss reconciles without changing already committed ciphertext again',async t=>{
 const f=fixture(t);await f.account();const env=envFor(f);pause(f,env);f.setHook({when:s=>s.some(x=>x.sql.includes('SET phone_cipher=')),after:true});
 await assert.rejects(prepareIdentityKeyRotation(env,rotationOptions(f)));f.clearHook();const after=f.sql('SELECT phone_cipher FROM auth_accounts')[0].phone_cipher;
 const r=await prepareIdentityKeyRotation(env,rotationOptions(f));assert.equal(r.processed,0);assert.equal(r.complete,true);assert.equal(f.sql('SELECT phone_cipher FROM auth_accounts')[0].phone_cipher,after);
});
test('rewrap and activation transactions reject gate changes during asynchronous work',async t=>{
 const f=fixture(t);await f.account();const env=envFor(f);pause(f,env);const before=JSON.stringify(f.sql('SELECT * FROM auth_accounts'));
 f.setHook({when:s=>s.some(x=>x.sql.includes('SET phone_cipher=')),before:()=>f.db.sqlite.exec('UPDATE auth_settings SET import_ready=1')});
 await assert.rejects(prepareIdentityKeyRotation(env,rotationOptions(f)));assert.equal(JSON.stringify(f.sql('SELECT * FROM auth_accounts')),before);assert.equal(f.sql("SELECT count(*) n FROM auth_key_versions WHERE key_version='2'")[0].n,0);
 f.clearHook();pause(f,env);await prepareIdentityKeyRotation(env,rotationOptions(f));f.setHook({when:s=>s.some(x=>x.sql.includes('INSERT INTO auth_key_rotations')),before:()=>f.db.sqlite.exec('UPDATE auth_delivery_control SET enabled=1')});
 await assert.rejects(activateIdentityKeyRotation(env,rotationOptions(f)));assert.equal(f.sql('SELECT key_version FROM auth_settings')[0].key_version,'1');assert.equal(f.count('auth_key_rotations'),0);
});
test('original native verification and refresh response receipts recover across a key change',async t=>{
 const f=fixture(t),a=await f.login(),refreshKey=f.key(),r=await f.service.refresh(24,{refreshToken:a.tokens.refreshToken},refreshKey),env=envFor(f);
 const s=await rotate(f,env);assert.deepEqual(await s.refresh(24,{refreshToken:a.tokens.refreshToken},refreshKey),r);
 await rejectsCode(s.verify(24,input(a.c),a.key),'reauthentication_required');assert.equal(r.authenticatedAt,a.tokens.authenticatedAt);
 const f2=fixture(t),b=await f2.login(),s2=await rotate(f2,envFor(f2));assert.deepEqual(await s2.verify(24,input(b.c),b.key),b.tokens);
});
test('an original challenge retry survives a key change without another delivery',async t=>{
 const f=fixture(t),c=await f.issue(),s=await rotate(f,envFor(f));const r=await s.challenge(24,{phone:PHONE,clientSecret:c.secret},c.requestKey,'c'.repeat(64));
 assert.equal(r.challengeId,c.challengeId);assert.equal(f.count('auth_challenges'),1);await rejectsCode(s.challenge(24,{phone:PHONE2,clientSecret:c.secret},c.requestKey,'c'.repeat(64)),'idempotency_conflict');
});
test('pre-change and post-change signups converge on one identity under parallel verification',async t=>{
 const f=fixture(t),old=await f.issue(),s=await rotate(f,envFor(f)),fresh=await issue(f,s,{phone:PHONE});
 const [a,b]=await Promise.all([s.verify(24,input(old),f.key()),s.verify(24,input(fresh),f.key())]);assert.equal(a.userId,b.userId);assert.equal(f.count('auth_accounts'),1);assert.equal(f.count('auth_sessions'),2);
 assert.equal(f.sql("SELECT count(*) n FROM auth_phone_aliases WHERE key_version='2'")[0].n,1);assert(f.sql('SELECT phone_cipher FROM auth_accounts')[0].phone_cipher.startsWith('2.'));
});
test('changing a challenge HMAC version cannot make an old OTP valid under another key',async t=>{
 const f=fixture(t),c=await f.issue(),s=await rotate(f,envFor(f));f.db.sqlite.exec("UPDATE auth_challenges SET hmac_key_version='2'");
 await rejectsCode(s.verify(24,input(c),f.key()),'invalid_code');assert.equal(f.count('auth_accounts'),0);
});
test('rotation does not reset the phone issuance or verification budget',async t=>{
 const f=fixture(t),a=await f.login();for(let i=1;i<15;i++)await f.service.verify(24,input(a.c),a.key);
 const s=await rotate(f,envFor(f));await rejectsCode(s.verify(24,input(a.c),a.key),'rate_limited');await issue(f,s,{phone:PHONE});await issue(f,s,{phone:PHONE,club:26});
 await rejectsCode(issue(f,s,{phone:PHONE}),'rate_limited');assert.equal(f.count('auth_challenges'),3);
});
test('original deletion receipt remains recoverable without reviving any session',async t=>{
 const f=fixture(t),a=await f.login(),key=f.key(),r=await f.service.deletion(24,a.tokens.accessToken,{confirmation:'DELETE MY ACCOUNT'},key),s=await rotate(f,envFor(f));
 assert.deepEqual(await s.deletion(24,a.tokens.accessToken,{confirmation:'DELETE MY ACCOUNT'},key),r);await rejectsCode(s.current(24,a.tokens.accessToken),'unauthenticated');
 assert.equal(f.count('auth_outbox'),1);await rejectsCode(s.deletion(24,a.tokens.accessToken,{confirmation:'DELETE MY ACCOUNT'},f.key()),'unauthenticated');
});
test('superseded key workers cannot serve or mutate after the new version activates',async t=>{
 const f=fixture(t),a=await f.login();await rotate(f,envFor(f));await rejectsCode(f.service.current(24,a.tokens.accessToken),'key_policy_changed');
 await rejectsCode(f.issue(),'key_policy_changed');assert.equal(f.count('auth_challenges'),1);
});

test('public policy validation requires no key material and shares the runtime schema',t=>{
 const f=fixture(t),env=envFor(f),publicEnv={AUTH_KEY_VERSION:'2',AUTH_KEY_POLICY_JSON:env.AUTH_KEY_POLICY_JSON};
 const p=publicKeyPolicy(publicEnv);assert.equal(p.currentVersion,'2');assert.equal(p.versions.length,2);assert.equal(p.legacy,false);
 assert.equal(publicKeyPolicy({AUTH_KEY_VERSION:'1'}).legacy,true);assert.throws(()=>publicKeyPolicy({AUTH_KEY_VERSION:'2'}));
 assert.throws(()=>new Vault(publicEnv,{clock:()=>f.clock.now}));
});
