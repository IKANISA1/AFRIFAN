import test from 'node:test';import assert from 'node:assert/strict';
import {checkoutFixture,ids,checkoutPrincipal,readPrincipal,packageId,routeId} from './checkout-fixture.mjs';
import {MembershipCheckoutService} from '../src/checkout-service.mjs';
async function run(fn){const f=checkoutFixture();try{await fn(f);}finally{f.close();}}
const invalid=[['chosen price',{amount:1}],['chosen recipient',{recipient:'999999'}],['chosen principal',{principalId:checkoutPrincipal}],['chosen order',{orderId:crypto.randomUUID()}],['bad request',{requestId:'x'}],['bad owner',{userId:'x'}],['zero club',{clubId:0}],['fraction club',{clubId:24.5}],['string club',{clubId:'24'}],['empty tier',{tier:''}],['oversized tier',{tier:'a'.repeat(65)}],['markup tier',{tier:'<script>'}],['query tier',{tier:"gold' OR 1=1"}]];
for(const [name,change] of invalid)test(`prepare rejects ${name}`,()=>run(async f=>{await assert.rejects(f.checkout.prepare(f.request(change)));assert.equal(f.count('pa_checkout_requests'),0);assert.equal(f.orderFor({checkout:{orderId:f.order.order_id}}).state,'pending');}));
for(const [name,mutation] of [
 ['principal disabled',`UPDATE pa_principals SET enabled=0 WHERE principal_id='${checkoutPrincipal}'`],
 ['principal expired',`UPDATE pa_principals SET expires_at_ms=1 WHERE principal_id='${checkoutPrincipal}'`],
 ['grant disabled',`UPDATE pa_checkout_grants SET enabled=0 WHERE principal_id='${checkoutPrincipal}' AND club_id=24`],
 ['subject disabled',`UPDATE pa_subjects SET enabled=0 WHERE club_id=24`],
 ['club disabled',`UPDATE pa_clubs SET enabled=0 WHERE club_id=24`],
 ['checkout disabled','UPDATE pa_checkout_settings SET enabled=0'],
 ['catalog unreconciled','UPDATE pa_checkout_settings SET catalog_reconciled=0'],
 ['missing catalog evidence',"UPDATE pa_checkout_settings SET evidence_ref=''"],
 ['writer disabled',"UPDATE pa_settings SET writer_mode='disabled'"],
 ['history incomplete','UPDATE pa_settings SET historical_claims_verified=0'],
 ['source unreconciled','UPDATE pa_settings SET source_reconciled=0']]){
 test(`authority rejects ${name}`,()=>run(async f=>{f.db.sql.exec(mutation);await assert.rejects(f.checkout.prepare(f.request()),{code:'checkout_permission_denied'});assert.equal(f.count('pa_checkout_requests'),0);}));
 test(`commit rejects concurrent ${name}`,()=>run(async f=>{f.db.beforeBatch=()=>f.db.sql.exec(mutation);await assert.rejects(f.checkout.prepare(f.request()),{code:'checkout_permission_denied'});assert.equal(f.count('pa_checkout_order_details'),0);assert.equal(f.db.sql.prepare('SELECT state FROM pa_orders WHERE order_id=?').get(f.order.order_id).state,'pending');}));
}
for(const [name,mutation] of [
 ['price','UPDATE pa_checkout_packages SET annual_price=12000'],
 ['package selection',`INSERT INTO pa_checkout_packages SELECT '50000000-0000-4000-8000-000000000001',club_id,partner_id,tier,annual_price,price,-1,active,revision,source_sha256 FROM pa_checkout_packages`],
 ['receiver','UPDATE pa_receivers SET active=0'],
 ['route','UPDATE pa_checkout_routes SET active=0'],
 ['dialer',"UPDATE pa_checkout_clubs SET ussd_template='*999*{amount}*{code}#'"],
 ['package revoke reenabling','UPDATE pa_checkout_packages SET active=0;UPDATE pa_checkout_packages SET active=1']])
 test(`commit rejects changed ${name}`,()=>run(async f=>{f.db.beforeBatch=()=>f.db.sql.exec(mutation);await assert.rejects(f.checkout.prepare(f.request()),{code:'checkout_offer_changed'});assert.equal(f.count('pa_checkout_requests'),0);}));
test('revoked and reenabled principal does not pass captured revisions',()=>run(async f=>{f.db.beforeBatch=()=>f.db.sql.exec(`UPDATE pa_principals SET enabled=0 WHERE principal_id='${checkoutPrincipal}';UPDATE pa_principals SET enabled=1 WHERE principal_id='${checkoutPrincipal}'`);await assert.rejects(f.checkout.prepare(f.request()),{code:'checkout_permission_denied'});}));
for(const table of ['pa_orders','pa_checkout_order_details','pa_checkout_results','pa_checkout_audit'])
 test(`failure inserting ${table} rolls back cancellation and entire checkout`,()=>run(async f=>{
  f.db.sql.exec(`CREATE TRIGGER fail_checkout BEFORE INSERT ON ${table} BEGIN SELECT RAISE(ABORT,'sensitive SQL must not leak'); END;`);
  await assert.rejects(f.checkout.prepare(f.request()),{code:'checkout_unavailable'});
  assert.equal(f.count('pa_checkout_requests'),0);assert.equal(f.count('pa_checkout_audit'),0);
  assert.equal(f.db.sql.prepare('SELECT state FROM pa_orders WHERE order_id=?').get(f.order.order_id).state,'pending');
 }));
