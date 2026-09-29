import {test} from 'node:test';import assert from 'node:assert/strict';
import {portalFixture,MembershipPortalController,BrowserClientError,checkPrivateCacheBoundary} from './support/portal-fixture.mjs';
async function signed(t){const f=await portalFixture(t);await f.login();const c=f.controller();await c.refresh();assert.equal(c.getSnapshot().phase,'member');return {...f,c};}
test('mount refresh is read-only and does not send an OTP',async t=>{const f=await portalFixture(t),c=f.controller();assert.equal(f.calls.length,0);await c.refresh();assert.equal(c.getSnapshot().phase,'signed_out');assert(f.calls.every(x=>x.init.method==='GET'));});
test('controller signs in through the real session and payment services',async t=>{
 const f=await portalFixture(t),c=f.controller();await c.refresh();await c.requestCode('+250700000001');assert.equal(c.getSnapshot().phase,'code_sent');
 const row=f.sql('SELECT * FROM auth_challenges ORDER BY created_at_ms DESC')[0];const {code}=await f.service.vault.open(row.delivery_cipher,`challenge:${row.challenge_id}`);
 await c.verifyCode(code);assert.equal(c.getSnapshot().phase,'member');assert.equal(c.getSnapshot().offers[0].tier,'gold');
 assert(!JSON.stringify(c.getSnapshot()).includes(code));assert(!JSON.stringify(c.getSnapshot()).includes('csrfToken'));assert.deepEqual(f.notifications,['change']);
});
test('selecting and cancelling a tier never prepares an order',async t=>{const f=await signed(t);const before=f.calls.length;f.c.selectTier('gold');assert(f.c.getSnapshot().review);f.c.cancelReview();assert.equal(f.c.getSnapshot().review,null);assert.equal(f.calls.length,before);assert.equal(f.payment.count('pa_checkout_requests'),0);});
test('confirmation prepares once and presents authoritative details without launching a dialer',async t=>{const f=await signed(t);f.c.selectTier('gold');await f.c.confirmCheckout();const s=f.c.getSnapshot();assert.equal(s.checkout.status,'pending_current');assert.equal(s.checkout.paymentInstruction.amount,10000);assert.equal(f.payment.count('pa_checkout_requests'),1);assert.equal(f.payment.count('pa_allocations'),0);assert.equal(f.memory.size,1);assert([...f.memory.keys()][0].includes('checkout-last'));});
test('recreated client restores a previously acknowledged order using only reads',async t=>{const f=await signed(t);f.c.selectTier('gold');await f.c.confirmCheckout();const id=f.c.getSnapshot().checkout.orderId,before=f.calls.length;
 const c=new MembershipPortalController(f.make(),{canCheckout:true,key:f.key});await c.refresh();assert.equal(c.getSnapshot().checkout.orderId,id);assert(f.calls.slice(before).every(x=>x.init.method==='GET'));assert.equal(f.payment.count('pa_checkout_requests'),1);});
