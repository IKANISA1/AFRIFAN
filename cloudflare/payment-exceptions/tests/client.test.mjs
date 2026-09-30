import test,{before,after} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {spawnSync} from 'node:child_process';
import {fixture} from './fixture.mjs';
import gateway from '../../operator-api/src/index.mjs';
let PaymentCaseClient,CaseClientError,dir;
before(async()=>{
 dir=mkdtempSync(join(tmpdir(),'africlub-case-client-'));
 const result=spawnSync('tsc',['--strict','--target','ES2022','--module','NodeNext','--moduleResolution','NodeNext','--lib','ES2022,DOM','--skipLibCheck','--outDir',dir,fileURLToPath(new URL('../client.ts',import.meta.url))],{encoding:'utf8',timeout:30000});
 assert.equal(result.status,0,result.error?.message??result.stdout+result.stderr);
 ({PaymentCaseClient,CaseClientError}=await import(pathToFileURL(join(dir,'client.js')).href));
});
after(()=>{if(dir)rmSync(dir,{recursive:true,force:true});});
function setup(t,who='maker'){
 const f=fixture(t),calls=[];
 const transport=async(url,init)=>{
  calls.push({url,init});const h=new Headers(init.headers);
  if(init.method==='POST')h.set('origin',f.httpEnv.OPERATOR_API_ORIGIN); // Browser-managed Origin, never client identity.
  return gateway.fetch(new Request(url,{...init,headers:h}),f.httpEnv,f.context(who));
 };
 return {...f,calls,transport,client:new PaymentCaseClient(f.httpEnv.OPERATOR_API_ORIGIN,transport)};
}
test('strictly compiled client opens, reads, lists and pages real gateway cases',async t=>{
 const f=setup(t),i=f.command();
 const r=await f.client.command(24,i.caseId,i.operationId,0,'open',i.detail);
 assert.equal(r.currentCase.state,'open');assert.equal(r.currentCase.financialEffect,'none');
 assert.equal((await f.client.get(24,i.caseId)).caseId,i.caseId);
 assert.equal((await f.client.list(24)).cases.length,1);
 assert.equal((await f.client.history(24,i.caseId)).events.length,1);
 const p=f.calls[0].init;assert.equal(p.credentials,'same-origin');assert.equal(p.redirect,'error');assert.equal(p.cache,'no-store');
 assert.equal(JSON.parse(p.body).identity,undefined);assert.equal(p.headers.authorization,undefined);
});
test('client surfaces stale review conflict without retrying',async t=>{
 const f=setup(t),o=await f.open();const p=await f.transition(o.input.caseId,'propose');
 const checker=new PaymentCaseClient(f.httpEnv.OPERATOR_API_ORIGIN,(url,init)=>{f.calls.push({url,init});return gateway.fetch(new Request(url,{...init,headers:{...init.headers,origin:f.httpEnv.OPERATOR_API_ORIGIN}}),f.httpEnv,f.context('checker'));});
 await f.transition(o.input.caseId,'reject','checker');await f.transition(o.input.caseId,'propose');
 await assert.rejects(()=>checker.command(24,o.input.caseId,crypto.randomUUID(),p.result.currentCase.revision,'approve',{reasonCode:'review_complete',evidenceDigest:null}),e=>e.status===409&&!e.outcomeUnknown);
 assert.equal(f.calls.length,1);assert.equal(f.count(),4);
});
test('lost network acknowledgement remains uncertain and same-key retry recovers one event',async t=>{
 const f=setup(t),i=f.command();let lose=true;
 const c=new PaymentCaseClient(f.httpEnv.OPERATOR_API_ORIGIN,async(...a)=>{const response=await f.transport(...a);if(lose){lose=false;throw Error('lost response');}return response;});
 await assert.rejects(()=>c.command(24,i.caseId,i.operationId,0,'open',i.detail),e=>e.code==='transport_unavailable'&&e.outcomeUnknown);
 assert.equal(f.count(),1);assert.equal(f.calls.length,1);
 const recovered=await c.command(24,i.caseId,i.operationId,0,'open',i.detail);assert.equal(recovered.replayed,true);assert.equal(f.count(),1);
});
test('transport failure on GET is not a write outcome',async()=>{
 const c=new PaymentCaseClient('https://operator.example.invalid',async()=>{throw Error('offline');});
 await assert.rejects(()=>c.get(24,crypto.randomUUID()),e=>e.status===0&&!e.outcomeUnknown);
});
for(const origin of ['http://operator.example.invalid','https://operator.example.invalid/path','https://operator.example.invalid/?x=1','https://x:y@operator.example.invalid'])test('rejects origin '+origin,()=>assert.throws(()=>new PaymentCaseClient(origin),CaseClientError));
for(const field of ['clubId','caseId','financialEffect','referencesVerified','state','revision','proposalDigest'])test('client rejects incompatible case response '+field,async t=>{
 const f=setup(t),o=await f.open();const data={...o.result.currentCase};
 data[field]={clubId:26,caseId:crypto.randomUUID(),financialEffect:'refund',referencesVerified:true,state:'paid',revision:0,proposalDigest:'bad'}[field];
 const c=new PaymentCaseClient(f.httpEnv.OPERATOR_API_ORIGIN,async()=>Response.json({schemaVersion:1,requestId:crypto.randomUUID(),data}));
 await assert.rejects(()=>c.get(24,o.input.caseId),e=>e.code==='invalid_response');
});
test('client rejects history events from another club',async t=>{
 const f=setup(t),o=await f.open();const c=new PaymentCaseClient(f.httpEnv.OPERATOR_API_ORIGIN,async()=>Response.json({schemaVersion:1,requestId:crypto.randomUUID(),data:{events:[{...o.result.outcome,clubId:26}],nextRevision:null}}));
 await assert.rejects(()=>c.history(24,o.input.caseId),e=>e.code==='invalid_response');
});
test('client rejects command response with a different operation identity',async t=>{
 const f=setup(t),i=f.command(),o=await f.service.command(i);
 const c=new PaymentCaseClient(f.httpEnv.OPERATOR_API_ORIGIN,async()=>Response.json({schemaVersion:1,requestId:crypto.randomUUID(),data:{...o,outcome:{...o.outcome,operationId:crypto.randomUUID()}}}));
 await assert.rejects(()=>c.command(24,i.caseId,i.operationId,0,'open',i.detail),e=>e.code==='invalid_response');
});
for(const status of [401,403,500,503])test('write error '+status+' retains unknown outcome',async t=>{
 const f=setup(t),i=f.command();const c=new PaymentCaseClient(f.httpEnv.OPERATOR_API_ORIGIN,async()=>Response.json({error:{code:'unavailable'}},{status}));
 await assert.rejects(()=>c.command(24,i.caseId,i.operationId,0,'open',i.detail),e=>e.status===status&&e.outcomeUnknown);
});
test('client rejects invalid history range before transport',async t=>{
 const f=setup(t);await assert.rejects(()=>f.client.history(24,crypto.randomUUID(),0,51),e=>e.code==='invalid_request');assert.equal(f.calls.length,0);
});
test('browser fetch is called without a client object receiver',async t=>{
 const f=setup(t),o=await f.open();
 const c=new PaymentCaseClient(f.httpEnv.OPERATOR_API_ORIGIN,async function(){assert.equal(this,undefined,'Window fetch rejects a client as its receiver');return Response.json({schemaVersion:1,requestId:crypto.randomUUID(),data:o.result.currentCase});});
 assert.equal((await c.get(24,o.input.caseId)).caseId,o.input.caseId);
});
