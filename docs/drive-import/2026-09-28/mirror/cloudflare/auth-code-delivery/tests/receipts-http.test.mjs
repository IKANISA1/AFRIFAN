import {test} from 'node:test';
import assert from 'node:assert/strict';
import {receiptFixture,ACCOUNT} from './receipts-fixture.mjs';
import {handleReceipt,readRaw,signatureValid} from '../src/receipt-http.mjs';
const decode=r=>r.json();
test('valid signature stores provider fact, not raw message body or phone',async t=>{
 const f=receiptFixture(t);await f.tracked.deliver(f.input);const p=f.payload();p.entry[0].changes[0].value.messages=[{text:{body:'secret inbound content'},from:f.input.phone}];
 const r=await f.send(p);assert.equal(r.status,200);assert.deepEqual(await r.json(),{received:true});
 assert.equal(f.count('delivery_status_events'),1);assert.equal(f.count('delivery_status_links'),1);
 const rows=JSON.stringify(f.db.sql.prepare('SELECT * FROM delivery_status_events').all());assert(!rows.includes(f.input.phone.slice(1)));assert(!rows.includes('secret inbound'));
});
for(const sig of [null,'','sha1='+'a'.repeat(40),'sha256=bad','sha256='+'0'.repeat(64),'sha256='+'f'.repeat(64)+', sha256='+'e'.repeat(64)])
 test('missing or forged signature rejected '+String(sig).slice(0,30),async t=>{
  const f=receiptFixture(t),req=await f.signed();if(sig===null)req.headers.delete('x-hub-signature-256');else req.headers.set('x-hub-signature-256',sig);
  const r=await handleReceipt(req,f.env,{clock:f.now});assert.equal(r.status,403);assert.equal(f.count('delivery_status_events'),0);
 });
test('signature binds exact raw bytes and rejects whitespace change',async t=>{
 const f=receiptFixture(t),req=await f.signed();const headers=req.headers;
 const r=await handleReceipt(new Request(req.url,{method:'POST',headers,body:' '+JSON.stringify(f.payload())}),f.env,{clock:f.now});assert.equal(r.status,403);
});
test('valid raw whitespace is accepted without JSON reserialization before HMAC',async t=>{
 const f=receiptFixture(t);const r=await f.send(JSON.stringify(f.payload(),null,2));assert.equal(r.status,200);
});
for(const flag of ['RECEIPT_WEBHOOK_ENABLED','RECEIPT_HMAC_KEY','RECEIPT_KEY_VERSION','WA_WEBHOOK_APP_SECRET','WA_WEBHOOK_VERIFY_TOKEN','RECEIPT_ROUTES_JSON','RECEIPT_EDGE_LIMIT','DELIVERY_DB'])
 test('missing configuration fails closed '+flag,async t=>{const f=receiptFixture(t),req=await f.signed();delete f.env[flag];assert.equal((await handleReceipt(req,f.env,{clock:f.now})).status,503);});
