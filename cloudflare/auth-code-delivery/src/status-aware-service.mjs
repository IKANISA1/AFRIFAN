import { AuthenticationCodeDeliveryService } from './service.mjs';
import { configuration, inputRequest, exact, demand } from './policy.mjs';
import { receiptRoutes, receiptKey, recipientCommitment, hmac, receiptDb, requireReceipt } from './receipts-policy.mjs';
/** Opt-in decorator. Existing sender remains the only owner of external submission. */
export class StatusAwareDeliveryService {
  constructor(env, options = {}) {
    this.env = env; this.clock = options.clock ?? Date.now;
    this.sender = new AuthenticationCodeDeliveryService(env, options);
  }
  async bind(raw) {
    requireReceipt(this.env.RECEIPT_BINDING_ENABLED === 'true', 'receipt_binding_disabled', 503);
    const now = this.clock(), input = inputRequest(raw, now);
    const config = configuration(this.env, now);
    const route = config.routes.find(r => r.clubId === input.clubId);
    const receiptRoute = receiptRoutes(this.env).find(r => r.clubId === input.clubId);
    requireReceipt(route && receiptRoute && route.phoneNumberId === receiptRoute.phoneNumberId, 'receipt_route_mismatch', 503);
    const db = receiptDb(this.env), key = receiptKey(this.env);
    const recipient = await recipientCommitment(this.env, receiptRoute.businessAccountId, route.phoneNumberId, input.phone.slice(1));
    const binding = await hmac(key, ['wa-binding-v1', input, config.version, route, receiptRoute]);
    // Never retrospectively invent recipient metadata for an older accepted/unknown dispatch.
    await db.prepare(`INSERT INTO delivery_receipt_bindings
      (challenge_id,club_id,business_account_id,phone_number_id,recipient_commitment,binding_commitment,key_version,created_at)
      SELECT ?,?,?,?,?,?,'1',? WHERE NOT EXISTS(SELECT 1 FROM delivery_dispatches WHERE challenge_id=?)
      ON CONFLICT(challenge_id) DO NOTHING`).bind(input.challengeId,input.clubId,receiptRoute.businessAccountId,
        route.phoneNumberId,recipient,binding,now,input.challengeId).run();
    const row = await db.withSession('first-primary').prepare('SELECT * FROM delivery_receipt_bindings WHERE challenge_id=?').bind(input.challengeId).first();
    requireReceipt(row && row.binding_commitment === binding && row.recipient_commitment === recipient &&
      row.club_id === input.clubId && row.business_account_id === receiptRoute.businessAccountId &&
      row.phone_number_id === route.phoneNumberId && row.key_version === '1', 'receipt_binding_conflict', 409);
    return input;
  }
  async deliver(raw) { const input = await this.bind(raw); return this.sender.deliver(input); }
  async deliverWithReceipt(raw) {
    exact(raw, ['challengeId','clubId','phone','code','expiresAt','channel','template']);
    const { template, ...input } = raw;
    const route = configuration(this.env, this.clock()).routes.find(r => r.clubId === input.clubId);
    demand(route && route.templateName === template, 'template_not_approved');
    await this.bind(input);
    return this.sender.deliverWithReceipt(raw);
  }
}
