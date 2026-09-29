import { RECEIPT_LIMITS, ReceiptError, receiptDb, receiptRoutes, receiptKey, requireReceipt, exactKeys, challengeId } from './receipts-policy.mjs';
const linkSelect = `SELECT e.event_id,d.challenge_id,d.club_id,? FROM delivery_status_events e
  JOIN delivery_dispatches d ON d.provider_message_id=e.provider_message_id AND d.state='accepted'
  JOIN delivery_receipt_bindings b ON b.challenge_id=d.challenge_id AND b.club_id=d.club_id
  WHERE e.business_account_id=b.business_account_id AND e.phone_number_id=b.phone_number_id
    AND e.recipient_commitment=b.recipient_commitment AND e.key_version=b.key_version
    AND e.provider_at>=d.created_at-300000 AND e.provider_at<=d.created_at+691200000`;
export class ReceiptStore {
  constructor(env, { clock = Date.now } = {}) { this.env = env; this.clock = clock; this.db = receiptDb(env); receiptKey(env); this.routes = receiptRoutes(env); }
  async persist(events) {
    requireReceipt(Array.isArray(events) && events.length <= RECEIPT_LIMITS.maxEvents);
    if (!events.length) return { stored: 0, linked: 0 };
    const statements = [];
    for (const e of events) {
      statements.push(this.db.prepare(`INSERT INTO delivery_status_events
        (event_id,business_account_id,phone_number_id,provider_message_id,recipient_commitment,key_version,status,provider_at,received_at,error_codes_json)
        VALUES (?,?,?,?,?,'1',?,?,?,?) ON CONFLICT(event_id) DO NOTHING`).bind(e.eventId,e.businessAccountId,e.phoneNumberId,
        e.messageId,e.recipientCommitment,e.status,e.providerAt,this.clock(),JSON.stringify(e.errorCodes)));
      statements.push(this.db.prepare(`INSERT INTO delivery_status_links(event_id,challenge_id,club_id,matched_at)
        ${linkSelect} AND e.event_id=? ON CONFLICT(event_id) DO NOTHING`).bind(this.clock(), e.eventId));
    }
    // HTTP acknowledgement follows durable atomic completion, including idempotent duplicates.
    const result = await this.db.batch(statements);
    return { stored: result.filter((_,i)=>i%2===0).reduce((n,r)=>n+(r.meta?.changes??0),0),
      linked: result.filter((_,i)=>i%2===1).reduce((n,r)=>n+(r.meta?.changes??0),0) };
  }
  async reconcile() {
    requireReceipt(this.env.RECEIPT_RECONCILE_ENABLED === 'true', 'receipt_reconcile_disabled', 503);
    // Only records with a now-known provider acceptance can be selected; unrelated
    // pending rows cannot starve later correlatable rows. A fixed 100-row SQL limit.
    const routePredicates = this.routes.map(()=>'(b.club_id=? AND b.business_account_id=? AND b.phone_number_id=?)').join(' OR ');
    const args = this.routes.flatMap(r=>[r.clubId,r.businessAccountId,r.phoneNumberId]);
    const result = await this.db.prepare(`INSERT INTO delivery_status_links(event_id,challenge_id,club_id,matched_at)
      ${linkSelect} AND NOT EXISTS(SELECT 1 FROM delivery_status_links l WHERE l.event_id=e.event_id)
      AND (${routePredicates}) ORDER BY e.received_at,e.event_id LIMIT ${RECEIPT_LIMITS.reconcileBatch}
      ON CONFLICT(event_id) DO NOTHING`).bind(this.clock(), ...args).run();
    return { linked: result.meta?.changes ?? 0, limit: RECEIPT_LIMITS.reconcileBatch };
  }
  /** Callable only behind a reviewed private binding. Caller authenticates its operator/user. */
  async read(raw) {
    requireReceipt(this.env.RECEIPT_READ_ENABLED === 'true', 'receipt_read_disabled', 503);
    exactKeys(raw, ['challengeId','clubId']);
    requireReceipt(challengeId(raw.challengeId) && Number.isSafeInteger(raw.clubId) && raw.clubId > 0);
    const route = this.routes.find(r=>r.clubId===raw.clubId);
    requireReceipt(route, 'receipt_not_found', 404);
    const primary = this.db.withSession('first-primary');
    const row = await primary.prepare(`SELECT d.state,d.challenge_id,d.club_id FROM delivery_dispatches d
      JOIN delivery_receipt_bindings b ON b.challenge_id=d.challenge_id AND b.club_id=d.club_id
      WHERE d.challenge_id=? AND d.club_id=? AND b.business_account_id=? AND b.phone_number_id=? AND b.key_version='1'`)
      .bind(raw.challengeId,raw.clubId,route.businessAccountId,route.phoneNumberId).first();
    requireReceipt(row, 'receipt_not_found', 404);
    const result = await primary.prepare(`SELECT e.status,e.provider_at,e.error_codes_json FROM delivery_status_events e
      JOIN delivery_status_links l ON l.event_id=e.event_id WHERE l.challenge_id=? AND l.club_id=?
      ORDER BY e.provider_at,e.event_id LIMIT 201`).bind(raw.challengeId,raw.clubId).all();
    requireReceipt(result.results.length <= 200, 'receipt_history_limit', 503);
    const reported={sentAt:null,deliveredAt:null,readAt:null,failedAt:null,deletedAt:null}, codes=new Set();
    for (const e of result.results) {
      const field = `${e.status}At`; reported[field] = Math.max(reported[field]??0, e.provider_at);
      for (const code of JSON.parse(e.error_codes_json)) codes.add(code);
    }
    const progress = reported.readAt!==null?'read':reported.deliveredAt!==null?'delivered':reported.sentAt!==null?'sent':'unknown';
    const conflicting = reported.failedAt!==null && ['delivered','read'].includes(progress);
    const deliveryState = conflicting?'conflicting':reported.failedAt!==null?'failed':progress;
    return {schemaVersion:1,challengeId:raw.challengeId,clubId:raw.clubId,providerAccepted:row.state==='accepted',
      deliveryState,reported,errorCodes:[...codes].sort((a,b)=>a-b),observedEvents:result.results.length,informationOnly:true};
  }
}
