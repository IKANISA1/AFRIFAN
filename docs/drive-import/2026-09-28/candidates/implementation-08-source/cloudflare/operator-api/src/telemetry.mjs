/** Allowlisted HTTP metrics only. Never read request/response bodies, cookies,
 * authorization, opaque case IDs, operator IDs, IP addresses, queries or errors.
 * Random requestId correlates this HTTP response; it is not a payment identity.
 */
const UUID=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/;
export function requestMetric(request,response,requestId,elapsedMs){
 if(!UUID.test(requestId)||!Number.isInteger(response.status)||response.status<100||response.status>599)return null;
 let path;try{path=new URL(request.url).pathname;}catch{return null;}
 const base='^/v1/admin/clubs/[1-9][0-9]{0,9}/payment-exceptions';let route='other';
 for(const [name,suffix] of [['case_session','/session$'],['case_operation','/operations/[a-f0-9-]{36}$'],['case_list','$'],['case_command','/[a-f0-9-]{36}/commands$'],['case_history','/[a-f0-9-]{36}/history$'],['case_detail','/[a-f0-9-]{36}$']])if(new RegExp(base+suffix).test(path)){route=name;break;}
 if(/^\/operator\/clubs\/[1-9][0-9]{0,9}\/payment-exceptions$/.test(path))route='case_page';
 else if(/^\/operator\/assets\/[a-z.-]+$/.test(path))route='operator_asset';
 else if(/^\/v1\/admin\/clubs\/[1-9][0-9]{0,9}\/public-source\//.test(path))route='publication';
 return {schemaVersion:1,event:'operator_http_response',requestId,route,
  method:['GET','POST','HEAD'].includes(request.method)?request.method:'OTHER',responseStatus:response.status,
  durationMs:Number.isFinite(elapsedMs)?Math.min(3600000,Math.max(0,Math.round(elapsedMs))):null};
}
export function emitRequestMetric(env,request,response,requestId,elapsedMs,sink=line=>console.log(line)){
 if(env.OPERATOR_METRICS_ENABLED!=='true')return false;
 try{const value=requestMetric(request,response,requestId,elapsedMs);if(!value)return false;sink(JSON.stringify(value));return true;}
 catch{return false;} // Telemetry is not permission to retry a committed command.
}
