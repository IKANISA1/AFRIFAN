import {club,uuid,exact,demand,hash,envelope,accepted,AllocationError,failure} from './policy.mjs';
import {traceOperation,operationMetric,emitMetricDetached} from '../../shared-telemetry/telemetry.mjs';
async function bounded(promise,ms,code){
 let timer;try{return await Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(new AllocationError(code)),ms);})]);}
 finally{clearTimeout(timer);}
}
/** At most one event per configured club and five events per invocation. No overlapping local loop. */
export async function drain(env,{ctx}={}){
 return traceOperation(env,{service:'allocation_delivery',operation:'delivery_drain'},()=>drainOnce(env,ctx),
  {ctx,selectOutcome:r=>r.unknown?'unknown':r.unavailableClubs?'unavailable':r.examined?'completed':'no_work'});
}
async function drainOnce(env,ctx){
 demand(env.DELIVERY_DISPATCH_ENABLED==='true','service_disabled');
 demand(env.DELIVERY_ENVIRONMENT==='isolated-staging','staging_only');
 let clubs;try{clubs=JSON.parse(env.DELIVERY_CLUB_IDS);}catch{throw new AllocationError('invalid_configuration');}
 const timeout=Number(env.DELIVERY_TIMEOUT_MS);
 demand(Array.isArray(clubs)&&clubs.length>0&&clubs.length<=5&&clubs.every(club)&&new Set(clubs).size===clubs.length
  &&Number.isInteger(timeout)&&timeout>=100&&timeout<=4000&&env.SOURCE?.take&&env.SOURCE?.readForDispatch&&env.SOURCE?.finish&&env.INBOX?.accept,'invalid_configuration');
 const result={schemaVersion:1,examined:0,stored:0,retryRecorded:0,deadRecorded:0,unknown:0,unavailableClubs:0};
 for(const clubId of clubs){
  const before={...result},started=Date.now();
  try{
  let claim;
  try{
   const response=await bounded(Promise.resolve().then(()=>env.SOURCE.take({clubId})),timeout,'source_timeout');exact(response,['schemaVersion','clubId','event']);demand(response.schemaVersion===1&&response.clubId===clubId,'invalid_receipt');
   claim=response.event;if(claim===null)continue;
   exact(claim,['eventId','leaseId','leaseUntil','revision']);demand(uuid(claim.eventId)&&uuid(claim.leaseId)&&Number.isSafeInteger(claim.revision)&&Number.isSafeInteger(claim.leaseUntil),'invalid_receipt');
  }catch{result.unavailableClubs++;continue;}
  result.examined++;
  let outcome='retry',reason='sink_unavailable',receiptId=null;
  try{
   const prepared=await bounded(Promise.resolve().then(()=>env.SOURCE.readForDispatch({clubId,eventId:claim.eventId,leaseId:claim.leaseId})),timeout,'source_timeout');
   exact(prepared,['schemaVersion','event','envelopeSha256']);
   const value=envelope(prepared.event),digest=await hash(value);
   demand(prepared.schemaVersion===1&&value.clubId===clubId&&value.eventId===claim.eventId&&digest===prepared.envelopeSha256,'invalid_event');
   const receipt=await bounded(Promise.resolve().then(()=>env.INBOX.accept(value)),timeout,'sink_timeout');
   accepted(receipt,value,digest);outcome='delivered';reason='none';receiptId=receipt.receiptId;
  }catch(error){
   const code=failure(error).code;
   // A source timeout is not cancellation. Leave the original lease to expire;
   // the read may still be running and no sink call has been attempted.
   if(code==='source_timeout'){result.unknown++;continue;}
   if(code==='invalid_event'||code==='invalid_receipt'){outcome='dead';reason=code;}
   else if(code==='sink_timeout')reason='sink_timeout';
  }
  try{
   const requestId=crypto.randomUUID();
   const receipt=await bounded(Promise.resolve().then(()=>env.SOURCE.finish({clubId,eventId:claim.eventId,leaseId:claim.leaseId,expectedRevision:claim.revision,
    requestId,outcome,reason,receiptId})),timeout,'source_timeout');
   exact(receipt,['schemaVersion','operationId','eventId','action','committed','resultingRevision']);
   demand(receipt.schemaVersion===1&&receipt.operationId===requestId&&receipt.eventId===claim.eventId&&receipt.action===outcome
    &&receipt.committed===true&&receipt.resultingRevision===claim.revision+1,'invalid_receipt');
   if(outcome==='delivered')result.stored++;else if(outcome==='dead')result.deadRecorded++;else result.retryRecorded++;
  }catch{result.unknown++;}
  }finally{
   try{
   const outcome=result.unavailableClubs>before.unavailableClubs?'unavailable':result.unknown>before.unknown?'unknown':
    result.stored>before.stored?'completed':result.deadRecorded>before.deadRecorded||result.retryRecorded>before.retryRecorded?'rejected':'no_work';
   const observedAt=Date.now();emitMetricDetached(env,operationMetric({service:'allocation_delivery',operation:'delivery_drain',clubId,
    traceId:crypto.randomUUID(),observedAt,durationMs:observedAt-started,outcome}),ctx);
   }catch{/* Fairness observation failure cannot change a completed drain. */}
  }
 }
 return result;
}
