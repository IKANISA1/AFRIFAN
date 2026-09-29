import {writeFileSync} from 'node:fs';
import {fixture,json} from '../tests/fixture.mjs';
const cleanups=[],t={after(f){cleanups.push(f);}};
try{
 const f=await fixture(t),requestId=crypto.randomUUID();
 const session=await json(await f.call('session'));
 const prepared=await json(await f.call('membership/checkouts',{key:requestId}));
 const status=await json(await f.call(`membership/checkouts/${prepared.orderId}`));
 await f.allocate(prepared.orderId);
 const receipt=await json(await f.call(`membership/checkouts/${prepared.orderId}/receipt`));
 const allocated=await json(await f.call(`membership/checkouts/${prepared.orderId}`));
 const vectors=[];
 for(const [kind,body] of Object.entries({session,prepared,status,receipt})){
  vectors.push({name:`${kind}:valid`,kind,accept:true,body});
  for(const field of Object.keys(body)){
   const changed=structuredClone(body);delete changed[field];vectors.push({name:`${kind}:missing:${field}`,kind,accept:false,body:changed});
  }
  vectors.push({name:`${kind}:unknown-field`,kind,accept:false,body:{...body,unexpected:true}});
  vectors.push({name:`${kind}:wrong-club`,kind,accept:false,body:{...body,clubId:25}});
 }
 vectors.push({name:'status:allocated-valid',kind:'status',accept:true,body:allocated});
 for(const s of ['expired','cancelled','configuration_changed'])vectors.push({name:`status:${s}-valid`,kind:'status',accept:true,body:{...status,status:s,paymentInstruction:null}});
 for(const [field,value] of Object.entries({amount:0,currency:'Rwf',country:'RWA',provider:'bad provider',recipient:'last-three-123',ussdCode:'https://example.invalid'}))
  vectors.push({name:`status:invalid:${field}`,kind:'status',accept:false,body:{...status,paymentInstruction:{...status.paymentInstruction,[field]:value}}});
 vectors.push({name:'status:paid-with-instructions',kind:'status',accept:false,body:{...status,status:'allocated',paymentEvidenceAllocated:true}});
 vectors.push({name:'receipt:not-historical',kind:'receipt',accept:false,body:{...receipt,historical:false}});
 vectors.push({name:'receipt:tier-object',kind:'receipt',accept:false,body:{...receipt,membershipAtAllocation:{...receipt.membershipAtAllocation,tier:{}}}});
 const out={schemaVersion:1,fixtureOnly:true,source:'Actual gateway + current identity and checkout/allocation services, synthetic SQLite fixtures',expected:{clubId:24,userId:session.userId,sessionId:session.sessionId,requestId,orderId:prepared.orderId,tier:'gold'},vectors};
 writeFileSync(new URL('../../../packages/features/feat_membership/test/native_checkout/wire-vectors.json',import.meta.url),JSON.stringify(out,null,2)+'\n');
 console.log(JSON.stringify({vectorCases:vectors.length,actualServices:true,providerRequests:0}));
}finally{for(const cleanup of cleanups.reverse())await cleanup();}
