import {traceOperation} from './telemetry.mjs';
const club=input=>{try{const value=input?.clubId;return Number.isSafeInteger(value)&&value>0&&value<=2147483647?value:null;}catch{return null;}};
export function rpcOperation(owner,{service,operation,mutating=false},input,work){
 return traceOperation(owner.env,{service,operation,clubId:club(input)},work,{ctx:owner.ctx,mutating,
  selectOutcome:result=>result?.ok===false?(mutating?'unknown':result.error?.status===401||result.error?.status===403?'denied':'rejected'):'completed'});
}
export function httpOperation(env,{service,operation,clubId=null},request,work,ctx){
 const mutating=!['GET','HEAD','OPTIONS'].includes(request.method);
 return traceOperation(env,{service,operation,clubId},work,{ctx,mutating,selectOutcome:response=>{
  const status=response?.status;
  if(!Number.isInteger(status)||status<100||status>599)return 'unknown';
  if(status<400)return 'completed';if(mutating)return 'unknown';
  return status===401||status===403?'denied':status>=500?'unavailable':'rejected';
 }});
}