test('send kill switch does not stop signed receipt intake',async t=>{const f=receiptFixture(t);f.env.DELIVERY_ENABLED='false';assert.equal((await f.send()).status,200);});
for(const header of [{origin:'https://hostile.example'},{cookie:'x=1'}])test('browser credential ingress is rejected '+Object.keys(header)[0],async t=>{
 const f=receiptFixture(t);assert.equal((await f.send(undefined,header)).status,403);
});
for(const suffix of ['/not-the-hook','/webhooks/whatsapp/auth-delivery/'])test('only exact path accepted '+suffix,async t=>{
 const f=receiptFixture(t);assert.equal((await handleReceipt(new Request(f.env.RECEIPT_ORIGIN+suffix),f.env)).status,404);
});
for(const method of ['PUT','DELETE','HEAD','OPTIONS'])test('unsupported verb '+method,async t=>{
 const f=receiptFixture(t);assert.equal((await handleReceipt(new Request(f.env.RECEIPT_ORIGIN+'/webhooks/whatsapp/auth-delivery',{method}),f.env)).status,405);
});
test('exact verification challenge, no store access',async t=>{
 const f=receiptFixture(t),url=new URL(f.env.RECEIPT_ORIGIN+'/webhooks/whatsapp/auth-delivery');url.search=new URLSearchParams({'hub.mode':'subscribe','hub.verify_token':f.env.WA_WEBHOOK_VERIFY_TOKEN,'hub.challenge':'123456'});
 const r=await handleReceipt(new Request(url),f.env);assert.equal(r.status,200);assert.equal(await r.text(),'123456');assert.equal(f.count('delivery_status_events'),0);
});
for(const change of ['wrong-token','duplicate-token','bad-challenge','extra-query','wrong-mode'])test('verification rejects '+change,async t=>{
 const f=receiptFixture(t),u=new URL(f.env.RECEIPT_ORIGIN+'/webhooks/whatsapp/auth-delivery');u.search=new URLSearchParams({'hub.mode':'subscribe','hub.verify_token':f.env.WA_WEBHOOK_VERIFY_TOKEN,'hub.challenge':'123'});
 if(change==='wrong-token')u.searchParams.set('hub.verify_token','wrong');if(change==='duplicate-token')u.searchParams.append('hub.verify_token',f.env.WA_WEBHOOK_VERIFY_TOKEN);
 if(change==='bad-challenge')u.searchParams.set('hub.challenge','<script>');if(change==='extra-query')u.searchParams.set('x','1');if(change==='wrong-mode')u.searchParams.set('hub.mode','other');
 assert.equal((await handleReceipt(new Request(u),f.env)).status,403);
});
for(const body of ['not json','[]','null','{}','{"object":"page","entry":[]}',new Uint8Array([0xff,0xfe])])test('signed malformed body rejected '+String(body).slice(0,35),async t=>{
 const f=receiptFixture(t);assert.equal((await f.send(body)).status,400);assert.equal(f.count('delivery_status_events'),0);
});
for(const h of [{'content-type':'text/plain'},{'content-encoding':'gzip'}])test('unsafe body transport rejected '+JSON.stringify(h),async t=>{
 const f=receiptFixture(t);assert.equal((await f.send(undefined,h)).status,415);
});
test('content length above bound rejected',async t=>{const f=receiptFixture(t);assert.equal((await f.send(undefined,{'content-length':'65537'})).status,413);});
test('actual body bound enforced even without length',async t=>{const f=receiptFixture(t);assert.equal((await f.send(' '.repeat(65537))).status,413);});
test('slow body times out without database effects',async()=>{
 const stream=new ReadableStream({start(){},cancel(){}}),req=new Request('https://x.example',{method:'POST',body:stream,duplex:'half',headers:{'content-type':'application/json'}});
 await assert.rejects(readRaw(req,5),/body_timeout/);
});
test('rate limit denied before persistence',async t=>{const f=receiptFixture(t);f.env.RECEIPT_EDGE_LIMIT={async limit(){return {success:false};}};assert.equal((await f.send()).status,429);assert.equal(f.count('delivery_status_events'),0);});
test('unknown account and sender are acknowledged without storage',async t=>{const f=receiptFixture(t),p=f.payload();p.entry[0].id='100000000000098';assert.equal((await f.send(p)).status,200);assert.equal(f.count('delivery_status_events'),0);});
test('user messages and unknown field are ignored, never forwarded',async t=>{
 const f=receiptFixture(t),p=f.payload();delete p.entry[0].changes[0].value.statuses;p.entry[0].changes[0].value.messages=[{text:{body:'Do not save'}}];
 assert.equal((await f.send(p)).status,200);assert.equal(f.count('delivery_status_events'),0);
 p.entry[0].changes[0].field='message_template_status_update';assert.equal((await f.send(p)).status,200);
});
test('unknown future status is ignored not converted to delivery',async t=>{const f=receiptFixture(t);assert.equal((await f.send(f.payload('new-status'))).status,200);assert.equal(f.count('delivery_status_events'),0);});
for(const s of [{recipient_id:'bad'},{timestamp:'-1'},{timestamp:'1e9'},{id:'invalid'},{errors:[{code:'bad',title:'SECRET'}]}])test('malformed status rejected '+JSON.stringify(s),async t=>{
 const f=receiptFixture(t);assert.equal((await f.send(f.payload('failed',s))).status,400);assert.equal(f.count('delivery_status_events'),0);
});
test('stale and far-future signed events acknowledged but not stored',async t=>{
 const f=receiptFixture(t);for(const ts of [f.now()-9*86400000,f.now()+300001])assert.equal((await f.send(f.payload('sent',{timestamp:String(Math.ceil(ts/1000))}))).status,200);
 assert.equal(f.count('delivery_status_events'),0);
});
test('event budget is per request, not per change',async t=>{
 const f=receiptFixture(t),p=f.payload();p.entry[0].changes[0].value.statuses=Array(21).fill(p.entry[0].changes[0].value.statuses[0]);assert.equal((await f.send(p)).status,413);assert.equal(f.count('delivery_status_events'),0);
});
test('unknown provider error strings are never persisted or echoed',async t=>{
 const f=receiptFixture(t),r=await f.send(f.payload('failed',{errors:[{code:131000,title:'PRIVATE_PHONE_AND_CODE',error_data:{details:'confidential'}}]}));assert.equal(r.status,200);
 const row=f.db.sql.prepare('SELECT * FROM delivery_status_events').get();assert.equal(row.error_codes_json,'[131000]');assert(!JSON.stringify(row).includes('confidential'));
});
test('database failure is safe and not acknowledged',async t=>{const f=receiptFixture(t);f.failBatchAt(0);const r=await f.send();assert.equal(r.status,503);assert.deepEqual(await r.json(),{error:'receipt_unavailable'});});
test('no public status-read path exists',async t=>{const f=receiptFixture(t);assert.equal((await handleReceipt(new Request(f.env.RECEIPT_ORIGIN+'/status/'+f.input.challengeId),f.env)).status,404);});
