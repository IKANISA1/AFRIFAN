import {club,uuid,exact,demand,hash,envelope,accepted,AllocationError,failure} from './policy.mjs';
async function bounded(promise,ms){
 let timer;try{return await Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(new AllocationError('sink_timeout')),ms);})]);}
 finally{clearTimeout(timer);}
}
/** At most one event per configured club and five events per invocation. No overlapping local loop. */
export async function drain(env){
 demand(env.DELIVERY_DISPATCH_ENABLED==='true','service_disabled');
 demand(env.DELIVERY_ENVIRONMENT==='isolated-staging','staging_only');
 let clubs;try{clubs=JSON.parse(env.DELIVERY_CLUB_IDS);}catch{throw new AllocationError('invalid_configuration');}
 const timeout=Number(env.DELIVERY_TIMEOUT_MS);
 demand(Array.isArray(clubs)&&clubs.length>0&&clubs.length<=5&&clubs.every(club)&&new Set(clubs).size===clubs.length
  &&Number.isInteger(timeout)&&timeout>=100&&timeout<=4000&&env.SOURCE?.take&&env.SOURCE?.readForDispatch&&env.SOURCE?.finish&&env.INBOX?.accept,'invalid_configuration');
 const result={schemaVersion:1,examined:0,stored:0,retryRecorded:0,deadRecorded:0,unknown:0,unavailableClubs:0};
 for(const clubId of clubs){
  let claim;
  try{
   const response=await env.SOURCE.take({clubId});exact(response,['schemaVersion','clubId','event']);demand(response.schemaVersion===1&&response.clubId===clubId,'invalid_receipt');
   claim=response.event;if(claim===null)continue;
   exact(claim,['eventId','leaseId','leaseUntil','revision']);demand(uuid(claim.eventId)&&uuid(claim.leaseId)&&Number.isSafeInteger(claim.revision)&&Number.isSafeInteger(claim.leaseUntil),'invalid_receipt');
  }catch{result.unavailableClubs++;continue;}
  result.examined++;
  let outcome='retry',reason='sink_unavailable',receiptId=null;
  try{
   const prepared=await env.SOURCE.readForDispatch({clubId,eventId:claim.eventId,leaseId:claim.leaseId});
   exact(prepared,['schemaVersion','event','envelopeSha256']);
   const value=envelope(prepared.event),digest=await hash(value);
   demand(prepared.schemaVersion===1&&value.clubId===clubId&&value.eventId===claim.eventId&&digest===prepared.envelopeSha256,'invalid_event');
   const receipt=await bounded(Promise.resolve().then(()=>env.INBOX.accept(value)),timeout);
   accepted(receipt,value,digest);outcome='delivered';reason='none';receiptId=receipt.receiptId;
  }catch(error){
   const code=failure(error).code;
   if(code==='invalid_event'||code==='invalid_receipt'){outcome='dead';reason=code;}
   else if(code==='sink_timeout')reason='sink_timeout';
  }
  try{
   const requestId=crypto.randomUUID();
   const receipt=await env.SOURCE.finish({clubId,eventId:claim.eventId,leaseId:claim.leaseId,expectedRevision:claim.revision,
    requestId,outcome,reason,receiptId});
   exact(receipt,['schemaVersion','operationId','eventId','action','committed','resultingRevision']);
   demand(receipt.schemaVersion===1&&receipt.operationId===requestId&&receipt.eventId===claim.eventId&&receipt.action===outcome
    &&receipt.committed===true&&receipt.resultingRevision===claim.revision+1,'invalid_receipt');
   if(outcome==='delivered')result.stored++;else if(outcome==='dead')result.deadRecorded++;else result.retryRecorded++;
  }catch{result.unknown++;}
 }
 return result;
}
