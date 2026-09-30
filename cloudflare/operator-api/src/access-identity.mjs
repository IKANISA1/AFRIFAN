import { requireThat, UUID, HEX64 } from './errors.mjs';

/** Trust only Cloudflare's authenticated runtime context, never incoming identity
 * headers, email addresses, decoded JWTs, body fields or an environment test user.
 * A runtime without ctx.access denies access. There is deliberately no fallback.
 * Source contract: Cloudflare Workers / configuration / cloudflare-access.
 */
export async function authenticatedOperator(env, ctx) {
  requireThat(HEX64.test(env.ACCESS_AUD ?? '') && /^[a-f0-9]{32}$/.test(env.ACCESS_ACCOUNT_ID ?? ''),
    'operator_auth_unconfigured', 503);
  requireThat(ctx?.access && ctx.access.aud === env.ACCESS_AUD &&
    typeof ctx.access.getIdentity === 'function', 'authentication_required', 401);
  let identity;
  try { identity = await ctx.access.getIdentity(); }
  catch { requireThat(false, 'identity_unavailable', 503); }
  requireThat(identity && UUID.test(identity.user_uuid ?? '') &&
    identity.account_id === env.ACCESS_ACCOUNT_ID && !identity.service_token_id &&
    !identity.service_token_status, 'human_operator_required', 401);
  return Object.freeze({ accountId: env.ACCESS_ACCOUNT_ID, audience: env.ACCESS_AUD, subject: identity.user_uuid });
}
