import test from 'node:test';import assert from 'node:assert/strict';
import {checkoutFixture,packageId,routeId,ids} from './checkout-fixture.mjs';
async function run(fn){const f=checkoutFixture();try{await fn(f);}finally{f.close();}}
for(const [annual,price,expected] of [[10000,500,10000],[0,500,500],[null,500,500],[1,null,1],[2147483647,1,2147483647]])
 test(`price selection annual=${annual} price=${price}`,()=>run(async f=>{f.db.sql.prepare('UPDATE pa_checkout_packages SET annual_price=?,price=?').run(annual,price);assert.equal((await f.checkout.prepare(f.request())).checkout.amount,expected);}));
for(const [annual,price] of [[0,0],[null,0],[null,null]])test(`unpayable price ${annual}/${price} fails`,()=>run(async f=>{f.db.sql.prepare('UPDATE pa_checkout_packages SET annual_price=?,price=?').run(annual,price);await assert.rejects(f.checkout.prepare(f.request()));assert.equal(f.count('pa_checkout_requests'),0);}));
for(const price of [-1,0.2,2147483648])test(`invalid stored amount ${price} rejected by schema`,()=>run(f=>{assert.throws(()=>f.db.sql.prepare('UPDATE pa_checkout_packages SET annual_price=?').run(price));}));
test('source sort then package UUID selection',()=>run(async f=>{const p=f.addPackage({sort_order:-1,annual_price:9000});const r=await f.checkout.prepare(f.request());assert.equal(r.checkout.packageId,p.package_id);assert.equal(r.checkout.amount,9000);}));
test('invalid first package never falls back to expensive later package',()=>run(async f=>{f.db.sql.exec('UPDATE pa_checkout_packages SET annual_price=0,price=0');f.addPackage({sort_order:1,annual_price:20000});await assert.rejects(f.checkout.prepare(f.request()));}));
test('first route without receiver skipped as source requires joined receiver',()=>run(async f=>{f.addRoute({route_id:'50000000-0000-4000-8000-000000000001',recipient:'999999'});const r=await f.checkout.prepare(f.request());assert.equal(r.checkout.recipient,'123456');}));
test('ambiguous active receiver rejected rather than selected arbitrarily',()=>run(async f=>{f.addReceiver();await assert.rejects(f.checkout.prepare(f.request()));}));
test('ambiguous receiver across clubs rejected',()=>run(async f=>{f.addReceiver({club_id:25});await assert.rejects(f.checkout.prepare(f.request()));}));
for(const [name,sql] of [
 ['provider mismatch',"UPDATE pa_checkout_routes SET provider='other_provider'"],
 ['country mismatch',"UPDATE pa_checkout_routes SET country='ZM'"],
 ['currency mismatch',"UPDATE pa_receivers SET currency='USD'"],
 ['receiver wrong country',"UPDATE pa_receivers SET country='ZM'"],
 ['disabled package','UPDATE pa_checkout_packages SET active=0'],
 ['disabled dialer','UPDATE pa_checkout_clubs SET active=0'],
 ['disabled route','UPDATE pa_checkout_routes SET active=0'],
 ['disabled receiver','UPDATE pa_receivers SET active=0']])test(`catalog fails ${name}`,()=>run(async f=>{f.db.sql.exec(sql);await assert.rejects(f.checkout.prepare(f.request()));}));
for(const template of ['*123#{amount}{code}','https://malicious/{amount}/{code}','*123*{amount}*{unknown}#','*123456#','*123*{amount}#','*123*{code}#','*123*{code}*{amount}%23'])test(`reject dialer template ${template}`,()=>run(async f=>{f.db.sql.prepare('UPDATE pa_checkout_clubs SET ussd_template=?').run(template);await assert.rejects(f.checkout.prepare(f.request()));}));
for(const token of ['{recipient}','{momo}','{code}'])test(`accepted source recipient alias ${token}`,()=>run(async f=>{f.db.sql.prepare('UPDATE pa_checkout_clubs SET ussd_template=?').run(`*123*${token}*{amount}#`);assert.equal((await f.checkout.prepare(f.request())).checkout.ussdCode,'*123*123456*10000#');}));
test('route change creates distinct order; old immutable route retained',()=>run(async f=>{const a=await f.checkout.prepare(f.request());f.db.sql.exec("UPDATE pa_receivers SET recipient='654321';UPDATE pa_checkout_routes SET recipient='654321'");const b=await f.checkout.prepare(f.request());assert.equal(b.checkout.recipient,'654321');assert.equal(a.checkout.recipient,'123456');assert.equal(f.orderFor(a).state,'cancelled');}));
test('dialer change invalidates reuse even when destination and amount match',()=>run(async f=>{const a=await f.checkout.prepare(f.request());f.db.sql.exec("UPDATE pa_checkout_clubs SET ussd_template='*123*{code}*{amount}#'");const b=await f.checkout.prepare(f.request());assert.notEqual(b.checkout.orderId,a.checkout.orderId);}));
test('package metadata revision with same economic fields can reuse snapshot',()=>run(async f=>{const a=await f.checkout.prepare(f.request());f.db.sql.exec("UPDATE pa_checkout_packages SET source_sha256='"+'ef'.repeat(32)+"'");const b=await f.checkout.prepare(f.request());assert.deepEqual(b.checkout,a.checkout);assert.equal(b.reused,true);}));
test('candidate lookup has indexed package and receiver choices',()=>run(f=>{const plan=f.db.sql.prepare("EXPLAIN QUERY PLAN SELECT * FROM pa_checkout_offers WHERE club_id=24 AND tier='gold'").all().map(x=>x.detail).join('\n');assert.match(plan,/pa_checkout_packages_choice/);assert.match(plan,/pa_checkout_receiver_lookup/);}));
