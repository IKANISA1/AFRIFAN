import { primarySession, verifySnapshot, sha256, SNAPSHOT_TTL_MS, PublicationError } from './snapshot-publication.mjs';
import { OperatorError, requireThat, exactObject, positiveClub, UUID, HEX64 } from '../../operator-api/src/errors.mjs';
export const REVIEW_TTL_MS = 5 * 60_000;
const GRANT_SELECT = `SELECT p.principal_id,p.revision principal_revision,g.revision grant_revision,t.revision tenant_revision,
 t.source_club_id,g.can_review,g.can_publish,g.expires_at_ms FROM public_operator_principals p
 JOIN public_operator_grants g ON g.principal_id=p.principal_id JOIN public_operator_tenants t ON t.club_id=g.club_id
 WHERE p.access_account_id=? AND p.access_subject=? AND g.club_id=? AND p.enabled=1 AND g.enabled=1 AND t.enabled=1
 AND g.expires_at_ms>?`;
const LIVE_REVIEW = `SELECT r.* FROM public_operator_reviews r
 JOIN public_operator_principals p ON p.principal_id=r.principal_id
 JOIN public_operator_grants g ON g.principal_id=r.principal_id AND g.club_id=r.club_id
 JOIN public_operator_tenants t ON t.club_id=r.club_id
 JOIN public_snapshots s ON s.snapshot_id=r.snapshot_id
 WHERE r.review_id=? AND r.principal_id=? AND r.club_id=? AND r.state='ready' AND r.expires_at_ms>?
 AND p.enabled=1 AND g.enabled=1 AND t.enabled=1 AND g.can_review=1 AND g.can_publish=1 AND g.expires_at_ms>?
 AND r.expires_at_ms>(julianday('now')-2440587.5)*86400000 AND g.expires_at_ms>(julianday('now')-2440587.5)*86400000
 AND r.principal_revision=p.revision AND r.grant_revision=g.revision AND r.tenant_revision=t.revision
 AND s.source_club_id=t.source_club_id`;
const CAPTURE_FRESH = `AND julianday(s.captured_at_utc) IS NOT NULL
 AND (julianday(s.captured_at_utc)-2440587.5)*86400000 > ?
 AND (julianday(s.captured_at_utc)-2440587.5)*86400000 <= ?
 AND julianday(s.captured_at_utc)>julianday('now')-1
 AND julianday(s.captured_at_utc)<=julianday('now')+(5.0/1440)`;

/** All authorization, review, publication receipt and audit rows live in the same
 * D1 database as the public head. No cross-database commit is assumed.
 * D1 batch performs authorization recheck, head CAS, review consumption and audit
 * together. Object verification seals the candidate beforehand; it never approves.
 */
