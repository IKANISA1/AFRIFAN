import {need,BrowserError} from './policy.mjs';
export const SESSION_COOKIE='__Host-africlub_browser';
export const BOOTSTRAP_COOKIE='__Host-africlub_pre';
export const INTENT='browser-v1';
export function cookies(request){
 const text=request.headers.get('cookie')??'';need(text.length<=8192);
 const values={};
 for(const part of text.split(';')){
  if(!part.trim())continue;const pos=part.indexOf('=');need(pos>0);
  const name=part.slice(0,pos).trim(),value=part.slice(pos+1).trim();
  if(![SESSION_COOKIE,BOOTSTRAP_COOKIE].includes(name))continue;
  need(!Object.hasOwn(values,name),'invalid_request',400);
  need(value.length>0&&value.length<=2048&&/^[A-Za-z0-9_.-]+$/.test(value),'invalid_request',400);
  values[name]=value;
 }
 return {sessionCookie:values[SESSION_COOKIE]??null,bootstrapCookie:values[BOOTSTRAP_COOKIE]??null};
}
export function ingress(request,cfg){
 const url=new URL(request.url);
 need(url.origin===cfg.origin&&!url.username&&!url.password&&!url.hash&&!url.search,'not_found',404);
 need(!request.headers.has('authorization')&&!request.headers.has('x-africlub-client')&&
  !request.headers.has('x-africlub-session'),'invalid_request',400);
 need(request.headers.get('x-africlub-browser-intent')===INTENT,'invalid_request',400);
 const origin=request.headers.get('origin'),site=request.headers.get('sec-fetch-site');
 need(!site||site==='same-origin','permission_denied',403);
 if(request.method!=='GET')need(origin===cfg.origin,'permission_denied',403);
 else {
  need(!origin||origin===cfg.origin,'permission_denied',403);
  let referer=null;try{referer=new URL(request.headers.get('referer')).origin;}catch{}
  need(origin===cfg.origin||site==='same-origin'||referer===cfg.origin,'permission_denied',403);
 }
 const ip=request.headers.get('cf-connecting-ip');
 need(request.cf&&typeof ip==='string'&&ip.length>0&&ip.length<=64&&/^[0-9a-fA-F:.]+$/.test(ip),'service_unavailable',503);
 return {url,ip};
}
export async function body(request,{limit=2048,timeout=3000}={}){
 need(/^application\/json(?:;\s*charset=utf-8)?$/i.test(request.headers.get('content-type')??''));
 need(!request.headers.has('content-encoding'));
 const length=request.headers.get('content-length');
 need(length===null||(/^[0-9]+$/.test(length)&&Number(length)<=limit));
 need(request.body);const reader=request.body.getReader();let total=0,timer;const chunks=[];
 try{
  const data=async()=>{for(;;){const {value,done}=await reader.read();if(done)break;total+=value.byteLength;
   if(total>limit)throw new BrowserError('invalid_request',400);chunks.push(value);}
   const out=new Uint8Array(total);let offset=0;for(const x of chunks){out.set(x,offset);offset+=x.byteLength;}
   try{return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(out));}catch{throw new BrowserError('invalid_request',400);}};
  return await Promise.race([data(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(new BrowserError('invalid_request',400)),timeout);})]);
 }finally{clearTimeout(timer);reader.cancel().catch(()=>{});}
}
export function cookieHeader(name,value,maxAge){
 need([SESSION_COOKIE,BOOTSTRAP_COOKIE].includes(name));
 need(typeof value==='string'&&(!value||/^[A-Za-z0-9_.-]+$/.test(value))&&value.length<=2048);
 need(Number.isSafeInteger(maxAge)&&maxAge>=0&&maxAge<=86400);
 return `${name}=${value}; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=${maxAge}`;
}
export function response(value,status=200,setCookies=[]){
 const h=new Headers({'content-type':'application/json; charset=utf-8','cache-control':'private, no-store',
  'pragma':'no-cache','x-content-type-options':'nosniff','referrer-policy':'no-referrer',
  'content-security-policy':"default-src 'none'; frame-ancestors 'none'; base-uri 'none'",
  'vary':'Origin, Sec-Fetch-Site, Cookie','cross-origin-resource-policy':'same-origin'});
 for(const c of setCookies)h.append('set-cookie',c);
 return new Response(JSON.stringify(value),{status,headers:h});
}
