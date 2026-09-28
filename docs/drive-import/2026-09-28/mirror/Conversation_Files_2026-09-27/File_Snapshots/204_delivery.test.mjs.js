import test from 'node:test';import assert from 'node:assert/strict';
import {fixture} from './fixture.mjs';
import {AuthenticationCodeDeliveryService} from '../src/service.mjs';
const use=(name,fn)=>test(name,async()=>{const f=fixture();try{await fn(f);}finally{f.close();}});
const count=f=>f.calls.filter(c=>c.init.method==='POST').length;
const row=f=>f.db.sql.prepare('SELECT * FROM delivery_dispatches').get();
use('matching provider acceptance is persisted before acknowledgement',async f=>{
 const r=await f.service.deliver(f.input);assert.deepEqual(r,{accepted:true,challengeId:f.input.challengeId});assert.equal(count(f),1);assert.equal(row(f).state,'accepted');
});
use('payload uses identical code in body and copy-code button',async f=>{
 await f.service.deliver(f.input);const c=f.calls[1],p=JSON.parse(c.init.body);
 assert.equal(c.url,'https://graph.facebook.com/v99.0/100000000000001/messages');assert.equal(c.init.redirect,'error');
 assert.equal(p.to,f.input.phone.slice(1));assert.equal(p.template.components[0].parameters[0].text,'012345');
 assert.deepEqual(p.template.components[1],{type:'button',sub_type:'url',index:'0',parameters:[{type:'text',text:'012345'}]});
 assert.ok(c.init.signal.aborted);assert.equal(p.template.language.code,'en_US');
});
use('completed duplicate does not make another provider read or write',async f=>{
 const a=await f.service.deliver(f.input),b=await f.service.deliver(f.input);assert.deepEqual(a,b);assert.equal(f.calls.length,2);
});
use('parallel duplicates produce one outbound POST',async f=>{
 const r=await Promise.all(Array.from({length:8},()=>f.service.deliver(f.input)));assert.equal(count(f),1);assert.equal(r.filter(x=>x.accepted).length>=1,true);
});
for(const [key,value] of [['code','111111'],['phone','+250700000009'],['expiresAt',Date.UTC(2026,8,26,13,4)]]){
 use(`same challenge with changed ${key} conflicts`,async f=>{await f.service.deliver(f.input);await assert.rejects(f.service.deliver({...f.input,[key]:value}),/dispatch_conflict/);assert.equal(count(f),1);});
}
use('same challenge cannot be reused across two mapped clubs',async f=>{
 f.env.DELIVERY_ROUTES_JSON=JSON.stringify([f.route,{...f.route,clubId:44}]);await f.service.deliver(f.input);
 await assert.rejects(f.service.deliver({...f.input,clubId:44}),/dispatch_conflict/);assert.equal(count(f),1);
});
use('configuration change cannot resend a previously accepted challenge',async f=>{
 await f.service.deliver(f.input);f.env.DELIVERY_ROUTES_JSON=JSON.stringify([{...f.route,templateName:'new_reviewed_name'}]);
 await assert.rejects(f.service.deliver(f.input),/dispatch_conflict/);assert.equal(count(f),1);
});
for(const [key,value] of [['extra','bad'],['clubId','24'],['clubId',-1],['phone','250700000001'],['phone','+2507abc'],['code',123456],['code','１２３４５６'],['code','12345'],['channel','sms'],['challengeId','not-uuid'],['expiresAt',0],['expiresAt',Date.UTC(2027,0,1)]]){
 use(`rejects malformed input ${key}=${String(value)}`,async f=>{await assert.rejects(f.service.deliver({...f.input,[key]:value}));assert.equal(f.calls.length,0);assert.equal(row(f),undefined);});
}
use('unmapped club cannot select a sender',async f=>{await assert.rejects(f.service.deliver({...f.input,clubId:44}),/unmapped_club/);assert.equal(f.calls.length,0);});
for(const key of ['DELIVERY_ENABLED','DELIVERY_DB','WA_ACCESS_TOKEN','DISPATCH_HMAC_KEY','WA_GRAPH_VERSION','DELIVERY_ROUTES_JSON']){
 use(`missing ${key} prevents any dispatch`,async f=>{delete f.env[key];await assert.rejects(f.service.deliver(f.input));assert.equal(f.calls.length,0);});
}
for(const [key,value] of [['WA_GRAPH_VERSION','latest'],['WA_GRAPH_VERSION','v24.0/../../attacker'],['DISPATCH_HMAC_KEY','0'.repeat(64)],['WA_ACCESS_TOKEN','bad\r\ntoken']]){
 use(`unsafe configuration ${key} rejected`,async f=>{f.env[key]=value;await assert.rejects(f.service.deliver(f.input));assert.equal(f.calls.length,0);});
}
for(const [key,value] of [['phoneNumberId','https://evil.example'],['language','fr'],['templateName','../anything'],['reviewExpiresAt',0]]){
 use(`unsafe route ${key} rejected`,async f=>{f.env.DELIVERY_ROUTES_JSON=JSON.stringify([{...f.route,[key]:value}]);await assert.rejects(f.service.deliver(f.input));assert.equal(f.calls.length,0);});
}
use('duplicate club routes rejected',async f=>{f.env.DELIVERY_ROUTES_JSON=JSON.stringify([f.route,f.route]);await assert.rejects(f.service.deliver(f.input));});
for(const [key,value] of [['status','PAUSED'],['status','REJECTED'],['category','MARKETING'],['category','UTILITY'],['language','en_GB'],['name','other_template'],['id','999999']]){
 use(`provider template ${key} mismatch denies POST`,async f=>{f.override(async()=>Response.json({...f.template(),[key]:value}));assert.equal((await f.service.deliver(f.input)).accepted,false);assert.equal(count(f),0);assert.equal(row(f).state,'rejected');});
}
use('provider template missing status denies POST',async f=>{f.override(async()=>{const t=f.template();delete t.status;return Response.json(t);});assert.equal((await f.service.deliver(f.input)).accepted,false);assert.equal(count(f),0);});
for(const status of [400,401,403,404,429,500,503,302]){
 use(`provider send HTTP ${status} is not acceptance and never retries`,async f=>{
  f.override(async(_u,i)=>i.method==='GET'?Response.json(f.template()):new Response('sensitive-provider-body',{status}));
  assert.equal((await f.service.deliver(f.input)).accepted,false);assert.equal((await f.service.deliver(f.input)).accepted,false);assert.equal(count(f),1);
  assert.equal(row(f).state,status>=400&&status<500?'rejected':'unknown');assert.ok(!JSON.stringify(row(f)).includes('sensitive'));
 });
}
for(const [name,change] of [
 ['wrong recipient',r=>{r.contacts[0].wa_id='250700000009';}],['missing contacts',r=>{delete r.contacts;}],
 ['missing message',r=>{r.messages=[];}],['multiple messages',r=>{r.messages.push({...r.messages[0]});}],
 ['wrong product',r=>{r.messaging_product='sms';}],['malformed id',r=>{r.messages[0].id='random';}],
 ['quality hold',r=>{r.messages[0].message_status='held_for_quality_assessment';}],['error and success',r=>{r.error={code:42};}]
]){
 use(`${name} never authenticates acceptance`,async f=>{f.override(async(_u,i)=>{if(i.method==='GET')return Response.json(f.template());const r=f.success();change(r);return Response.json(r);});assert.equal((await f.service.deliver(f.input)).accepted,false);assert.equal(row(f).state,'unknown');assert.equal(count(f),1);});
}
use('legacy response without optional message_status still correlates acceptance',async f=>{f.override(async(_u,i)=>{if(i.method==='GET')return Response.json(f.template());const r=f.success();delete r.messages[0].message_status;return Response.json(r);});assert.equal((await f.service.deliver(f.input)).accepted,true);});
use('send network exception is sanitized, uncertain and not retried',async f=>{f.override(async(_u,i)=>{if(i.method==='GET')return Response.json(f.template());throw new Error('phone '+f.input.phone+' token '+f.env.WA_ACCESS_TOKEN);});assert.equal((await f.service.deliver(f.input)).accepted,false);await f.service.deliver(f.input);assert.equal(count(f),1);assert.equal(row(f).reason,'provider_unreachable');});
use('oversized provider response is rejected without storing body',async f=>{f.override(async()=>Response.json({blob:'x'.repeat(17000)}));assert.equal((await f.service.deliver(f.input)).accepted,false);assert.equal(row(f).reason,'invalid_provider_response');assert.equal(count(f),0);});
use('malformed UTF8 and JSON fail closed',async f=>{f.override(async()=>new Response(new Uint8Array([0xff,0xfe]),{headers:{'content-type':'application/json'}}));assert.equal((await f.service.deliver(f.input)).accepted,false);});
use('HTML status 200 fails closed',async f=>{f.override(async()=>new Response('<h1>Access denied</h1>',{headers:{'content-type':'text/html'}}));assert.equal((await f.service.deliver(f.input)).accepted,false);assert.equal(count(f),0);});
use('stalled preflight hits deadline and never sends later',async f=>{
 let resolve;f.override(()=>new Promise(r=>{resolve=r;}));const s=new AuthenticationCodeDeliveryService(f.env,{clock:f.now,fetcher:f.fetcher,deadlineMs:20});
 assert.equal((await s.deliver(f.input)).accepted,false);assert.equal(row(f).reason,'provider_timeout');resolve(Response.json(f.template()));await new Promise(r=>setTimeout(r,15));assert.equal(count(f),0);
});
use('stalled send is unknown and cannot be automatically repeated',async f=>{
 let resolve;f.override(async(_u,i)=>i.method==='GET'?Response.json(f.template()):new Promise(r=>{resolve=r;}));
 const s=new AuthenticationCodeDeliveryService(f.env,{clock:f.now,fetcher:f.fetcher,deadlineMs:20});assert.equal((await s.deliver(f.input)).accepted,false);
 resolve(Response.json(f.success()));await new Promise(r=>setTimeout(r,15));assert.equal((await s.deliver(f.input)).accepted,false);assert.equal(count(f),1);assert.equal(row(f).state,'unknown');
});
use('code too close to expiry never enters outbound send',async f=>{f.input.expiresAt=f.now()+14000;assert.equal((await f.service.deliver(f.input)).accepted,false);assert.equal(count(f),0);assert.equal(row(f).reason,'too_late');});
use('expiry during template preflight prevents dispatch',async f=>{f.override(async()=>{f.advance(295000);return Response.json(f.template());});assert.equal((await f.service.deliver(f.input)).accepted,false);assert.equal(count(f),0);});
use('disabled switch during preflight blocks send',async f=>{f.override(async()=>{f.env.DELIVERY_ENABLED='false';return Response.json(f.template());});assert.equal((await f.service.deliver(f.input)).accepted,false);assert.equal(count(f),0);});
use('route change during preflight blocks send',async f=>{f.override(async()=>{f.env.DELIVERY_ROUTES_JSON=JSON.stringify([{...f.route,phoneNumberId:'222222222'}]);return Response.json(f.template());});assert.equal((await f.service.deliver(f.input)).accepted,false);assert.equal(count(f),0);});
use('request object mutation cannot change reserved payload',async f=>{const old=f.input.phone;f.override(async(_u,i)=>{if(i.method==='GET'){f.input.phone='+250700000009';return Response.json(f.template());}return Response.json(f.success({...f.input,phone:old}));});assert.equal((await f.service.deliver(f.input)).accepted,true);assert.equal(JSON.parse(f.calls[1].init.body).to,old.slice(1));});
use('pre-claim database failure results in zero provider calls',async f=>{f.db.failInsert=true;await assert.rejects(f.service.deliver(f.input));assert.equal(f.calls.length,0);});
use('claim committed but response lost blocks all later sends',async f=>{f.db.loseInsert=true;await assert.rejects(f.service.deliver(f.input));assert.equal((await f.service.deliver(f.input)).accepted,false);assert.equal(f.calls.length,0);});
use('receipt write failure never acknowledges provider acceptance',async f=>{f.db.failUpdate=true;await assert.rejects(f.service.deliver(f.input));f.db.failUpdate=false;assert.equal((await f.service.deliver(f.input)).accepted,false);assert.equal(count(f),1);assert.equal(row(f).state,'reserved');});
use('lost receipt-write response recovers existing acceptance with no new call',async f=>{f.db.loseUpdate=true;await assert.rejects(f.service.deliver(f.input));assert.equal((await f.service.deliver(f.input)).accepted,true);assert.equal(count(f),1);});
use('same provider message identifier cannot confirm two challenges',async f=>{await f.service.deliver(f.input);await assert.rejects(f.service.deliver({...f.input,challengeId:crypto.randomUUID()}));assert.equal(f.db.sql.prepare("SELECT count(*) n FROM delivery_dispatches WHERE state='accepted'").get().n,1);});
use('dispatch database contains no code, phone or token',async f=>{await f.service.deliver(f.input);const body=JSON.stringify(row(f));for(const secret of [f.input.phone,f.input.code,f.env.WA_ACCESS_TOKEN,f.env.DISPATCH_HMAC_KEY])assert.ok(!body.includes(secret));assert.equal(row(f).request_commitment.length,64);});
use('final receipt and deduplication tombstone cannot be edited or deleted',async f=>{await f.service.deliver(f.input);assert.throws(()=>f.db.sql.exec("UPDATE delivery_dispatches SET state='reserved',provider_message_id=NULL,completed_at=NULL"),/immutable/);assert.throws(()=>f.db.sql.exec('DELETE FROM delivery_dispatches'),/retain/);});