test('failure cancelling old order rolls back request',()=>run(async f=>{f.db.sql.exec("CREATE TRIGGER fail_cancel BEFORE UPDATE ON pa_orders BEGIN SELECT RAISE(ABORT,'cancel failed'); END;");await assert.rejects(f.checkout.prepare(f.request()));assert.equal(f.count('pa_checkout_requests'),0);}));
test('batch injection leaves no checkout',()=>run(async f=>{f.db.failAt=0;await assert.rejects(f.checkout.prepare(f.request()));assert.equal(f.count('pa_checkout_requests'),0);}));
test('revocation inside effect cannot borrow another club grant',()=>run(async f=>{f.db.sql.exec(`CREATE TRIGGER revoke_during AFTER INSERT ON pa_checkout_order_details BEGIN UPDATE pa_checkout_grants SET enabled=0 WHERE principal_id='${checkoutPrincipal}' AND club_id=24; END;`);await assert.rejects(f.checkout.prepare(f.request()),{code:'checkout_permission_denied'});assert.equal(f.count('pa_checkout_order_details'),0);}));
test('catalog changes inside effect roll back entire order',()=>run(async f=>{f.db.sql.exec('CREATE TRIGGER mutate_during AFTER INSERT ON pa_checkout_order_details BEGIN UPDATE pa_checkout_packages SET annual_price=12000; END;');await assert.rejects(f.checkout.prepare(f.request()),{code:'checkout_unavailable'});assert.equal(f.count('pa_checkout_requests'),0);}));
for(const t of ['pa_checkout_requests','pa_checkout_order_details','pa_checkout_results','pa_checkout_audit'])
 for(const verb of ['delete','update'])test(`${t} ${verb} blocked`,()=>run(async f=>{await f.checkout.prepare(f.request());assert.throws(()=>f.db.sql.exec(verb==='delete'?`DELETE FROM ${t}`:`UPDATE ${t} SET ${t==='pa_checkout_order_details'?'ussd_code=ussd_code':'command_id=command_id'}`),/checkout_immutable_history/);}));
test('prepare principal cannot use read permission automatically',()=>run(async f=>{const a=await f.checkout.prepare(f.request());await assert.rejects(f.checkout.read(f.readRequest(a)),{code:'checkout_permission_denied'});}));
test('read-only principal cannot prepare',()=>run(async f=>{await assert.rejects(f.checkoutReader.prepare(f.request()),{code:'checkout_permission_denied'});}));
test('existing allocator principal does not gain checkout authority',()=>run(async f=>{const x=new MembershipCheckoutService(f.env,ids.allocate);await assert.rejects(x.prepare(f.request()),{code:'checkout_permission_denied'});}));
test('wrong-club read does not leak own checkout in another club',()=>run(async f=>{const a=await f.checkout.prepare(f.request());await assert.rejects(f.checkoutReader.read({...f.readRequest(a),clubId:25}),{code:'not_found'});}));
test('other enabled user cannot read owner checkout',()=>run(async f=>{const a=await f.checkout.prepare(f.request()),u=crypto.randomUUID();f.db.sql.prepare('INSERT INTO pa_subjects VALUES(?,24,1,1)').run(u);await assert.rejects(f.checkoutReader.read({...f.readRequest(a),userId:u}),{code:'not_found'});}));
test('request recovery also needs current subject authority',()=>run(async f=>{const v=f.request();await f.checkout.prepare(v);f.db.sql.exec('UPDATE pa_subjects SET enabled=0 WHERE club_id=24');await assert.rejects(f.checkout.prepare(v),{code:'checkout_permission_denied'});}));
test('20 per-subject commands allowed; new key blocked and exact retry works',()=>run(async f=>{const v=f.request(),r=await f.checkout.prepare(v);for(let i=1;i<20;i++)await f.checkout.prepare(f.request());await assert.rejects(f.checkout.prepare(f.request()),{code:'checkout_rate_limited'});assert.deepEqual(await f.checkout.prepare(v),r);f.advance(900000);await f.checkout.prepare(f.request());assert.equal(f.count('pa_checkout_order_details'),1);}));
test('client-visible errors do not include injected SQL or raw records',()=>run(async f=>{f.db.beforeBatch=()=>{throw Error('SECRET_SQL_CREDENTIAL');};await assert.rejects(f.checkout.prepare(f.request()),e=>e.message==='checkout_unavailable');}));
