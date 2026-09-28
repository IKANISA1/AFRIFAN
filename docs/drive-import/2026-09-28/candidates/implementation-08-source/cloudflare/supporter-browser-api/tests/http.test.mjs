import {test} from 'node:test';
import assert from 'node:assert/strict';
import {fixture,withPayments,ORIGIN} from './support/fixture.mjs';
import {SESSION_COOKIE,BOOTSTRAP_COOKIE,cookies,cookieHeader} from '../src/http.mjs';
async function json(r,status=200){const v=await r.json();assert.equal(r.status,status,JSON.stringify(v));return v;}
const sessionHeaders=s=>({sessionCookie:s.sessionCookie,csrf:s.view.csrfToken,sessionId:s.view.sessionId});
const bootHeaders=b=>({bootstrapCookie:b.bootstrapCookie,csrf:b.view.csrfToken});

test('HTTP start sets a host-only HttpOnly Secure Strict cookie and no-store headers',async t=>{
 const f=fixture(t),r=await f.http('/v1/browser/session/start',{method:'POST'}),v=await json(r);
 const c=r.headers.get('set-cookie');assert(c.startsWith(`${BOOTSTRAP_COOKIE}=`));
 for(const attr of ['HttpOnly','Secure','SameSite=Strict','Path=/'])assert(c.includes(attr));
 assert(!c.includes('Domain='));assert(!('bootstrapCookie' in v));assert(!r.headers.has('access-control-allow-origin'));
 assert(r.headers.get('cache-control').includes('no-store'));assert(r.headers.get('content-security-policy').includes("default-src 'none'"));
});
test('full HTTP sign-in uses cookie bootstrap and never returns bearer credentials',async t=>{
 const f=fixture(t);const start=await f.http('/v1/browser/session/start',{method:'POST'});const b=await json(start);
 const bootstrapCookie=start.headers.get('set-cookie').split(';')[0].split('=').slice(1).join('=');
 const challenge=await json(await f.http('/v1/browser/session/challenge',{method:'POST',json:{phone:'+250700000001'},
  bootstrapCookie,csrf:b.csrfToken,key:f.key()}));
 const row=f.sql('SELECT * FROM auth_challenges WHERE challenge_id=?',challenge.challengeId)[0];
 const {code}=await f.service.vault.open(row.delivery_cipher,`challenge:${challenge.challengeId}`);
 const response=await f.http('/v1/browser/session/verify',{method:'POST',json:{challengeId:challenge.challengeId,code},bootstrapCookie,csrf:b.csrfToken,key:f.key()});
 const s=await json(response);assert.equal(s.role,'supporter');assert(response.headers.get('set-cookie').startsWith(`${SESSION_COOKIE}=`));
 assert(!JSON.stringify(s).match(/accessToken|refreshToken|sessionCookie|phone_hash|code_hash/));
});
for(const headers of [{origin:'https://evil.invalid'},{origin:'null'},{origin:ORIGIN+'/path'},
 {origin:ORIGIN+'.evil.invalid'},{'sec-fetch-site':'same-site'},{'sec-fetch-site':'cross-site'},
 {'x-africlub-browser-intent':null},{authorization:'Bearer arbitrary'},{'x-africlub-client':'native-v1'},
 {'x-africlub-session':'arbitrary'}])test(`POST rejects wrong browser context ${JSON.stringify(headers)}`,async t=>{
 const f=fixture(t),r=await f.http('/v1/browser/session/start',{method:'POST',headers});assert.notEqual(r.status,200);assert.equal(f.count('auth_challenges'),0);
});
test('modern metadata absence falls back to exact Origin for POST, never missing both',async t=>{
 const f=fixture(t);await json(await f.http('/v1/browser/session/start',{method:'POST',headers:{'sec-fetch-site':null}}));
 await json(await f.http('/v1/browser/session/start',{method:'POST',headers:{'sec-fetch-site':null,origin:null}}),403);
});
test('private GET needs same-origin metadata or verified Origin/Referer',async t=>{
 const f=fixture(t),{s}=await f.browserLogin();
 await json(await f.http('/v1/browser/session',{...sessionHeaders(s),headers:{'sec-fetch-site':null,referer:ORIGIN+'/membership'}}));
 await json(await f.http('/v1/browser/session',{...sessionHeaders(s),headers:{'sec-fetch-site':null}}),403);
});
for(const patch of [{url:'https://other.invalid/v1/browser/session/start'},{url:ORIGIN+'/v1/browser/session/start?user=other'},
 {headers:{'content-type':'text/plain'}},{headers:{'content-type':'application/x-www-form-urlencoded'}},
 {headers:{'content-encoding':'gzip'}},{raw:'{bad'},{json:{userId:crypto.randomUUID()}},{cf:false}])
 test(`start denies invalid request ${JSON.stringify(patch)}`,async t=>{const f=fixture(t);assert.notEqual((await f.http('/v1/browser/session/start',{method:'POST',...patch})).status,200);});
