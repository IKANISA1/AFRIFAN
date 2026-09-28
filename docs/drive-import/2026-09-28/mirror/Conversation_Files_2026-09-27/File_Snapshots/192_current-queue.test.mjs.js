import {test} from 'node:test';
import assert from 'node:assert/strict';
import {fixture as authFixture} from '../../supporter-auth/tests/support/fixture.mjs';
import {dispatchOtp} from '../../supporter-auth/src/delivery.mjs';
import {sendPrivateWhatsAppOtp} from '../../supporter-auth/src/private-delivery-sender.mjs';
import {fixture as deliveryFixture} from './fixture.mjs';
function current(t){
 const a=authFixture(t),d=deliveryFixture();t.after(()=>d.close());
 d.advance(a.clock.now-d.now());d.route.templateName='synthetic_auth';d.route.reviewExpiresAt=d.now()+86400000;
 d.env.DELIVERY_ROUTES_JSON=JSON.stringify([d.route]);
 a.env.AUTH_DELIVERY_MODE='private-deduplicated';
 a.env.OTP_DELIVERY={deliverWithReceipt:input=>d.service.deliverWithReceipt(input)};
 const drain=()=>dispatchOtp(a.env,{clock:()=>a.clock.now});
 return {a,d,drain,advance(ms){a.clock.now+=ms;d.advance(ms);},posts:()=>d.calls.filter(c=>c.init.method==='POST').length};
}
test('current queued ten-minute code reaches approved private adapter with exact lineage',async t=>{
 const f=current(t),c=await f.a.issue();assert.equal(c.expiresAt-f.a.clock.now,600000);
 assert.deepEqual(await f.drain(),{disabled:false,accepted:1,failed:0});assert.equal(f.posts(),1);
 const q=f.a.sql('SELECT * FROM auth_challenges')[0];assert.equal(q.delivery_state,'accepted');assert.equal(q.delivery_cipher,null);
 assert.equal(q.provider_message_id,'wamid.SYNTHETIC');assert.equal(f.d.db.sql.prepare('SELECT challenge_id FROM delivery_dispatches').get().challenge_id,c.challengeId);
 const body=JSON.parse(f.d.calls.find(x=>x.init.method==='POST').init.body);assert.equal(body.template.components[0].parameters[0].text,c.code);
});
test('parallel current queue drains produce one lease and one external submission',async t=>{
 const f=current(t);await f.a.issue();await Promise.all([f.drain(),f.drain(),f.drain()]);assert.equal(f.posts(),1);
});
test('unknown provider outcome is not resent by existing three-attempt queue',async t=>{
 const f=current(t);await f.a.issue();f.d.override(async(_url,init)=>{if(init.method==='GET')return Response.json(f.d.template());throw Error('response lost');});
 for(let i=0;i<3;i++){const r=await f.drain();assert.equal(r.failed,1);f.advance(30001);}
 assert.equal(f.posts(),1);assert.equal(f.a.sql('SELECT delivery_state FROM auth_challenges')[0].delivery_state,'failed');
 assert.equal(f.d.db.sql.prepare('SELECT state FROM delivery_dispatches').get().state,'unknown');
});
test('auth receipt-write failure reuses known provider receipt without another message',async t=>{
 const f=current(t);await f.a.issue();const original=f.a.db.prepare.bind(f.a.db);let once=true;
 f.a.db.prepare=sql=>{const st=original(sql);if(sql.includes("delivery_state='accepted'")){const run=st.run;st.run=async function(){if(once){once=false;throw Error('lost auth write');}return run.call(this);};}return st;};
 assert.equal((await f.drain()).failed,1);f.advance(30001);assert.equal((await f.drain()).accepted,1);assert.equal(f.posts(),1);
 assert.equal(f.a.sql('SELECT provider_message_id FROM auth_challenges')[0].provider_message_id,'wamid.SYNTHETIC');
});
test('missing private binding cannot fall back to direct legacy delivery or consume lease',async t=>{
 const f=current(t);await f.a.issue();delete f.a.env.OTP_DELIVERY;
 await assert.rejects(f.drain(),/private_delivery_unavailable/);assert.equal(f.posts(),0);assert.equal(f.a.sql('SELECT delivery_attempts FROM auth_challenges')[0].delivery_attempts,0);
});
test('unknown delivery mode is rejected before any lease is taken',async t=>{
 const f=current(t);await f.a.issue();f.a.env.AUTH_DELIVERY_MODE='typo';await assert.rejects(f.drain(),/invalid_delivery_mode/);assert.equal(f.a.sql('SELECT delivery_attempts FROM auth_challenges')[0].delivery_attempts,0);
});
test('explicit private mode does not change omitted-mode legacy sender',async t=>{
 const f=current(t);delete f.a.env.AUTH_DELIVERY_MODE;await f.a.issue();let n=0;
 const result=await dispatchOtp(f.a.env,{clock:()=>f.a.clock.now,sender:async()=>{n++;return {accepted:true,messageId:'wamid.legacy-test'};}});
 assert.equal(result.accepted,1);assert.equal(n,1);assert.equal(f.posts(),0);
});
test('current server template mismatch is rejected before any provider request',async t=>{
 const f=current(t);await f.a.issue();f.d.route.templateName='different_template';f.d.env.DELIVERY_ROUTES_JSON=JSON.stringify([f.d.route]);
 assert.equal((await f.drain()).failed,1);assert.equal(f.d.calls.length,0);
});
test('disabling current club keeps queued code unsent',async t=>{
 const f=current(t);await f.a.issue();f.a.db.sqlite.exec('UPDATE auth_clubs SET enabled=0 WHERE club_id=24');assert.equal((await f.drain()).accepted,0);assert.equal(f.posts(),0);
});
test('binding failure returns safe error and never calls legacy provider',async t=>{
 const f=current(t);await f.a.issue();f.a.env.OTP_DELIVERY={async deliverWithReceipt(){throw Error('secret provider body');}};
 assert.equal((await f.drain()).failed,1);assert.equal(f.posts(),0);
});
for(const result of [{accepted:false},{accepted:true,challengeId:'wrong',messageId:'wamid.x'},
 {accepted:true,messageId:'wamid.x'},{accepted:true,challengeId:'same',messageId:'bad'},
 {accepted:true,challengeId:'same',messageId:'wamid.'+'x'.repeat(260)}]) {
 test('private sender rejects uncorrelated or malformed receipt '+JSON.stringify(result).slice(0,70),async()=>{
  await assert.rejects(sendPrivateWhatsAppOtp({AUTH_SERVICE_ENABLED:'true',AUTH_DELIVERY_ENABLED:'true',AUTH_DELIVERY_MODE:'private-deduplicated',OTP_DELIVERY:{async deliverWithReceipt(){return result;}}},
  {challengeId:'same',clubId:24,phone:'+250700000001',code:'123456',expiresAt:Date.now()+60000,template:'synthetic_auth'}),/private_delivery_unconfirmed/);
 });
}
for(const variable of ['AUTH_SERVICE_ENABLED','AUTH_DELIVERY_ENABLED','AUTH_DELIVERY_MODE'])test('private shim fails closed for '+variable,async()=>{
 const env={AUTH_SERVICE_ENABLED:'true',AUTH_DELIVERY_ENABLED:'true',AUTH_DELIVERY_MODE:'private-deduplicated',OTP_DELIVERY:{deliverWithReceipt(){assert.fail();}}};delete env[variable];
 await assert.rejects(sendPrivateWhatsAppOtp(env,{}),/private_delivery_disabled/);
});
test('private receipt method returns durable id on same-operation replay',async()=>{
 const f=deliveryFixture();try{const input={...f.input,template:f.route.templateName};const first=await f.service.deliverWithReceipt(input),second=await f.service.deliverWithReceipt(input);
 assert.deepEqual(first,second);assert.equal(first.messageId,'wamid.SYNTHETIC');assert.equal(f.calls.filter(x=>x.init.method==='POST').length,1);}finally{f.close();}
});
test('receipt method will not accept an extra actor or altered template',async()=>{
 const f=deliveryFixture();try{await assert.rejects(f.service.deliverWithReceipt({...f.input,template:f.route.templateName,actor:'admin'}));
 await assert.rejects(f.service.deliverWithReceipt({...f.input,template:'other'}));assert.equal(f.calls.length,0);}finally{f.close();}
});
test('metadata changes cannot reinterpret an already accepted dispatch receipt',async()=>{
 const f=deliveryFixture();try{await f.service.deliver(f.input);f.route.phoneNumberId='100000000000009';f.env.DELIVERY_ROUTES_JSON=JSON.stringify([f.route]);
 await assert.rejects(f.service.deliver(f.input),/dispatch_conflict/);assert.equal(f.calls.filter(c=>c.init.method==='POST').length,1);}finally{f.close();}
});
test('message identifier longer than current auth permits is never accepted',async()=>{
 const f=deliveryFixture();try{f.override(async(_u,o)=>Response.json(o.method==='GET'?f.template():{...f.success(),messages:[{id:'wamid.'+'x'.repeat(251)}]}));
 assert.equal((await f.service.deliver(f.input)).accepted,false);}finally{f.close();}
});
test('ten-minute ceiling rejects excessively long challenge validity',async()=>{
 const f=deliveryFixture();try{await assert.rejects(f.service.deliverWithReceipt({...f.input,expiresAt:f.now()+600001,template:f.route.templateName}),/invalid_expiry/);assert.equal(f.calls.length,0);}finally{f.close();}
});
test('accepted message does not create membership, account or session in queued auth',async t=>{
 const f=current(t);await f.a.issue();await f.drain();assert.equal(f.a.count('auth_accounts'),0);assert.equal(f.a.count('auth_sessions'),0);
});
