import { AuthError, requireValue, publicError } from './errors.mjs';
export function reply(body,status=200){return new Response(JSON.stringify(body),{status,headers:{
 'content-type':'application/json; charset=utf-8','cache-control':'no-store','pragma':'no-cache',
 'x-content-type-options':'nosniff','referrer-policy':'no-referrer','content-security-policy':"default-src 'none'; frame-ancestors 'none'"}});}
export function fail(error){const e=publicError(error);return reply({schemaVersion:1,error:e.code},e.status);}
export async function readJson(request,{timeoutMs=2000}={}){requireValue(request.headers.get('content-type')?.split(';')[0].trim()==='application/json','invalid_request',415);
 requireValue(Number.isInteger(timeoutMs)&&timeoutMs>0&&timeoutMs<=2000,'invalid_request',400);
 const length=request.headers.get('content-length');if(length!==null)requireValue(/^\d+$/.test(length)&&Number(length)<=4096,'request_too_large',413);
 requireValue(!request.headers.has('content-encoding'),'invalid_request',415);
 const reader=request.body?.getReader();requireValue(reader);let size=0,timer;const chunks=[];
 try{await Promise.race([(async()=>{while(true){const {value,done}=await reader.read();if(done)break;size+=value.length;
  requireValue(size<=4096,'request_too_large',413);chunks.push(value);}})(),new Promise((_,reject)=>{
   timer=setTimeout(()=>{void reader.cancel().catch(()=>{});reject(new AuthError('body_timeout',408));},timeoutMs);
  })]);}
 finally{clearTimeout(timer);void reader.cancel().catch(()=>{});try{reader.releaseLock();}catch{}}
 const bytes=new Uint8Array(size);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}
 try{return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));}catch{requireValue(false,'invalid_request',400);}}
export function bearer(request){const value=request.headers.get('authorization');requireValue(typeof value==='string'&&value.startsWith('Bearer '),'unauthenticated',401);return value.slice(7);}
/** This transport is for native/controlled server clients, NOT a browser cookie-session API. */
export function nativeIngress(request,env){const u=new URL(request.url);requireValue(u.protocol==='https:'&&u.origin===env.AUTH_ORIGIN,'invalid_origin',403);
 requireValue(!u.search&&!u.hash,'invalid_request',400);requireValue(!request.headers.has('origin')&&!request.headers.has('cookie')&&!request.headers.has('sec-fetch-site'),'browser_transport_not_enabled',403);
 requireValue(request.headers.get('x-africlub-client')==='native-v1','invalid_client',400);
 // The CF context and connection IP are trusted ONLY on directly invoked Cloudflare ingress.
 // Neither value grants user permissions. No X-Forwarded-For or client user-ID fallback.
 requireValue(request.cf&&typeof request.cf==='object','edge_context_required',503);
 const ip=request.headers.get('cf-connecting-ip');requireValue(typeof ip==='string'&&ip.length<=64&&/^[0-9a-fA-F:.]+$/.test(ip),'edge_context_required',503);return ip;
}