test('duplicate session cookies are rejected rather than selecting attacker-preferred value',()=>{
 assert.throws(()=>cookies(new Request(ORIGIN,{headers:{cookie:`${SESSION_COOKIE}=a; ${SESSION_COOKIE}=b`}})));
});
test('cookie serializer rejects injection',()=>assert.throws(()=>cookieHeader(SESSION_COOKIE,'abc; Domain=evil',5)));
test('edge limiter prevents bootstrap creation and does not log raw IP as key',async t=>{
 const f=fixture(t);let key;f.env.EDGE_LIMIT.limit=async v=>{key=v.key;return {success:false};};
 await json(await f.http('/v1/browser/session/start',{method:'POST'}),429);assert.match(key,/^[0-9a-f]{64}$/);assert(!key.includes('203.0.113'));
});
test('oversized body rejected before challenge',async t=>{
 const f=fixture(t),b=await f.start();const r=await f.http('/v1/browser/session/challenge',{method:'POST',...bootHeaders(b),key:f.key(),raw:JSON.stringify({phone:'1'.repeat(3000)})});
 await json(r,400);assert.equal(f.count('auth_challenges'),0);
});
test('CSRF is required even for a valid session cookie',async t=>{
 const f=fixture(t),{s}=await f.browserLogin();await json(await f.http('/v1/browser/session/rotate',{method:'POST',...sessionHeaders(s),csrf:'0'.repeat(64),key:f.key()}),403);
 assert.equal(f.count('auth_browser_rotations'),0);
});
test('GET cannot rotate/logout and no public native/provider endpoints exist',async t=>{
 const f=fixture(t);for(const path of ['/v1/browser/session/rotate','/v1/browser/session/logout','/v1/auth/clubs/24/verify','/refund','/allocate'])
  await json(await f.http(path),404);
});
test('HTTP rotation sets only the replacement cookie; logout clears both host cookies after commit',async t=>{
 const f=fixture(t),{s}=await f.browserLogin();const r=await f.http('/v1/browser/session/rotate',{method:'POST',...sessionHeaders(s),key:f.key()});
 const v=await json(r),cookie=r.headers.get('set-cookie').split(';')[0].split('=').slice(1).join('=');
 const out=await f.http('/v1/browser/session/logout',{method:'POST',sessionCookie:cookie,csrf:v.csrfToken,key:f.key()});
 assert.equal((await json(out)).loggedOut,true);assert(out.headers.get('set-cookie').includes('Max-Age=0'));
 await json(await f.http('/v1/browser/session',{sessionCookie:cookie}),401);
});
test('a private upstream error is redacted and uncertain after write invocation',async t=>{
 const f=fixture(t),{s}=await f.browserLogin(),key=f.key();f.env.BROWSER_IDENTITY.rotate=async()=>{throw Error('SELECT secret, phone, token');};
 const v=await json(await f.http('/v1/browser/session/rotate',{method:'POST',...sessionHeaders(s),key}),503);
 assert.equal(v.error,'identity_outcome_unknown');assert.equal(v.requestId,key);assert(!JSON.stringify(v).includes('SELECT'));
});
test('timeout never cancels or automatically replays a remote operation',async t=>{
 const f=fixture(t),{s}=await f.browserLogin(),key=f.key();let count=0;
 f.env.BROWSER_IDENTITY.rotate=async()=>{count++;return new Promise(()=>{});};
 const v=await json(await f.http('/v1/browser/session/rotate',{method:'POST',...sessionHeaders(s),key,rpcMs:5}),503);
 assert.equal(v.outcome,'unknown');assert.equal(count,1);
});
test('untrusted upstream cannot put credentials into browser JSON',async t=>{
 const f=fixture(t),{s}=await f.browserLogin();const real=f.env.BROWSER_IDENTITY.current;
 f.env.BROWSER_IDENTITY.current=async x=>{const r=await real(x);r.value.accessToken='private';return r;};
 const v=await json(await f.http('/v1/browser/session',sessionHeaders(s)),503);assert(!JSON.stringify(v).includes('private'));
});
test('membership uses the actual existing reader and never grants status from a receipt',async t=>{
 const f=await withPayments(t),{s}=await f.browserLogin();f.payment.membership();
 const first=await json(await f.http('/v1/browser/membership/status',sessionHeaders(s)));assert.equal(first.currentStatus,'active');
 f.payment.db.sql.exec("UPDATE pa_memberships SET status='suspended'");
 const second=await json(await f.http('/v1/browser/membership/status',sessionHeaders(s)));assert.equal(second.currentStatus,'suspended');
 assert.equal(second.isActive,false);assert.equal(second.historical,false);assert(!f.calls.includes('prepare'));
});
test('membership rejects wrong session anchor and body-supplied user override',async t=>{
 const f=await withPayments(t),{s}=await f.browserLogin();
 await json(await f.http('/v1/browser/membership/status',{...sessionHeaders(s),sessionId:crypto.randomUUID()}),409);
 await json(await f.http('/v1/browser/membership/status',{...sessionHeaders(s),url:ORIGIN+'/v1/browser/membership/status?userId=other'}),404);
 assert.equal(f.calls.length,0);
});
test('revocation after membership read suppresses private projection',async t=>{
 const f=await withPayments(t),{s}=await f.browserLogin(),real=f.env.CHECKOUT_READER.membershipStatus;
 f.env.CHECKOUT_READER.membershipStatus=async v=>{const r=await real(v);f.db.sqlite.exec("UPDATE auth_accounts SET status='suspended'");return r;};
 await json(await f.http('/v1/browser/membership/status',sessionHeaders(s)),401);
});
test('current membership expiry during the request downgrades the response',async t=>{
 const f=await withPayments(t),{s}=await f.browserLogin();f.payment.membership({expires_at_ms:f.clock.now+1});
 const real=f.env.CHECKOUT_READER.membershipStatus;f.env.CHECKOUT_READER.membershipStatus=async v=>{const r=await real(v);f.advance(2);return r;};
 assert.equal((await json(await f.http('/v1/browser/membership/status',sessionHeaders(s)))).isActive,false);
});
test('prepare, original-operation lookup, current order and historical receipt compose real services',async t=>{
 const f=await withPayments(t),{s}=await f.browserLogin(),key=f.key();
 const p=await json(await f.http('/v1/browser/membership/checkouts',{method:'POST',...sessionHeaders(s),key,json:{tier:'gold'}}));
 assert.equal(p.paymentVerified,false);assert.equal(p.membershipActivated,false);assert(!('ussdCode' in p));
 const lookup=await json(await f.http('/v1/browser/membership/operations/'+key,sessionHeaders(s)));assert(lookup.found);assert.equal(lookup.result.orderId,p.orderId);
 const pending=await json(await f.http('/v1/browser/membership/checkouts/'+p.orderId,sessionHeaders(s)));assert.equal(pending.status,'pending_current');
 await f.allocate(p.orderId);const received=await json(await f.http(`/v1/browser/membership/checkouts/${p.orderId}/receipt`,sessionHeaders(s)));
 assert.equal(received.historical,true);assert.equal(received.businessTargetFulfilled,true);
});
test('lost checkout response is found without a write or an invented replacement key',async t=>{
 const f=await withPayments(t),{s}=await f.browserLogin(),key=f.key(),real=f.env.CHECKOUT.prepare;
 f.env.CHECKOUT.prepare=async v=>{await real(v);throw Error('connection lost');};
 const unknown=await json(await f.http('/v1/browser/membership/checkouts',{method:'POST',...sessionHeaders(s),key,json:{tier:'gold'}}),503);
 assert.equal(unknown.requestId,key);const before=f.payment.effects();
 const lookup=await json(await f.http('/v1/browser/membership/operations/'+key,sessionHeaders(s)));
 assert.equal(lookup.found,true);assert.equal(lookup.mayRetryWithNewKey,false);assert.deepEqual(f.payment.effects(),before);
});
test('not-observed lookup does not authorize a fresh operation',async t=>{
 const f=await withPayments(t),{s}=await f.browserLogin();const v=await json(await f.http('/v1/browser/membership/operations/'+f.key(),sessionHeaders(s)));
 assert.equal(v.found,false);assert.equal(v.result,null);assert.equal(v.mayRetryWithNewKey,false);assert.equal(f.payment.count('pa_checkout_requests'),0);
});
test('owned operation recovery cannot disclose another supporter checkout',async t=>{
 const f=await withPayments(t),{s}=await f.browserLogin(),key=f.key();
 const p=await json(await f.http('/v1/browser/membership/checkouts',{method:'POST',...sessionHeaders(s),key,json:{tier:'gold'}}));
 const otherId=crypto.randomUUID();await f.account({id:otherId,phone:'+250700000002'});
 f.payment.db.sql.prepare('INSERT INTO pa_subjects(user_id,club_id,enabled) VALUES(?,24,1)').run(otherId);
 const b=await f.start(),c=await f.challenge(b,{phone:'+250700000002'}),other=await f.verify(b,c);
 const lookup=await json(await f.http('/v1/browser/membership/operations/'+key,sessionHeaders(other)));assert.equal(lookup.found,false);
 assert.notEqual((await f.http('/v1/browser/membership/checkouts/'+p.orderId,sessionHeaders(other))).status,200);
});
test('checkout requires independent feature flag and CSRF; disable does not write',async t=>{
 const f=await withPayments(t),{s}=await f.browserLogin();f.env.BROWSER_CHECKOUT_ENABLED='false';
 await json(await f.http('/v1/browser/membership/checkouts',{method:'POST',...sessionHeaders(s),key:f.key(),json:{tier:'gold'}}),503);
 assert(!f.calls.includes('prepare'));f.env.BROWSER_CHECKOUT_ENABLED='true';
 await json(await f.http('/v1/browser/membership/checkouts',{method:'POST',...sessionHeaders(s),csrf:'a'.repeat(64),key:f.key(),json:{tier:'gold'}}),403);
 assert(!f.calls.includes('prepare'));
});
