import {emitRequestMetric} from './telemetry.mjs';
import { paymentExceptionResponse, callCases } from './payment-exceptions.mjs';
import { authenticatedOperator } from './access-identity.mjs';
import { OperatorError, requireThat, exactObject, positiveClub, UUID, HEX64 } from './errors.mjs';
import { json, apiError, originPolicy, readJson } from './http.mjs';
import { uiResponse } from './ui-response.mjs';

async function callService(env, method, input) {
  requireThat(env.PUBLIC_SOURCE_PUBLISHER && typeof env.PUBLIC_SOURCE_PUBLISHER[method] === 'function',
    'publication_service_unavailable',503);
  const result=await env.PUBLIC_SOURCE_PUBLISHER[method](input);
  requireThat(result && typeof result.ok==='boolean','publication_service_unavailable',503);
  if(!result.ok) {
    const e=result.error;
    requireThat(e && /^[a-z_]{3,80}$/.test(e.code) && [400,401,403,404,409,410,429,503].includes(e.status),
      'publication_service_unavailable',503);
    throw new OperatorError(e.code,e.status);
  }
  return result.data;
}
/** Same-origin Access gateway. The UI is served directly by this Worker, never
 * through Static Assets or another Worker; ctx.access must remain authoritative.
 */
const gateway = {
  async fetch(request, env, ctx, requestId) {
    try {
      const caseResponse=await paymentExceptionResponse(request,env,ctx,requestId);
      if(caseResponse)return caseResponse;
      const url=new URL(request.url);
      const casesPage=/^\/operator\/clubs\/([1-9]\d{0,9})\/payment-exceptions$/.exec(url.pathname);
      if(casesPage) {
        requireThat(!url.search,'not_found',404);requireThat(request.method==='GET','method_not_allowed',405);
        requireThat(env.OPERATOR_API_ENABLED==='true'&&env.OPERATOR_UI_ENABLED==='true'&&env.OPERATOR_CASES_ENABLED==='true','operator_cases_disabled',503);
        originPolicy(request,env.OPERATOR_API_ORIGIN,false);
        const identity=await authenticatedOperator(env,ctx),clubId=positiveClub(Number(casesPage[1]));
        await callCases(env,'access',{identity,clubId});
        return uiResponse(clubId,null,'cases');
      }
      const page=/^\/operator\/clubs\/([1-9]\d{0,9})\/public-source$/.exec(url.pathname);
      const asset=/^\/operator\/assets\/(client\.js|controller\.js|app\.js|styles\.css|case-client\.js|case-controller\.js|cases\.js|inter-latin-wght-normal\.woff2)$/.exec(url.pathname);
      if(page||asset) {
        requireThat(!url.search,'not_found',404);
        requireThat(request.method==='GET','method_not_allowed',405);
        requireThat(env.OPERATOR_API_ENABLED==='true' && env.OPERATOR_UI_ENABLED==='true','operator_ui_disabled',503);
        originPolicy(request,env.OPERATOR_API_ORIGIN,false);
        if(asset&&asset[1].startsWith('case'))requireThat(env.OPERATOR_CASES_ENABLED==='true','operator_cases_disabled',503);
        const identity=await authenticatedOperator(env,ctx);
        if(page) await callService(env,'session',{identity,clubId:positiveClub(Number(page[1]))});
        return uiResponse(page?Number(page[1]):null,asset?.[1]??null);
      }
      const route=/^\/v1\/admin\/clubs\/([1-9]\d{0,9})\/public-source\/(head|session|reviews|publications|candidates)(?:\/([a-f0-9-]+))?(?:\/preview\/([a-z-]+))?$/.exec(url.pathname);
      requireThat(route,'not_found',404);
      const clubId=positiveClub(Number(route[1])),resource=route[2],id=route[3],previewRoute=route[4];
      let method;
      if(previewRoute) {
        requireThat(resource==='candidates' && HEX64.test(id??'') &&
          [...url.searchParams.keys()].every(k=>k==='offset') && url.searchParams.getAll('offset').length<=1,'not_found',404);
        method='preview';
      } else {
        requireThat(!url.search,'not_found',404);
        if(resource==='head'&&!id)method='head';
        else if(resource==='session'&&!id)method='session';
        else if(resource==='candidates'&&(!id||HEX64.test(id)))method=id?'candidate':'candidates';
        else if(resource==='reviews'&&UUID.test(id??''))method='reviewStatus';
        else if(resource==='publications'&&UUID.test(id??''))method='publication';
        else if(resource==='reviews'&&!id)method='review';
        else if(resource==='publications'&&!id)method='publish';
        else throw new OperatorError('not_found',404);
      }
      const write=['review','publish'].includes(method);
      requireThat(request.method===(write?'POST':'GET'),'method_not_allowed',405);
      requireThat(env.OPERATOR_API_ENABLED==='true','operator_api_disabled',503);
      originPolicy(request,env.OPERATOR_API_ORIGIN,write);
      const identity=await authenticatedOperator(env,ctx);
      let input={identity,clubId};
      if(method==='candidate'||method==='preview')input.snapshotId=id;
      if(method==='preview') {
        const offset=url.searchParams.get('offset')??'0';
        requireThat(/^(0|[1-9]\d{0,5})$/.test(offset),'invalid_preview_offset');
        input={...input,route:previewRoute,offset:Number(offset)};
      }
      if(method==='reviewStatus')input.reviewId=id;
      if(method==='publication')input.operationId=id;
      if(write) {
        const body=await readJson(request);
        if(method==='review') {
          exactObject(body,['snapshotId','expectedPreviousId','reviewRef']);
          requireThat(HEX64.test(body.snapshotId??'') && (body.expectedPreviousId===null||HEX64.test(body.expectedPreviousId??'')),'invalid_snapshot_id');
          requireThat(typeof body.reviewRef==='string'&&/^[A-Za-z0-9_.:/-]{3,160}$/.test(body.reviewRef),'invalid_review_reference');
          input={...input,...body};
        } else {
          exactObject(body,['reviewId']);requireThat(UUID.test(body.reviewId??''),'invalid_review_id');
          const idempotencyKey=request.headers.get('idempotency-key');
          requireThat(typeof idempotencyKey==='string'&&/^[A-Za-z0-9_-]{16,128}$/.test(idempotencyKey),'idempotency_key_required');
          input={...input,reviewId:body.reviewId,idempotencyKey};
        }
      }
      return json({schemaVersion:1,requestId,data:await callService(env,method,input)},method==='review'?201:200);
    } catch(error) {return apiError(error,requestId);}
  },
};

/** Injectable sink/clock for deterministic tests; defaults emit no private data. */
export function createOperatorGateway({sink,clock=()=>performance.now()}={}){
 const observe=()=>{try{return clock();}catch{return null;}};
 return {async fetch(request,env,ctx){
  const requestId=crypto.randomUUID(),started=observe();
  const response=await gateway.fetch(request,env,ctx,requestId);
  const ended=observe();
  emitRequestMetric(env,request,response,requestId,typeof started==='number'&&typeof ended==='number'?ended-started:NaN,sink,ctx);
  return response;
 }};
}
export default createOperatorGateway();
