import { authenticatedOperator } from './access-identity.mjs';
import { OperatorError, requireThat, exactObject, positiveClub, UUID, HEX64 } from './errors.mjs';
import { json, apiError, originPolicy, readJson } from './http.mjs';

/** Access-protected operator gateway. No supporter/financial API and no direct SQL.
 * Only the private AuthorizedPublicSourcePublisher service may mutate publication.
 */
export default {
  async fetch(request, env, ctx) {
    const requestId = crypto.randomUUID();
    try {
      const url = new URL(request.url);
      const route = /^\/v1\/admin\/clubs\/([1-9]\d{0,9})\/public-source\/(head|reviews|publications)(?:\/([a-f0-9-]{36}))?$/.exec(url.pathname);
      requireThat(route && !url.search, 'not_found',404);
      const clubId = positiveClub(Number(route[1])); const resource = route[2]; const resourceId = route[3];
      const read = resource === 'head' && !resourceId || resource === 'publications' && resourceId && UUID.test(resourceId);
      const write = !resourceId && ['reviews','publications'].includes(resource);
      requireThat(read || write, 'not_found',404);
      requireThat(request.method === (read ? 'GET' : 'POST'), 'method_not_allowed',405);
      requireThat(env.OPERATOR_API_ENABLED === 'true', 'operator_api_disabled',503);
      originPolicy(request,env.OPERATOR_API_ORIGIN,write);
      const identity = await authenticatedOperator(env,ctx);
      requireThat(env.PUBLIC_SOURCE_PUBLISHER && typeof env.PUBLIC_SOURCE_PUBLISHER.review === 'function',
        'publication_service_unavailable',503);
      let result;
      if(read) result = resource === 'head'
        ? await env.PUBLIC_SOURCE_PUBLISHER.head({identity,clubId})
        : await env.PUBLIC_SOURCE_PUBLISHER.publication({identity,clubId,operationId:resourceId});
      else {
        const body = await readJson(request);
        if (resource === 'reviews') {
          exactObject(body,['snapshotId','expectedPreviousId','reviewRef']);
          requireThat(HEX64.test(body.snapshotId ?? '') && (body.expectedPreviousId === null || HEX64.test(body.expectedPreviousId ?? '')), 'invalid_snapshot_id');
          requireThat(typeof body.reviewRef === 'string' && /^[A-Za-z0-9_.:/-]{3,160}$/.test(body.reviewRef), 'invalid_review_reference');
          result = await env.PUBLIC_SOURCE_PUBLISHER.review({identity,clubId,...body});
        } else {
          exactObject(body,['reviewId']); requireThat(UUID.test(body.reviewId ?? ''),'invalid_review_id');
          const idempotencyKey = request.headers.get('idempotency-key');
          requireThat(typeof idempotencyKey === 'string' && /^[A-Za-z0-9_-]{16,128}$/.test(idempotencyKey), 'idempotency_key_required');
          result = await env.PUBLIC_SOURCE_PUBLISHER.publish({identity,clubId,reviewId:body.reviewId,idempotencyKey});
        }
      }
      // RPC errors are serializable envelopes, not implementation exceptions.
      requireThat(result && typeof result.ok === 'boolean','publication_service_unavailable',503);
      if(!result.ok) {
        const e=result.error;
        requireThat(e && /^[a-z_]{3,80}$/.test(e.code) && [400,401,403,404,409,410,429,503].includes(e.status),
          'publication_service_unavailable',503);
        throw new OperatorError(e.code,e.status);
      }
      return json({schemaVersion:1,requestId,data:result.data},write && resource === 'reviews' ? 201 : 200);
    } catch(error) { return apiError(error,requestId); }
  },
};
