import test,{after} from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';
import {compileClient} from '../scripts/compile-client.mjs';
const c=compileClient();after(()=>c.cleanup());const {MembershipApiClient}=await import(c.url);
const fixture=JSON.parse(readFileSync(new URL('../../../packages/features/feat_membership/test/native_checkout/wire-vectors.json',import.meta.url)));
const e=fixture.expected,actor={schemaVersion:1,userId:e.userId,clubId:e.clubId,sessionId:e.sessionId};
for(const v of fixture.vectors)test(`wire: ${v.name}`,async()=>{
 let calls=0;const api=new MembershipApiClient('https://membership.example.invalid',e.clubId,async()=>`${e.sessionId}.${'a'.repeat(43)}`,async()=>{calls++;return new Response(JSON.stringify(v.body),{status:200,headers:{'content-type':'application/json'}});});
 const run=()=>v.kind==='session'?api.session():v.kind==='prepared'?api.prepare(actor,e.requestId,e.tier):v.kind==='status'?api.read(actor,e.orderId):api.receipt(actor,e.orderId);
 if(v.accept)await run();else await assert.rejects(run());assert.equal(calls,1);
});
