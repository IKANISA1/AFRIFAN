import {authenticatedOperator} from './access-identity.mjs';
import {OperatorError, requireThat, exactObject, positiveClub, UUID} from './errors.mjs';
import {json, originPolicy, readJson} from './http.mjs';
export async function callCases(env,method,input) {
  requireThat(env.PAYMENT_EXCEPTION_CASES && typeof env.PAYMENT_EXCEPTION_CASES[method]==='function','case_service_unavailable',503);
  const result=await env.PAYMENT_EXCEPTION_CASES[method](input);
  requireThat(result && typeof result.ok==='boolean','case_service_unavailable',503);
  if(!result.ok) {
    const e=result.error;
    requireThat(e && /^[a-z_]{3,80}$/.test(e.code) && [400,401,403,404,409,410,429,503].includes(e.status),'case_service_unavailable',503);
    throw new OperatorError(e.code,e.status);
  }
  return result.data;
}
/** Return null only when this is not an exception route. Errors are handled by
 * the existing operator gateway's no-store, redacted response envelope. */
export async function paymentExceptionResponse(request,env,ctx,requestId) {
  const url=new URL(request.url);
  const auxiliary=/^\/v1\/admin\/clubs\/([1-9]\d{0,9})\/payment-exceptions\/(session|operations\/([a-f0-9-]+))$/.exec(url.pathname);
  if(auxiliary) {
    const method=auxiliary[2]==='session'?'access':'operation';
    requireThat(!url.search && (method==='access'||UUID.test(auxiliary[3]??'')),'not_found',404);
    requireThat(request.method==='GET','method_not_allowed',405);
    requireThat(env.OPERATOR_API_ENABLED==='true' && env.OPERATOR_CASES_ENABLED==='true','operator_cases_disabled',503);
    originPolicy(request,env.OPERATOR_API_ORIGIN,false);
    const identity=await authenticatedOperator(env,ctx);
    const input={identity,clubId:positiveClub(Number(auxiliary[1])),...(method==='operation'?{operationId:auxiliary[3]}:{})};
    return json({schemaVersion:1,requestId,data:await callCases(env,method,input)});
  }
  const match=/^\/v1\/admin\/clubs\/([1-9]\d{0,9})\/payment-exceptions(?:\/([a-f0-9-]+))?(?:\/(commands|history))?$/.exec(url.pathname);
  if(!match)return null;
  const clubId=positiveClub(Number(match[1])),caseId=match[2],suffix=match[3];
  requireThat(!caseId || UUID.test(caseId),'not_found',404);
  requireThat(!suffix || caseId,'not_found',404);
  const method=suffix==='commands'?'command':suffix==='history'?'history':caseId?'get':'list';
  const write=method==='command';
  requireThat(request.method===(write?'POST':'GET'),'method_not_allowed',405);
  requireThat(env.OPERATOR_API_ENABLED==='true' && env.OPERATOR_CASES_ENABLED==='true','operator_cases_disabled',503);
  originPolicy(request,env.OPERATOR_API_ORIGIN,write,'payment-case-review');
  const identity=await authenticatedOperator(env,ctx);
  let input={identity,clubId};
  if(caseId)input.caseId=caseId;
  const allowed=method==='list'?['after','limit','state']:method==='history'?['after','limit']:[];
  requireThat([...url.searchParams.keys()].every(k=>allowed.includes(k)) &&
    allowed.every(k=>url.searchParams.getAll(k).length<=1),'invalid_query');
  if(method==='list'||method==='history') {
    const limit=url.searchParams.get('limit')??'25';
    requireThat(/^[1-9]\d?$/.test(limit)&&Number(limit)<=50,'invalid_limit');input.limit=Number(limit);
    if(method==='list') {
      input.afterCaseId=url.searchParams.get('after');input.state=url.searchParams.get('state');
    } else {
      const after=url.searchParams.get('after')??'0';
      requireThat(/^(0|[1-9]\d{0,9})$/.test(after),'invalid_cursor');input.afterRevision=Number(after);
    }
  }
  if(write) {
    const body=await readJson(request);exactObject(body,['expectedRevision','action','detail']);
    const operationId=request.headers.get('idempotency-key');
    requireThat(typeof operationId==='string'&&UUID.test(operationId),'idempotency_key_required');
    input={...input,...body,operationId};
  }
  return json({schemaVersion:1,requestId,data:await callCases(env,method,input)});
}
