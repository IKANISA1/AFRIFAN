import {test} from 'node:test';import assert from 'node:assert/strict';
import {portalFixture} from './support/portal-fixture.mjs';
import {projectOffers} from '../src/offers.mjs';
test('offers read uses canonical approved view and exposes no receiver identifiers',async t=>{const f=await portalFixture(t);await f.login();const before=f.payment.effects();const v=await f.client.offers();assert.equal(v.offers[0].amount,10000);assert.equal(v.preparationOnly,true);assert.deepEqual(Object.keys(v.offers[0]).sort(),['amount','country','currency','tier']);assert.deepEqual(f.payment.effects(),before);});
test('existing hyphenated membership tier passes without renaming',async t=>{const f=await portalFixture(t);f.payment.addPackage({tier:'ingenzi-imanzi'});await f.login();assert((await f.client.offers()).offers.some(x=>x.tier==='ingenzi-imanzi'));const p=await f.client.prepareCheckout('ingenzi-imanzi',f.key());assert.equal(p.tier,'ingenzi-imanzi');assert.equal((await f.client.checkout(p.orderId)).tier,'ingenzi-imanzi');});
test('disabled catalog packages are not offered',async t=>{const f=await portalFixture(t);await f.login();f.payment.db.sql.exec('UPDATE pa_checkout_packages SET active=0,revision=revision+1');assert.deepEqual((await f.client.offers()).offers,[]);});
test('catalog larger than 32 fails rather than returning a silent partial list',async t=>{const f=await portalFixture(t);for(let i=0;i<32;i++)f.payment.addPackage({tier:'tier_'+i});await f.login();await assert.rejects(f.client.offers());});
test('revoked reader grant cannot list offers',async t=>{const f=await portalFixture(t);await f.login();f.payment.db.sql.exec("UPDATE pa_checkout_grants SET enabled=0,revision=revision+1 WHERE capability='read'");await assert.rejects(f.client.offers());});
test('offers endpoint rejects caller supplied club query',async t=>{const f=await portalFixture(t);const {s}=await f.browserLogin();const res=await f.http('/v1/browser/membership/offers?clubId=25',{sessionCookie:s.sessionCookie,sessionId:s.view.sessionId});assert.equal(res.status,404);});
const now=1900000000000,a={clubId:24,userId:'10000000-0000-4000-8000-000000000001'};
const valid=()=>({schemaVersion:1,...a,observedAt:now,preparationOnly:true,offers:[{tier:'gold',amount:500,currency:'RWF',country:'RW'}]});
for(const [name,mutate] of Object.entries({wrongClub:v=>v.clubId=25,wrongUser:v=>v.userId='other',stale:v=>v.observedAt=now-10001,
 duplicate:v=>v.offers.push({...v.offers[0]}),extraField:v=>v.offers[0].recipient='private',zero:v=>v.offers[0].amount=0,
 float:v=>v.offers[0].amount=0.5,unsafe:v=>v.offers[0].amount=2147483648,badCurrency:v=>v.offers[0].currency='rwf',badTier:v=>v.offers[0].tier='../gold'})){
 test('offer projection rejects '+name,()=>{const v=valid();mutate(v);assert.throws(()=>projectOffers(v,a,now));});
}