test('catalog price change invalidates review before preparation',async t=>{const f=await signed(t);f.c.selectTier('gold');f.payment.db.sql.exec('UPDATE pa_checkout_packages SET annual_price=12345,revision=revision+1');await f.c.confirmCheckout();assert.equal(f.payment.count('pa_checkout_requests'),0);assert.equal(f.c.getSnapshot().review,null);assert.match(f.c.getSnapshot().message,/catalog changed/);});
test('catalog price may change after the last read; actual order displays the new price without payment',async t=>{const f=await signed(t);const old=f.env.CHECKOUT.prepare;f.env.CHECKOUT.prepare=async v=>{f.payment.db.sql.exec('UPDATE pa_checkout_packages SET annual_price=22222,revision=revision+1');return old(v);};f.c.selectTier('gold');await f.c.confirmCheckout();assert.equal(f.c.getSnapshot().checkout.paymentInstruction.amount,22222);assert.equal(f.payment.count('pa_allocations'),0);});
test('double confirmation does not submit two operations',async t=>{const f=await signed(t);f.c.selectTier('gold');await Promise.all([f.c.confirmCheckout(),f.c.confirmCheckout()]);assert.equal(f.payment.count('pa_checkout_requests'),1);});
test('pre-commit transport loss retains original key for explicit retry',async t=>{const f=await signed(t);const old=f.env.CHECKOUT.prepare;let fail=true;f.env.CHECKOUT.prepare=async v=>{if(fail)throw Error('before commit');return old(v);};f.c.selectTier('gold');await f.c.confirmCheckout();assert(f.c.getSnapshot().pending);const key=JSON.parse([...f.memory.values()][0]).requestId;await f.c.recoverCheckout();assert(f.c.getSnapshot().pending);assert.equal(f.payment.count('pa_checkout_requests'),0);fail=false;await f.c.retryCheckout();assert.equal(f.payment.count('pa_checkout_requests'),1);const row=f.payment.db.sql.prepare('SELECT * FROM pa_checkout_requests').get();assert.equal(row.request_id,key);});
test('post-commit response loss recovers through reads without another prepare',async t=>{const f=await signed(t),old=f.env.CHECKOUT.prepare;f.env.CHECKOUT.prepare=async v=>{await old(v);throw Error('private diagnostic');};f.c.selectTier('gold');await f.c.confirmCheckout();assert(f.c.getSnapshot().pending);assert(!JSON.stringify(f.c.getSnapshot()).includes('private diagnostic'));const before=f.calls.length;await f.c.recoverCheckout();assert.equal(f.c.getSnapshot().pending,false);assert.equal(f.c.getSnapshot().checkout.status,'pending_current');assert(f.calls.slice(before).every(x=>x.init.method==='GET'));assert.equal(f.payment.count('pa_checkout_requests'),1);});
test('last-order storage failure leaves the uncertain record recoverable',async t=>{const f=await signed(t),set=f.storage.setItem;f.storage.setItem=(k,v)=>{if(k.includes('checkout-last'))throw Error('disk');set(k,v);};f.c.selectTier('gold');await f.c.confirmCheckout();assert.equal(f.payment.count('pa_checkout_requests'),1);assert.equal(f.memory.size,1);assert([...f.memory.keys()][0].includes('checkout:v1'));f.storage.setItem=set;await f.c.recoverCheckout();assert.equal(f.c.getSnapshot().pending,false);});
test('corrupt last-order metadata blocks new checkout but preserves read-only membership',async t=>{const f=await signed(t);f.c.selectTier('gold');await f.c.confirmCheckout();f.memory.set([...f.memory.keys()][0],'{bad');await f.c.refresh();assert.equal(f.c.getSnapshot().phase,'member');assert.equal(f.c.getSnapshot().canCheckout,false);assert.match(f.c.getSnapshot().message,/Recovery records/);});
test('hidden lifecycle during preparation suppresses late private presentation; original result remains readable',async t=>{const f=await signed(t),old=f.env.CHECKOUT.prepare;f.env.CHECKOUT.prepare=async v=>{const p=await old(v);f.setActive(false);f.c.invalidate();return p;};f.c.selectTier('gold');await f.c.confirmCheckout();assert.equal(f.c.getSnapshot().phase,'blocked');assert.equal(f.c.getSnapshot().checkout,null);assert.equal(f.c.getSnapshot().membership,null);assert.equal(f.payment.count('pa_checkout_requests'),1);f.setActive(true);await f.c.refresh();assert.equal(f.c.getSnapshot().checkout.status,'pending_current');});
test('background invalidation before dispatch prevents preparation',async t=>{const f=await signed(t),old=f.env.CHECKOUT_READER.offers;f.c.selectTier('gold');f.env.CHECKOUT_READER.offers=async v=>{const o=await old(v);f.c.invalidate();return o;};await f.c.confirmCheckout();assert.equal(f.payment.count('pa_checkout_requests'),0);});
test('offline explicit action does not reach a write endpoint',async t=>{const f=await signed(t);f.c.selectTier('gold');f.setActive(false);await f.c.confirmCheckout();assert.equal(f.payment.count('pa_checkout_requests'),0);});
test('current suspension is not overwritten by a historical receipt',async t=>{const f=await signed(t);f.c.selectTier('gold');await f.c.confirmCheckout();const id=f.c.getSnapshot().checkout.orderId;await f.allocate(id);f.payment.db.sql.exec("UPDATE pa_memberships SET status='suspended'");await f.c.refreshCheckout();assert.equal(f.c.getSnapshot().membership.currentStatus,'suspended');await f.c.readReceipt();assert.equal(f.c.getSnapshot().receipt.historical,true);assert.equal(f.c.getSnapshot().membership.currentStatus,'suspended');});
test('expiry tick removes payment instructions without an HTTP request',async t=>{const f=await signed(t);f.c.selectTier('gold');await f.c.confirmCheckout();const c=f.c.getSnapshot().checkout,n=f.calls.length;f.c.tick(c.expiresAt);assert.equal(f.c.getSnapshot().checkout?.paymentInstruction??null,null);assert.equal(f.calls.length,n);});
test('logout retains private owner-scoped order metadata while hiding presentation',async t=>{const f=await signed(t);f.c.selectTier('gold');await f.c.confirmCheckout();await f.c.logout();assert.equal(f.c.getSnapshot().phase,'signed_out');assert.equal(f.c.getSnapshot().checkout,null);assert.equal(f.memory.size,1);});
test('unknown logout retries the exact original operation key',async t=>{const f=await signed(t),old=f.env.BROWSER_IDENTITY.logout;let once=true;f.env.BROWSER_IDENTITY.logout=async v=>{const res=await old(v);if(once){once=false;throw Error('lost');}return res;};await f.c.logout();assert(f.c.getSnapshot().canRetrySession);assert.equal(f.c.getSnapshot().membership,null);await f.c.retrySession();const calls=f.calls.filter(x=>x.url.endsWith('/logout'));assert.equal(calls.length,2);assert.equal(calls[0].init.headers['idempotency-key'],calls[1].init.headers['idempotency-key']);assert.equal(f.c.getSnapshot().phase,'signed_out');});
test('unknown rotation blocks new checkout until original retry',async t=>{const f=await signed(t),old=f.env.BROWSER_IDENTITY.rotate;let once=true;f.env.BROWSER_IDENTITY.rotate=async v=>{const res=await old(v);if(once){once=false;throw Error('lost');}return res;};await f.c.rotate();assert(f.c.getSnapshot().canRetrySession);f.c.selectTier('gold');assert.equal(f.c.getSnapshot().review,null);await f.c.retrySession();assert.equal(f.c.getSnapshot().canRetrySession,false);const calls=f.calls.filter(x=>x.url.endsWith('/rotate'));assert.equal(calls[0].init.headers['idempotency-key'],calls[1].init.headers['idempotency-key']);});
test('site cache handshake failure permits no sign-in or checkout',async t=>{const f=await portalFixture(t),c=new MembershipPortalController(f.client,{canCheckout:true,key:f.key,checkCacheBoundary:async()=>false});await c.refresh();assert.equal(c.getSnapshot().phase,'blocked');assert.equal(f.calls.length,0);await c.requestCode('+250700000001');assert.equal(f.calls.length,0);});
test('a browser lacking Web Locks can read but cannot select checkout',async t=>{const f=await signed(t),c=new MembershipPortalController(f.make({recoveryStore:undefined,rememberLastCheckout:false}),{canCheckout:false,key:f.key});await c.refresh();assert.equal(c.getSnapshot().phase,'member');c.selectTier('gold');assert.equal(c.getSnapshot().review,null);});
test('no controlling service worker requires no artificial handshake',async()=>{assert.equal(await checkPrivateCacheBoundary(undefined),true);});
test('old worker without protocol acknowledgement is rejected',async()=>{assert.equal(await checkPrivateCacheBoundary({controller:{postMessage(){}}},()=>new MessageChannel(),10),false);});
test('worker acknowledgement must confirm the expected protocol and successful purge',async()=>{for(const purged of [false,true]){
 const worker={postMessage(data,ports){assert.equal(data.type,'AFRICLUB_PRIVATE_CACHE_CHECK');ports[0].postMessage({protocol:'africlub-private-cache-v1',purged});}};
 assert.equal(await checkPrivateCacheBoundary({controller:worker}),purged);
}});

