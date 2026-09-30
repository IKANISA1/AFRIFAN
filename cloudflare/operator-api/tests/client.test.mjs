import test from 'node:test';import assert from 'node:assert/strict';import {spawnSync} from 'node:child_process';
import {mkdtempSync,readFileSync,rmSync} from 'node:fs';import {tmpdir} from 'node:os';import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
const dir=mkdtempSync(join(tmpdir(),'africlub-client-test-'));let Client,ApiError;
try{
 const r=spawnSync(process.env.TSC_BIN||'tsc',['--strict','--target','ES2022','--module','ES2022','--lib','ES2022,DOM','--outDir',dir,fileURLToPath(new URL('../client.ts',import.meta.url))],{encoding:'utf8'});
 assert.equal(r.status,0,r.stderr+r.stdout);
 ({OperatorPublicationClient:Client,OperatorApiError:ApiError}=await import(`data:text/javascript;base64,${readFileSync(join(dir,'client.js')).toString('base64')}`));
}finally{rmSync(dir,{recursive:true,force:true});}
const reviewId=crypto.randomUUID(),operationId=crypto.randomUUID(),snapshotId='a'.repeat(64);
const publication={operationId,clubId:24,reviewId,snapshotId,previousSnapshotId:null,publishedAt:new Date().toISOString(),status:'published',replayed:false};
const response=(data,status=200)=>new Response(JSON.stringify({schemaVersion:1,data}),{status});
test('client enforces HTTPS origin',()=>{for(const url of ['http://operator.invalid','https://operator.invalid/path','https://name:pass@operator.invalid'])assert.throws(()=>new Client(url));});
test('client sends same-origin credentials and no automatic token or approver',async()=>{let options;const c=new Client('https://operator.invalid',async(url,o)=>{options=o;return response(publication)});await c.confirm(24,reviewId,'idempotent_key_123456');assert.equal(options.credentials,'same-origin');assert.equal(options.redirect,'error');assert.equal(options.headers.authorization,undefined);assert.deepEqual(JSON.parse(options.body),{reviewId});assert.equal(options.headers['idempotency-key'],'idempotent_key_123456');});
test('client preserves key across explicit retry and never auto-retries',async()=>{const keys=[];const c=new Client('https://operator.invalid',async(url,o)=>{keys.push(o.headers['idempotency-key']);if(keys.length===1)throw Error('network');return response({...publication,replayed:true})});await assert.rejects(c.confirm(24,reviewId,'idempotent_key_123456'),e=>e instanceof ApiError&&e.mayHaveCommitted);assert.equal(keys.length,1);await c.confirm(24,reviewId,'idempotent_key_123456');assert.deepEqual(keys,['idempotent_key_123456','idempotent_key_123456']);});
test('client treats successful malformed confirmation as possibly committed',async()=>{const c=new Client('https://operator.invalid',async()=>response({...publication,snapshotId:'bad'}));await assert.rejects(c.confirm(24,reviewId,'idempotent_key_123456'),e=>e.code==='invalid_response'&&e.mayHaveCommitted);});
test('client rejects wrong-club response',async()=>{const c=new Client('https://operator.invalid',async()=>response({...publication,clubId:44}));await assert.rejects(c.confirm(24,reviewId,'idempotent_key_123456'),/invalid_response/);});
test('client rejects wrong review or operation ID',async()=>{const c=new Client('https://operator.invalid',async()=>response(publication));await assert.rejects(c.confirm(24,crypto.randomUUID(),'idempotent_key_123456'),/invalid_response/);await assert.rejects(c.status(24,crypto.randomUUID()),/invalid_response/);});
test('client exposes sanitized server error and no automatic confirm on review',async()=>{let calls=0;const c=new Client('https://operator.invalid',async()=>{calls++;return new Response(JSON.stringify({schemaVersion:1,error:{code:'operator_not_authorized',requestId:'safe'}}),{status:403})});await assert.rejects(c.review(24,{snapshotId,expectedPreviousId:null,reviewRef:'ref:test'}),e=>e.code==='operator_not_authorized'&&!e.mayHaveCommitted);assert.equal(calls,1);});
test('client validates review receipt details',async()=>{const input={snapshotId,expectedPreviousId:null,reviewRef:'ref:test'},data={...input,reviewId,clubId:24,expiresAt:new Date().toISOString(),rowCount:5,mediaCount:0};const c=new Client('https://operator.invalid',async()=>response(data,201));assert.equal((await c.review(24,input)).reviewId,reviewId);data.rowCount=-1;await assert.rejects(c.review(24,input),/invalid_response/);});
test('client validates head freshness shape and operation read',async()=>{const c=new Client('https://operator.invalid',async()=>response({clubId:24,snapshotId:null,capturedAt:null,activatedAt:null,fresh:false}));assert.equal((await c.head(24)).fresh,false);const d=new Client('https://operator.invalid',async()=>response(publication));assert.equal((await d.status(24,operationId)).operationId,operationId);});
test('client-generated idempotency key is valid and unique',()=>{const a=Client.createIdempotencyKey(),b=Client.createIdempotencyKey();assert.match(a,/^[A-Za-z0-9_-]{16,128}$/);assert.notEqual(a,b);});
for(const status of [401,403])test(`confirmation ${status} retains a possible committed outcome`,async()=>{
 const c=new Client('https://operator.invalid',async()=>new Response(JSON.stringify({schemaVersion:1,error:{code:'operator_not_authorized'}}),{status}));
 await assert.rejects(c.confirm(24,reviewId,'idempotent_key_123456'),e=>e instanceof ApiError&&e.status===status&&e.mayHaveCommitted);
});
test('browser fetch is called without a client object receiver',async()=>{
 const c=new Client('https://operator.invalid',async function(){assert.equal(this,undefined,'Window fetch rejects a client as its receiver');return response(publication);});
 assert.equal((await c.confirm(24,reviewId,'idempotent_key_123456')).operationId,operationId);
});
