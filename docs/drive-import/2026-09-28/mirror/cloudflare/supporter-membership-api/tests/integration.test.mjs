import test from 'node:test';import assert from 'node:assert/strict';import {fixture,json,ids} from './fixture.mjs';
test('real identity to checkout to evidence to allocation to owner-only historical receipt',async t=>{
 const f=await fixture(t);assert.equal((await json(await f.call('session'))).userId,ids.user);
 const p=await f.prepare();assert.equal('ussdCode' in p,false);assert.equal(f.payment.count('pa_allocations'),0);assert.equal(f.payment.count('pa_memberships'),0);
 const path=`membership/checkouts/${p.orderId}`,state=await json(await f.call(path));assert.equal(state.status,'pending_current');assert.equal(state.paymentInstruction.ussdCode,'*182*8*1*123456*10000#');
 await json(await f.call(path+'/receipt'),409);assert.equal(f.calls.includes('receipt'),false);
 f.payment.membership({status:'suspended'});await f.allocate(p.orderId);
 const after=await json(await f.call(path));assert.equal(after.status,'allocated');assert.equal(after.paymentInstruction,null);
 const receipt=await json(await f.call(path+'/receipt'));assert.equal(receipt.historical,true);assert.equal(receipt.membershipAtAllocation.status,'suspended');
 for(const field of ['userId','evidenceId','sourceIntentId','providerReference','accessToken'])assert.equal(field in receipt,false);
 assert.equal(f.payment.count('pa_allocations'),1);assert.equal(f.payment.count('pa_outbox'),1);
});
test('unknown prepare recovers original key after reauthentication without another order',async t=>{
 const f=await fixture(t),key=crypto.randomUUID(),original=f.env.CHECKOUT.prepare;
 f.env.CHECKOUT.prepare=async v=>{const r=await original(v);await f.auth.service.revoke(24,f.tokens.accessToken,{scope:'current'});return r;};
 const r=await json(await f.call('membership/checkouts',{key}),503);assert.deepEqual(r,{schemaVersion:1,error:'checkout_outcome_unknown',outcome:'unknown',requestId:key});assert.equal(f.payment.count('pa_checkout_requests'),1);
 f.env.CHECKOUT.prepare=original;const tokens=(await f.auth.login()).tokens;
 assert.equal((await json(await f.call('membership/checkouts',{key,token:tokens.accessToken}))).requestId,key);assert.equal(f.payment.count('pa_checkout_requests'),1);
});
test('same key replays descriptor while changed tier does not create another request',async t=>{
 const f=await fixture(t),key=crypto.randomUUID(),p=await json(await f.call('membership/checkouts',{key}));
 assert.deepEqual(await json(await f.call('membership/checkouts',{key})),p);
 assert.equal((await json(await f.call('membership/checkouts',{key,body:{tier:'silver'}}),503)).outcome,'unknown');assert.equal(f.payment.count('pa_checkout_requests'),1);
});
test('another supporter cannot read checkout or invoke broad receipt reader',async t=>{
 const f=await fixture(t),p=await f.prepare();await f.allocate(p.orderId);const other=await f.attacker();
 for(const tail of ['', '/receipt'])await json(await f.call(`membership/checkouts/${p.orderId}${tail}`,{token:other.accessToken}),404);
 assert.equal(f.calls.includes('receipt'),false);
});
test('other club rejects bearer before domain access',async t=>{const f=await fixture(t);await json(await f.call('membership/checkouts',{clubId:25}),503);assert.equal(f.calls.includes('prepare'),false);});
for(const kind of ['revoked','account_disabled','club_disabled','rotated','refresh_token'])test(`rejects ${kind} before checkout`,async t=>{
 const f=await fixture(t);let token=f.tokens.accessToken;
 if(kind==='revoked')await f.auth.service.revoke(24,token,{scope:'current'});
 if(kind==='account_disabled')f.auth.db.sqlite.prepare("UPDATE auth_accounts SET status='suspended' WHERE user_id=?").run(ids.user);
 if(kind==='club_disabled')f.auth.db.sqlite.prepare('UPDATE auth_clubs SET enabled=0 WHERE club_id=24').run();
 if(kind==='rotated')await f.auth.service.refresh(24,{refreshToken:f.tokens.refreshToken},crypto.randomUUID());
 if(kind==='refresh_token')token=f.tokens.refreshToken;
 assert.ok([401,503].includes((await f.call('membership/checkouts',{token})).status));assert.equal(f.calls.includes('prepare'),false);
});
test('cross-database revocation race withholds response but does not falsely promise rollback',async t=>{
 const f=await fixture(t),original=f.env.CHECKOUT.prepare;
 f.env.CHECKOUT.prepare=async v=>{await f.auth.service.revoke(24,f.tokens.accessToken,{scope:'current'});return original(v);};
 assert.equal((await json(await f.call(),503)).outcome,'unknown');assert.equal(f.payment.count('pa_checkout_requests'),1);assert.equal(f.payment.count('pa_memberships'),0);
});
test('revocation during read prevents disclosure',async t=>{
 const f=await fixture(t),p=await f.prepare(),original=f.env.CHECKOUT_READER.read;
 f.env.CHECKOUT_READER.read=async v=>{const r=await original(v);await f.auth.service.revoke(24,f.tokens.accessToken,{scope:'current'});return r;};
 assert.equal('paymentInstruction' in await json(await f.call(`membership/checkouts/${p.orderId}`),401),false);
});
test('catalog change hides instructions while original descriptor stays recoverable',async t=>{
 const f=await fixture(t),key=crypto.randomUUID(),p=await json(await f.call('membership/checkouts',{key}));f.payment.db.sql.exec('UPDATE pa_checkout_packages SET annual_price=20000');
 const state=await json(await f.call(`membership/checkouts/${p.orderId}`));assert.equal(state.status,'configuration_changed');assert.equal(state.paymentInstruction,null);
 const recovered=await json(await f.call('membership/checkouts',{key}));assert.equal(recovered.orderId,p.orderId);assert.equal('ussdCode' in recovered,false);
});
test('private timeout may commit once later; original-key recovery never starts another order',async t=>{
 const f=await fixture(t,{rpcMs:100}),original=f.env.CHECKOUT.prepare;let done;const finished=new Promise(resolve=>done=resolve);
 f.env.CHECKOUT.prepare=async v=>{await new Promise(r=>setTimeout(r,200));const x=await original(v);done();return x;};
 const key=crypto.randomUUID();assert.equal((await json(await f.call('membership/checkouts',{key}),503)).outcome,'unknown');await finished;
 f.env.CHECKOUT.prepare=original;await json(await f.call('membership/checkouts',{key}));assert.equal(f.payment.count('pa_checkout_requests'),1);
});
test('concurrent matching requests converge on one pending order',async t=>{
 const f=await fixture(t);const results=await Promise.all((await Promise.all([f.call(),f.call(),f.call()])).map(r=>json(r)));
 assert.equal(new Set(results.map(r=>r.orderId)).size,1);assert.equal(f.payment.count('pa_checkout_order_details'),1);
});