test('challenge retry after lifecycle invalidation uses the original key and current presentation epoch',async t=>{
 const f=await portalFixture(t),c=f.controller();await c.refresh();
 const original=f.env.BROWSER_IDENTITY.challenge;let lost=true;
 f.env.BROWSER_IDENTITY.challenge=async v=>{const result=await original(v);if(lost){lost=false;throw Error('response lost');}return result;};
 await c.requestCode('+250700000001');assert(c.getSnapshot().canRetrySignIn);c.invalidate();
 await c.retrySignIn();assert.equal(c.getSnapshot().phase,'code_sent');
 const calls=f.calls.filter(x=>x.url.endsWith('/challenge'));
 assert.equal(calls.length,2);assert.equal(calls[0].init.headers['idempotency-key'],calls[1].init.headers['idempotency-key']);
});
test('rotation retry after lifecycle invalidation restores presentation using the same operation',async t=>{
 const f=await signed(t),original=f.env.BROWSER_IDENTITY.rotate;let lost=true;
 f.env.BROWSER_IDENTITY.rotate=async v=>{const result=await original(v);if(lost){lost=false;throw Error('response lost');}return result;};
 await f.c.rotate();assert(f.c.getSnapshot().canRetrySession);f.c.invalidate();await f.c.retrySession();
 assert.equal(f.c.getSnapshot().phase,'member');assert(f.c.getSnapshot().membership);
 const calls=f.calls.filter(x=>x.url.endsWith('/rotate'));
 assert.equal(calls.length,2);assert.equal(calls[0].init.headers['idempotency-key'],calls[1].init.headers['idempotency-key']);
});
test('logout retry after lifecycle invalidation acknowledges the same original logout',async t=>{
 const f=await signed(t),original=f.env.BROWSER_IDENTITY.logout;let lost=true;
 f.env.BROWSER_IDENTITY.logout=async v=>{const result=await original(v);if(lost){lost=false;throw Error('response lost');}return result;};
 await f.c.logout();assert(f.c.getSnapshot().canRetrySession);f.c.invalidate();await f.c.retrySession();
 assert.equal(f.c.getSnapshot().phase,'signed_out');assert.equal(f.c.getSnapshot().membership,null);
});
test('concealment during sign-in bootstrap prevents a later unsent challenge',async t=>{
 const f=await portalFixture(t),c=f.controller();await c.refresh();const original=f.env.BROWSER_IDENTITY.start;
 f.env.BROWSER_IDENTITY.start=async v=>{const result=await original(v);c.invalidate();return result;};
 await c.requestCode('+250700000001');assert.equal(f.calls.filter(x=>x.url.endsWith('/challenge')).length,0);
});

test('an unauthenticated refresh cannot replace an unresolved challenge with a new operation',async t=>{
 const f=await portalFixture(t),c=f.controller();await c.refresh();const original=f.env.BROWSER_IDENTITY.challenge;let lost=true;
 f.env.BROWSER_IDENTITY.challenge=async v=>{const result=await original(v);if(lost){lost=false;throw Error('response lost');}return result;};
 await c.requestCode('+250700000001');c.invalidate();await c.refresh();
 assert(c.getSnapshot().canRetrySignIn);await c.requestCode('+250700000001');
 assert.equal(f.sql('SELECT COUNT(*) AS n FROM auth_challenges')[0].n,1);
 await c.retrySignIn();assert.equal(c.getSnapshot().phase,'code_sent');
 assert.equal(f.sql('SELECT COUNT(*) AS n FROM auth_challenges')[0].n,1);
 const calls=f.calls.filter(x=>x.url.endsWith('/challenge'));assert.equal(calls.length,2);
 assert.equal(calls[0].init.headers['idempotency-key'],calls[1].init.headers['idempotency-key']);
});
