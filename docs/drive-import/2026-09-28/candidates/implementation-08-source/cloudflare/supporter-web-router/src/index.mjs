/** Same-origin edge composition. The original Cloudflare Request goes directly to the browser
 * API service binding: no synthetic CF context or browser-supplied identity is manufactured. */
export function routerConfig(env){
 if(env.WEB_ROUTER_ENABLED!=='true')throw Error('disabled');
 const url=new URL(env.WEB_ORIGIN);
 if(url.origin!==env.WEB_ORIGIN||url.protocol!=='https:'||url.username||url.password||
   !url.hostname.includes('.')||url.hostname.endsWith('.')||typeof env.NEXT_APP?.fetch!=='function'||typeof env.BROWSER_API?.fetch!=='function')throw Error('configuration');
 return {origin:url.origin};
}
function privateResponse(response){
 const h=new Headers(response.headers);h.set('cache-control','private, no-store');h.set('cdn-cache-control','no-store');
 h.set('cloudflare-cdn-cache-control','no-store');h.set('pragma','no-cache');h.set('x-robots-tag','noindex, nofollow, noarchive');
 h.set('referrer-policy','no-referrer');h.set('x-content-type-options','nosniff');
 const vary=new Set((h.get('vary')??'').split(',').map(x=>x.trim()).filter(Boolean));vary.add('Cookie');h.set('vary',[...vary].join(', '));
 return new Response(response.body,{status:response.status,statusText:response.statusText,headers:h});
}
export function createWebRouter(){return {async fetch(request,env){
 let api=false,invoked=false;
 try{
  const cfg=routerConfig(env),url=new URL(request.url);api=/^\/v1(?:\/|%|$)/.test(url.pathname);
  if(url.origin!==cfg.origin||url.username||url.password||url.hash)return new Response('Not found',{status:404,headers:{'cache-control':'no-store'}});
  if(api){
   if(url.pathname.includes('%'))return new Response('Not found',{status:404,headers:{'cache-control':'no-store'}});
   if(!url.pathname.startsWith('/v1/browser/')&&url.pathname!=='/v1/browser/session')return new Response('Not found',{status:404,headers:{'cache-control':'no-store'}});
   if(!['GET','POST'].includes(request.method))return new Response('Method not allowed',{status:405,headers:{'cache-control':'no-store'}});
   invoked=true;return privateResponse(await env.BROWSER_API.fetch(request));
  }
  // The public app must not resolve an attacker-controlled forwarded host as another tenant/admin host.
  const h=new Headers(request.headers);for(const key of ['forwarded','x-forwarded-host','x-original-host','x-africlub-controlled-admin-evidence'])h.delete(key);
  h.set('host',url.host);invoked=true;
  const response=await env.NEXT_APP.fetch(new Request(request,{headers:h,redirect:'manual'}));
  return /^\/(?:membership|supporters|admin|operator|auth|account-deletion|api)(?:\/|$)/.test(url.pathname)?privateResponse(response):response;
 }catch{
  return privateResponse(new Response(JSON.stringify({error:'service_unavailable',...(api&&request.method==='POST'?{outcome:invoked?'unknown':'not_dispatched'}:{})}),
   {status:503,headers:{'content-type':'application/json; charset=utf-8'}}));
 }
}};}
export default createWebRouter();
