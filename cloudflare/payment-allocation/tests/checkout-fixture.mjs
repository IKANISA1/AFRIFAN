import {readFileSync} from 'node:fs';
import {fixture as baseFixture,ids,NOW} from './fixture.mjs';
import {NOW_SQL} from '../src/policy.mjs';
import {MembershipCheckoutService} from '../src/checkout-service.mjs';
export {ids,NOW};
export const checkoutPrincipal='10000000-0000-4000-8000-000000000006';
export const readPrincipal='10000000-0000-4000-8000-000000000007';
export const packageId='60000000-0000-4000-8000-000000000001';
export const routeId='70000000-0000-4000-8000-000000000001';
export function checkoutFixture(){
 const f=baseFixture();
 f.db.sql.exec(readFileSync(new URL('../migrations/0002_membership_checkout.sql',import.meta.url),'utf8').replaceAll(NOW_SQL,'test_now_ms()'));
 f.db.sql.exec(readFileSync(new URL('../migrations/0005_membership_history_read_index.sql',import.meta.url),'utf8'));
 f.env.MEMBERSHIP_CHECKOUT_ENABLED='true';
 f.db.sql.exec("UPDATE pa_checkout_settings SET enabled=1,catalog_reconciled=1,evidence_ref='SYNTHETIC-CATALOG';");
 for(const p of [checkoutPrincipal,readPrincipal]) f.db.sql.prepare('INSERT INTO pa_principals VALUES(?,1,1,?)').run(p,NOW+7*86400000);
 for(const c of [24,25]){
  f.db.sql.prepare('INSERT INTO pa_checkout_grants VALUES(?,?,?,1,1)').run(checkoutPrincipal,c,'prepare');
  f.db.sql.prepare('INSERT INTO pa_checkout_grants VALUES(?,?,?,1,1)').run(readPrincipal,c,'read');
  f.db.sql.prepare('INSERT INTO pa_checkout_clubs(club_id,ussd_template,active,source_sha256) VALUES(?,?,1,?)').run(c,'*182*8*1*{recipient}*{amount}#','ab'.repeat(32));
 }
 const addPackage=(patch={})=>{
  const r={package_id:crypto.randomUUID(),club_id:24,partner_id:ids.partner,tier:'gold',annual_price:10000,price:1000,sort_order:0,active:1,revision:1,source_sha256:'bc'.repeat(32),...patch};
  f.db.sql.prepare(`INSERT INTO pa_checkout_packages(${Object.keys(r).join(',')}) VALUES(${Object.keys(r).map(()=>'?').join(',')})`).run(...Object.values(r));return r;
 };
 const addRoute=(patch={})=>{
  const r={route_id:crypto.randomUUID(),club_id:24,partner_id:ids.partner,provider:'mtn_rwanda',country:'RW',recipient:'123456',active:1,revision:1,source_sha256:'cd'.repeat(32),...patch};
  f.db.sql.prepare(`INSERT INTO pa_checkout_routes(${Object.keys(r).join(',')}) VALUES(${Object.keys(r).map(()=>'?').join(',')})`).run(...Object.values(r));return r;
 };
 const addReceiver=(patch={})=>{
  const r={receiver_id:crypto.randomUUID(),club_id:24,partner_id:ids.partner,provider:'mtn_rwanda',country:'RW',currency:'RWF',recipient:'123456',active:1,revision:1,...patch};
  f.db.sql.prepare(`INSERT INTO pa_receivers(${Object.keys(r).join(',')}) VALUES(${Object.keys(r).map(()=>'?').join(',')})`).run(...Object.values(r));return r;
 };
 addPackage({package_id:packageId});addRoute({route_id:routeId});
 const checkout=new MembershipCheckoutService(f.env,checkoutPrincipal),checkoutReader=new MembershipCheckoutService(f.env,readPrincipal);
 const request=(patch={})=>({requestId:crypto.randomUUID(),clubId:24,userId:ids.user,tier:'gold',...patch});
 const readRequest=r=>({clubId:r.checkout.clubId,userId:r.checkout.userId,orderId:r.checkout.orderId});
 return {...f,checkout,checkoutReader,request,readRequest,addPackage,addRoute,addReceiver,
  orderFor:r=>f.db.sql.prepare('SELECT * FROM pa_orders WHERE order_id=?').get(r.checkout.orderId),
  effects:()=>Object.fromEntries(['pa_checkout_requests','pa_checkout_order_details','pa_checkout_results','pa_checkout_audit','pa_allocations','pa_memberships','pa_ledger','pa_outbox'].map(t=>[t,f.count(t)]))};
}
