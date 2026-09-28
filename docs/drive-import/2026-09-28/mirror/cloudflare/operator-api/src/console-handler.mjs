import {authenticatedOperator} from './access-identity.mjs';
import {originPolicy,apiError} from './http.mjs';
import {requireThat,OperatorError} from './errors.mjs';
const security={
 'cache-control':'no-store','x-content-type-options':'nosniff','referrer-policy':'no-referrer',
 'content-security-policy':"default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'; object-src 'none'",
 'permissions-policy':'camera=(), microphone=(), geolocation=()',
};
/** No Static Assets binding: the direct authenticated Worker serves fixed text modules. */
export async function serveConsole(request,env,ctx,assets){
 const requestId=crypto.randomUUID();try{
  const url=new URL(request.url),page=/^\/operator\/clubs\/([1-9]\d{0,9})$/.exec(url.pathname);
  const asset=Object.hasOwn(assets,url.pathname)?assets[url.pathname]:null;
  requireThat(page||asset,'not_found',404);requireThat(!url.search,'not_found',404);
  requireThat(request.method==='GET','method_not_allowed',405);
  requireThat(env.OPERATOR_API_ENABLED==='true'&&env.OPERATOR_CONSOLE_ENABLED==='true','operator_console_disabled',503);
  originPolicy(request,env.OPERATOR_API_ORIGIN,false);
  const identity=await authenticatedOperator(env,ctx);
  if(page){requireThat(env.PUBLIC_SOURCE_PUBLISHER&&typeof env.PUBLIC_SOURCE_PUBLISHER.session==='function','publication_service_unavailable',503);
   const result=await env.PUBLIC_SOURCE_PUBLISHER.session({identity,clubId:Number(page[1])});
   if(!result?.ok){const e=result?.error;throw new OperatorError(e?.code??'publication_service_unavailable',[401,403,404,409,429,503].includes(e?.status)?e.status:503);}
  }
  const resource=page?assets.shell:asset;requireThat(resource&&typeof resource.body==='string','console_assets_unavailable',503);
  return new Response(resource.body,{headers:{...security,'content-type':resource.type}});
 }catch(error){return apiError(error,requestId);}
}