export class OperatorPublicationService {
  constructor(env, {clock = () => Date.now()} = {}) {
    this.env=env; this.clock=clock; this.db=env.RAYON_PUBLIC_DB ? primarySession(env.RAYON_PUBLIC_DB) : null;
  }
  async scope(identity, clubId, action) {
    requireThat(this.env.PUBLICATION_ENABLED==='true' && this.db,'publication_disabled',503);
    positiveClub(clubId);
    requireThat(/^[1-9]\d*$/.test(this.env.TARGET_CLUB_ID ?? '') && Number(this.env.TARGET_CLUB_ID)===clubId,'club_not_available',404);
    requireThat(HEX64.test(this.env.ACCESS_AUD ?? '') && /^[a-f0-9]{32}$/.test(this.env.ACCESS_ACCOUNT_ID ?? ''),'operator_auth_unconfigured',503);
    exactObject(identity,['accountId','audience','subject'],'invalid_identity_context');
    requireThat(identity.accountId===this.env.ACCESS_ACCOUNT_ID && identity.audience===this.env.ACCESS_AUD && UUID.test(identity.subject ?? ''),'invalid_identity_context',403);
    const grant=await this.db.prepare(GRANT_SELECT).bind(identity.accountId,identity.subject,clubId,this.clock()).first();
    requireThat(grant && UUID.test(grant.principal_id) &&
      (action==='review'?grant.can_review===1:action==='publish'?grant.can_publish===1:grant.can_review===1||grant.can_publish===1),'operator_not_authorized',403);
    return grant;
  }
  async rate(grant,clubId) {
    const now=this.clock(), window=Math.floor(now/60_000)*60_000;
    // Per-principal, per-club, atomic counter. WAF/Access handle unauthenticated abuse.
    const row=await this.db.prepare(`INSERT INTO public_operator_rate_windows(principal_id,club_id,window_start_ms,calls)
 VALUES(?,?,?,1) ON CONFLICT(principal_id,club_id,window_start_ms) DO UPDATE SET calls=calls+1 RETURNING calls`)
      .bind(grant.principal_id,clubId,window).first();
    requireThat(row && Number.isSafeInteger(row.calls),'rate_control_unavailable',503);
    await this.db.prepare('DELETE FROM public_operator_rate_windows WHERE window_start_ms<?').bind(window-120_000).run();
    requireThat(row.calls<=30,'rate_limited',429);
  }
  async currentHead() {
    const h=await this.db.prepare('SELECT snapshot_id FROM public_snapshot_head WHERE singleton=1').first();
    return h?.snapshot_id??null;
  }
  async head(input) {
    exactObject(input,['identity','clubId']);
    const g=await this.scope(input.identity,input.clubId,'read');await this.rate(g,input.clubId);
    const h=await this.db.prepare(`SELECT s.snapshot_id,s.source_club_id,s.captured_at_utc,s.activated_at_utc
 FROM public_snapshot_head h JOIN public_snapshots s ON s.snapshot_id=h.snapshot_id WHERE h.singleton=1 AND s.status='active'`).first();
    requireThat(!h||h.source_club_id===g.source_club_id,'tenant_mapping_conflict',409);
    const captured=h?Date.parse(h.captured_at_utc):NaN, now=this.clock();
    return {clubId:input.clubId,snapshotId:h?.snapshot_id??null,capturedAt:h?.captured_at_utc??null,
      activatedAt:h?.activated_at_utc??null,fresh:Number.isFinite(captured)&&captured<=now+300_000&&now-captured<SNAPSHOT_TTL_MS};
  }
  async review(input) {
    exactObject(input,['identity','clubId','snapshotId','expectedPreviousId','reviewRef']);
    const {identity,clubId,snapshotId,expectedPreviousId,reviewRef}=input;
    requireThat(HEX64.test(snapshotId??'')&&(expectedPreviousId===null||HEX64.test(expectedPreviousId??'')),'invalid_snapshot_id');
    requireThat(typeof reviewRef==='string'&&/^[A-Za-z0-9_.:/-]{3,160}$/.test(reviewRef),'invalid_review_reference');
    let g=await this.scope(identity,clubId,'review');await this.rate(g,clubId);
    requireThat(await this.currentHead()===expectedPreviousId,'publication_conflict',409);
    const s=await this.db.prepare('SELECT source_club_id,status FROM public_snapshots WHERE snapshot_id=?').bind(snapshotId).first();
    requireThat(s&&s.source_club_id===g.source_club_id,'snapshot_not_found',404);
    requireThat(['importing','sealed','verified'].includes(s.status),'snapshot_not_reviewable',409);
    try { await verifySnapshot(this.db,this.env.RAYON_PUBLIC_MEDIA,snapshotId,new Date(this.clock())); }
    catch(error) { if(error instanceof PublicationError)throw new OperatorError(error.code,409);throw error; }
    g=await this.scope(identity,clubId,'review');
    const now=this.clock(), expiresAt=Math.min(now+REVIEW_TTL_MS,g.expires_at_ms),reviewId=crypto.randomUUID(),nonce=crypto.randomUUID();
    const guard=`INSERT INTO public_operator_guards(nonce,passed) SELECT ?,CASE WHEN EXISTS(
 SELECT 1 FROM public_operator_principals p JOIN public_operator_grants g ON g.principal_id=p.principal_id
 JOIN public_operator_tenants t ON t.club_id=g.club_id JOIN public_snapshots s ON s.source_club_id=t.source_club_id
 WHERE p.principal_id=? AND p.access_account_id=? AND p.access_subject=? AND g.club_id=?
 AND p.enabled=1 AND g.enabled=1 AND t.enabled=1 AND g.can_review=1 AND g.expires_at_ms>?
 AND g.expires_at_ms>(julianday('now')-2440587.5)*86400000
 AND p.revision=? AND g.revision=? AND t.revision=? AND s.snapshot_id=? AND s.status='verified' ${CAPTURE_FRESH})
 AND (SELECT snapshot_id FROM public_snapshot_head WHERE singleton=1) IS ? THEN 1 ELSE 0 END`;
    try {
      await this.db.batch([
        this.db.prepare(guard).bind(nonce,g.principal_id,identity.accountId,identity.subject,clubId,now,
          g.principal_revision,g.grant_revision,g.tenant_revision,snapshotId,now-SNAPSHOT_TTL_MS,now+300_000,expectedPreviousId),
        this.db.prepare(`INSERT INTO public_operator_reviews(review_id,principal_id,club_id,snapshot_id,expected_previous_id,review_ref,
 reviewed_at_ms,expires_at_ms,principal_revision,grant_revision,tenant_revision) VALUES(?,?,?,?,?,?,?,?,?,?,?)`)
          .bind(reviewId,g.principal_id,clubId,snapshotId,expectedPreviousId,reviewRef,now,expiresAt,g.principal_revision,g.grant_revision,g.tenant_revision),
        this.db.prepare(`INSERT INTO public_operator_audit VALUES(?,?,?,?,?,?,?,?,?,?)`)
          .bind(crypto.randomUUID(),'snapshot_reviewed',g.principal_id,clubId,reviewId,null,snapshotId,expectedPreviousId,now,reviewRef),
        this.db.prepare('DELETE FROM public_operator_guards WHERE nonce=?').bind(nonce),
      ]);
    } catch {
      await this.scope(identity,clubId,'review');
      requireThat(await this.currentHead()===expectedPreviousId,'publication_conflict',409);
      throw new OperatorError('review_commit_failed',503);
    }
    const counts=await this.db.prepare(`SELECT (SELECT COUNT(*) FROM public_snapshot_records WHERE snapshot_id=?) row_count,
 (SELECT COUNT(*) FROM public_snapshot_media WHERE snapshot_id=?) media_count`).bind(snapshotId,snapshotId).first();
    return {reviewId,clubId,snapshotId,expectedPreviousId,reviewRef,expiresAt:new Date(expiresAt).toISOString(),
      rowCount:counts.row_count,mediaCount:counts.media_count};
  }
  async completed(g,clubId,keyHash,requestHash) {
    const row=await this.db.prepare(`SELECT result_json,request_sha256 FROM public_operator_publications
 WHERE principal_id=? AND club_id=? AND key_sha256=?`).bind(g.principal_id,clubId,keyHash).first();
    if(!row)return null;
    requireThat(row.request_sha256===requestHash,'idempotency_conflict',409);
    return {...JSON.parse(row.result_json),replayed:true};
  }
  async reviewForPublish(reviewId,g,clubId,now) {
    const row=await this.db.prepare(LIVE_REVIEW).bind(reviewId,g.principal_id,clubId,now,now).first();
    if(row)return row;
    const existing=await this.db.prepare('SELECT expires_at_ms FROM public_operator_reviews WHERE review_id=? AND principal_id=? AND club_id=?')
      .bind(reviewId,g.principal_id,clubId).first();
    requireThat(existing,'review_not_found',404);
    requireThat(existing.expires_at_ms>now,'review_expired',410);
    throw new OperatorError('review_no_longer_authorized',409);
  }
  async publish(input) {
    try { return await this.publishOnce(input); }
    catch(error) {
      // A concurrent identical request can commit while this request is still
      // rechecking the review. Recover the receipt even before our own batch.
      if (!(error instanceof OperatorError) || ![409,410].includes(error.status)) throw error;
      const {identity,clubId,reviewId,idempotencyKey}=input;
      const g=await this.scope(identity,clubId,'publish');
      const receipt=await this.completed(g,clubId,await sha256(idempotencyKey),
        await sha256(JSON.stringify([1,g.principal_id,clubId,reviewId])));
      if(receipt)return receipt;
      throw error;
    }
  }
  async publishOnce(input) {
    exactObject(input,['identity','clubId','reviewId','idempotencyKey']);
    const {identity,clubId,reviewId,idempotencyKey}=input;
    requireThat(UUID.test(reviewId??''),'invalid_review_id');
    requireThat(typeof idempotencyKey==='string'&&/^[A-Za-z0-9_-]{16,128}$/.test(idempotencyKey),'idempotency_key_required');
    const g=await this.scope(identity,clubId,'publish');await this.rate(g,clubId);
    const keyHash=await sha256(idempotencyKey),requestHash=await sha256(JSON.stringify([1,g.principal_id,clubId,reviewId]));
    const done=await this.completed(g,clubId,keyHash,requestHash);if(done)return done;
    let r=await this.reviewForPublish(reviewId,g,clubId,this.clock());
    requireThat(await this.currentHead()===r.expected_previous_id,'publication_conflict',409);
    try { await verifySnapshot(this.db,this.env.RAYON_PUBLIC_MEDIA,r.snapshot_id,new Date(this.clock())); }
    catch(error) { if(error instanceof PublicationError)throw new OperatorError(error.code,409);throw error; }
    if (r.expected_previous_id !== null) {
      const previous=await this.db.prepare('SELECT captured_at_utc FROM public_snapshots WHERE snapshot_id=?').bind(r.expected_previous_id).first();
      const candidate=await this.db.prepare('SELECT captured_at_utc FROM public_snapshots WHERE snapshot_id=?').bind(r.snapshot_id).first();
      requireThat(previous && candidate && Date.parse(candidate.captured_at_utc)>=Date.parse(previous.captured_at_utc),'snapshot_regression',409);
    }
    // Verify grants/review again after potentially slow media verification.
    await this.scope(identity,clubId,'publish'); const now=this.clock();
    r=await this.reviewForPublish(reviewId,g,clubId,now);
    const operationId=crypto.randomUUID(),nonce=crypto.randomUUID();
    const result={operationId,clubId,snapshotId:r.snapshot_id,previousSnapshotId:r.expected_previous_id,
      reviewId,publishedAt:new Date(now).toISOString(),status:'published',replayed:false};
    // Journal/head/approval/review/audit share ONE atomic D1 commit. Failure and
    // unknown-outcome retries always reuse the same key; there is no second writer.
    const guard=`INSERT INTO public_operator_guards(nonce,passed) SELECT ?,CASE WHEN EXISTS(
 ${LIVE_REVIEW} AND s.status='verified' ${CAPTURE_FRESH}
 AND (r.expected_previous_id IS NULL OR julianday(s.captured_at_utc)>=(SELECT julianday(captured_at_utc) FROM public_snapshots WHERE snapshot_id=r.expected_previous_id)))
 AND (SELECT snapshot_id FROM public_snapshot_head WHERE singleton=1) IS ? THEN 1 ELSE 0 END`;
    try {
      await this.db.batch([
        this.db.prepare(guard).bind(nonce,reviewId,g.principal_id,clubId,now,now,now-SNAPSHOT_TTL_MS,now+300_000,r.expected_previous_id),
        this.db.prepare("UPDATE public_snapshots SET status='retired' WHERE status='active' AND snapshot_id=?").bind(r.expected_previous_id),
        this.db.prepare("UPDATE public_snapshots SET status='active',approved_by=?,approval_ref=?,activated_at_utc=? WHERE snapshot_id=? AND status='verified'")
          .bind(g.principal_id,r.review_ref,new Date(now).toISOString(),r.snapshot_id),
        this.db.prepare('INSERT INTO public_snapshot_head(singleton,snapshot_id) VALUES(1,?) ON CONFLICT(singleton) DO UPDATE SET snapshot_id=excluded.snapshot_id').bind(r.snapshot_id),
        this.db.prepare("UPDATE public_operator_reviews SET state='consumed' WHERE review_id=? AND state='ready'").bind(reviewId),
        this.db.prepare('INSERT INTO public_operator_publications VALUES(?,?,?,?,?,?,?,?,?,?)')
          .bind(operationId,g.principal_id,clubId,keyHash,requestHash,reviewId,r.snapshot_id,r.expected_previous_id,now,JSON.stringify(result)),
        this.db.prepare('INSERT INTO public_operator_audit VALUES(?,?,?,?,?,?,?,?,?,?)')
          .bind(crypto.randomUUID(),'snapshot_published',g.principal_id,clubId,reviewId,operationId,r.snapshot_id,r.expected_previous_id,now,r.review_ref),
        this.db.prepare('DELETE FROM public_operator_guards WHERE nonce=?').bind(nonce),
      ]);
    } catch {
      // An RPC/DB response may be lost after COMMIT. Prefer its recorded result.
      await this.scope(identity,clubId,'publish');
      const concurrent=await this.completed(g,clubId,keyHash,requestHash);if(concurrent)return concurrent;
      await this.reviewForPublish(reviewId,g,clubId,this.clock());
      requireThat(await this.currentHead()===r.expected_previous_id,'publication_conflict',409);
      throw new OperatorError('publication_commit_failed',503);
    }
    return result;
  }
  async publication(input) {
    exactObject(input,['identity','clubId','operationId']); requireThat(UUID.test(input.operationId??''),'invalid_operation_id');
    const g=await this.scope(input.identity,input.clubId,'read');await this.rate(g,input.clubId);
    const row=await this.db.prepare('SELECT result_json FROM public_operator_publications WHERE operation_id=? AND principal_id=? AND club_id=?')
      .bind(input.operationId,g.principal_id,input.clubId).first();
    requireThat(row,'publication_not_found',404);
    return {...JSON.parse(row.result_json),replayed:true};
  }
}
/** Called by the private WorkerEntrypoint. No trust in exception serialization. */
export async function serviceResult(service,method,input) {
  try { return {ok:true,data:await service[method](input)}; }
  catch(error) { return {ok:false,error:{code:error instanceof OperatorError?error.code:'service_unavailable',status:error instanceof OperatorError?error.status:503}}; }
}
