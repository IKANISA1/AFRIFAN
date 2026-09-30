import {observationConfiguration,parseObservationJson} from './contracts.mjs';
const response=(status,code)=>Response.json({schemaVersion:1,...(status===201?{recorded:true}:{error:code})},
 {status,headers:{'cache-control':'no-store, private','x-content-type-options':'nosniff'}});
async function boundedBody(request){
 const reader=request.body?.getReader();if(!reader)throw Error('invalid_observation');
 let size=0;const chunks=[];
 let timer;
 try{return await Promise.race([(async()=>{
  for(;;){const {value,done}=await reader.read();if(done)break;size+=value.byteLength;
   if(size>1024){void reader.cancel().catch(()=>{});throw Error('invalid_observation');}chunks.push(value);}
  const all=new Uint8Array(size);let offset=0;for(const chunk of chunks){all.set(chunk,offset);offset+=chunk.length;}
  try{return new TextDecoder('utf-8',{fatal:true}).decode(all);}catch{throw Error('invalid_observation');}
 })(),new Promise((_,reject)=>{timer=setTimeout(()=>{
  void reader.cancel().catch(()=>{});reject(Error('web_observation_unavailable'));
 },250);})]);
 }finally{clearTimeout(timer);try{reader.releaseLock();}catch{}}
}
async function deadline(work,ms){let timer;try{return await Promise.race([Promise.resolve(work),
 new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('web_observation_unavailable')),ms);})]);}
 finally{clearTimeout(timer);}}
/** Incoming cookies, authentication and transport identifiers are never forwarded to the binding. */
export async function handleWebObservation(request,env,event){try{
 const config=observationConfiguration(env);
 if(!config||typeof env.WEB_OBSERVATIONS?.record!=='function')return response(503,'web_observation_unavailable');
 const url=new URL(request.url),path=event==='web_vital'?'/api/telemetry/vitals':'/api/pwa/events';
 if(request.method!=='POST')return response(405,'method_not_allowed');
 if(url.origin!==config.origin||url.pathname!==path||url.search||url.hash||
  request.headers.get('origin')!==config.origin||
  ![null,'same-origin'].includes(request.headers.get('sec-fetch-site'))||
  request.headers.has('authorization')||request.headers.has('cookie'))return response(403,'observation_access_denied');
 const contentType=request.headers.get('content-type')?.split(';').map(x=>x.trim());
 if(contentType?.[0]!=='application/json'||contentType.slice(1).some(x=>x.toLowerCase()!=='charset=utf-8')||
  ![null,'identity'].includes(request.headers.get('content-encoding')))return response(415,'unsupported_media_type');
 const observation=parseObservationJson(await boundedBody(request));
 if(!observation||observation.event!==event)return response(400,'invalid_observation');
 const result=await deadline(Promise.resolve().then(()=>env.WEB_OBSERVATIONS.record({
  observation,clubId:config.clubId,retentionMs:config.retentionMs,policyRef:config.policyRef})),250);
 if(result===null||typeof result!=='object'||Object.keys(result).length!==2||
  result.schemaVersion!==1||result.recorded!==true)return response(503,'web_observation_unavailable');
 return response(201);
}catch(error){return error instanceof Error&&error.message==='invalid_observation'
 ?response(400,'invalid_observation'):response(503,'web_observation_unavailable');}}
