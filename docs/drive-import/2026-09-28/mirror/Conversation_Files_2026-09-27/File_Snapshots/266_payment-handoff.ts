import type {Instruction, Session, Status, RecoveryStore} from './client.js';

/** Explicit native dialer handoff only. Opening a dialer is never payment evidence. */
export interface MembershipReadApi {
  session(): Promise<Session>;
  read(actor: Session, orderId: string): Promise<Status>;
}
export interface NativeDialer {
  /** true = platform reported opened; false = platform reported not opened.
   * Throw or timeout = unknown. Implementations must never retry internally. */
  open(ussdCode: string): Promise<boolean>;
}
export type HandoffPhase = 'reserved' | 'opened' | 'not_opened' | 'unknown';
export type HandoffRecord = Readonly<{
  version: 1; userId: string; clubId: number; orderId: string;
  attemptId: string; phase: HandoffPhase;
}>;
export type PaymentReview = Readonly<{
  reviewId: string; userId: string; clubId: number; sessionId: string;
  orderId: string; tier: string; expiresAt: number;
  instruction: Readonly<Instruction>;
}>;
export class PaymentHandoffError extends Error {
  constructor(public readonly code: string,
    public readonly outcome: 'not_opened' | 'unknown' = 'not_opened') {
    super(code); this.name = 'PaymentHandoffError';
  }
}
const uuid = (x: unknown): x is string => typeof x === 'string' &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(x);
function need(x: unknown, code: string): asserts x { if (!x) throw new PaymentHandoffError(code); }
function actor(s: Session): void {
  need(s?.schemaVersion === 1 && uuid(s.userId) && uuid(s.sessionId) &&
    Number.isSafeInteger(s.clubId) && s.clubId > 0, 'invalid_session');
}
function sameActor(a: Session, b: Session): boolean {
  return a.userId === b.userId && a.clubId === b.clubId && a.sessionId === b.sessionId;
}
function payable(s: Status, a: Session, orderId: string): asserts s is Status & {paymentInstruction: Instruction} {
  need(s?.schemaVersion === 1 && s.clubId === a.clubId && s.orderId === orderId && uuid(orderId), 'invalid_status');
  need(s.status === 'pending_current' && s.paymentEvidenceAllocated === false, 'checkout_not_payable');
  need(Number.isSafeInteger(s.observedAt) && Number.isSafeInteger(s.expiresAt) &&
    s.observedAt >= 0 && s.expiresAt - s.observedAt >= 15000, 'checkout_expiring');
  const p = s.paymentInstruction;
  need(p && typeof p === 'object' && typeof s.tier === 'string' && /^[a-z0-9][a-z0-9_-]{0,31}$/.test(s.tier), 'invalid_instruction');
  need(Number.isSafeInteger(p.amount) && p.amount > 0 && p.amount <= 2147483647 &&
    typeof p.currency === 'string' && /^[A-Z]{3}$/.test(p.currency) && typeof p.country === 'string' && /^[A-Z]{2}$/.test(p.country) &&
    typeof p.provider === 'string' && /^[a-z][a-z0-9_-]{0,63}$/.test(p.provider) && typeof p.recipient === 'string' && /^[0-9]{3,32}$/.test(p.recipient) &&
    typeof p.ussdCode === 'string' && p.ussdCode.length <= 128 && /^\*[0-9*]+#$/.test(p.ussdCode), 'invalid_instruction');
}
function detailsEqual(q: PaymentReview, s: Status & {paymentInstruction: Instruction}): boolean {
  const p = s.paymentInstruction, x = q.instruction;
  return q.orderId === s.orderId && q.clubId === s.clubId && q.tier === s.tier && q.expiresAt === s.expiresAt &&
    p.amount === x.amount && p.currency === x.currency && p.country === x.country &&
    p.provider === x.provider && p.recipient === x.recipient && p.ussdCode === x.ussdCode;
}
function decode(text: string | null, a: Session): HandoffRecord | null {
  if (text === null) return null;
  try {
    need(text.length <= 1024, 'handoff_storage_invalid');
    const v = JSON.parse(text);
    need(v && typeof v === 'object' && !Array.isArray(v) && Object.keys(v).sort().join(',') ===
      'attemptId,clubId,orderId,phase,userId,version' && v.version === 1 && v.userId === a.userId && v.clubId === a.clubId &&
      uuid(v.orderId) && uuid(v.attemptId) && ['reserved','opened','not_opened','unknown'].includes(v.phase), 'handoff_storage_invalid');
    return Object.freeze(v as HandoffRecord);
  } catch { throw new PaymentHandoffError('handoff_storage_invalid'); }
}

/** The store MUST use OS-protected durable storage and a process/isolate-safe lock.
 * Returned reviews are display values, not authority: confirm uses its private copy.
 * No restore, polling, timer, resume or constructor calls a dialer. */
export class PaymentHandoffCoordinator {
  private active: {review: PaymentReview; actor: Session; monotonicAt: number} | null = null;
  private readonly enabled: boolean;
  private generation = 0;
  constructor(private readonly api: MembershipReadApi, private readonly store: RecoveryStore,
    private readonly dialer: NativeDialer,
    private readonly monotonicNow: () => number = () => performance.now(),
    private readonly timeoutMs = 10000, enabled = false) {
    this.enabled = enabled;
    need(api && typeof api.session === 'function' && typeof api.read === 'function' &&
      store && typeof store.load === 'function' && typeof store.compareAndSet === 'function' &&
      typeof store.runExclusive === 'function' && dialer && typeof dialer.open === 'function' &&
      Number.isInteger(timeoutMs) && timeoutMs > 0 && timeoutMs <= 15000, 'handoff_not_configured');
  }
  private gate(): void { need(this.enabled, 'handoff_disabled'); }
  private scope(a: Session): string { return `africlub-payment-handoff-v1:${a.clubId}:${a.userId}`; }
  private fresh(at: number): void {
    const elapsed = this.monotonicNow() - at;
    need(Number.isFinite(elapsed) && elapsed >= 0 && elapsed <= 30000, 'payment_review_expired');
  }
  private unchanged(generation: number): void { need(this.generation===generation,'payment_review_invalidated'); }
  private timely(status: Status, at: number): void {
    this.fresh(at);
    need(status.expiresAt-status.observedAt >= 15000 + this.monotonicNow()-at,'checkout_expiring');
  }
  private async persist(key: string, old: string | null, value: HandoffRecord): Promise<string> {
    const text = JSON.stringify(value);
    need(await this.store.compareAndSet(key, old, text), 'handoff_storage_conflict');
    need(await this.store.load(key) === text, 'handoff_storage_unavailable');
    return text;
  }
  private async priorResolved(a: Session, prior: HandoffRecord | null): Promise<void> {
    if (!prior || prior.phase === 'not_opened') return;
    const previous = await this.api.read(a, prior.orderId);
    need(previous.schemaVersion === 1 && previous.clubId === a.clubId && previous.orderId === prior.orderId &&
      previous.status === 'allocated' && previous.paymentEvidenceAllocated === true, 'unresolved_payment_handoff');
  }
  async review(orderId: string): Promise<PaymentReview> {
    this.gate(); this.active = null; const generation=++this.generation; need(uuid(orderId), 'invalid_order');
    const a = await this.api.session(); actor(a); const key = this.scope(a);
    return this.store.runExclusive(key, async () => {
      await this.priorResolved(a, decode(await this.store.load(key), a));
      const at=this.monotonicNow(); const s = await this.api.read(a, orderId); payable(s,a,orderId);
      const current = await this.api.session(); actor(current); need(sameActor(a,current), 'session_changed');
      const q: PaymentReview = Object.freeze({reviewId:crypto.randomUUID(),userId:a.userId,clubId:a.clubId,
        sessionId:a.sessionId,orderId,tier:s.tier,expiresAt:s.expiresAt,instruction:Object.freeze({...s.paymentInstruction})});
      this.unchanged(generation); this.timely(s,at); need(Number.isFinite(at) && at>=0,'invalid_clock');
      this.active={review:q,actor:Object.freeze({...a}),monotonicAt:at}; return q;
    });
  }
  /** Must be wired to an explicit user action after displaying the review. */
  async confirm(reviewId: string, acknowledgement: boolean): Promise<Readonly<{attemptId:string;platformOpened:boolean|null;paymentVerified:false}>> {
    this.gate(); const active = this.active;
    need(acknowledgement === true && active && active.review.reviewId === reviewId, 'explicit_confirmation_required');
    this.active = null; const generation=this.generation; this.fresh(active.monotonicAt);
    const {review:q,actor:a}=active,key=this.scope(a);
    return this.store.runExclusive(key,async()=>{
      const current=await this.api.session(); actor(current); need(sameActor(a,current),'session_changed');
      const old=await this.store.load(key); await this.priorResolved(a,decode(old,a));
      const startedAt=this.monotonicNow(); const s=await this.api.read(a,q.orderId); payable(s,a,q.orderId);
      need(detailsEqual(q,s),'payment_instruction_changed');
      const final=await this.api.session(); actor(final); need(sameActor(a,final),'session_changed'); this.fresh(active.monotonicAt);
      this.unchanged(generation); this.timely(s,startedAt);
      const reservation:HandoffRecord={version:1,userId:a.userId,clubId:a.clubId,orderId:q.orderId,attemptId:crypto.randomUUID(),phase:'reserved'};
      const saved=await this.persist(key,old,reservation);
      this.unchanged(generation); this.fresh(active.monotonicAt); this.timely(s,startedAt);
      // Once this durable marker exists, a crash must not cause an automatic second handoff.
      let opened:boolean|null=null,timer:ReturnType<typeof setTimeout>|undefined;
      try {
        opened=await Promise.race([this.dialer.open(q.instruction.ussdCode),new Promise<never>((_,reject)=>{
          timer=setTimeout(()=>reject(new Error('handoff_timeout')),this.timeoutMs);
        })]);
        if(typeof opened!=='boolean')opened=null;
      } catch { opened=null; } finally { clearTimeout(timer); }
      const phase:HandoffPhase=opened===true?'opened':opened===false?'not_opened':'unknown';
      try { await this.persist(key,saved,{...reservation,phase}); }
      catch { throw new PaymentHandoffError('handoff_outcome_unknown','unknown'); }
      return Object.freeze({attemptId:reservation.attemptId,platformOpened:opened,paymentVerified:false as const});
    });
  }
  /** Read-only recovery; no dialer, checkout creation, retry, discard or payment claim. */
  async recover(): Promise<Readonly<{record:HandoffRecord;status:Status}>|null> {
    this.gate(); this.active=null; ++this.generation;
    const a=await this.api.session();actor(a);const key=this.scope(a);
    return this.store.runExclusive(key,async()=>{
      const record=decode(await this.store.load(key),a);if(!record)return null;
      const status=await this.api.read(a,record.orderId);
      need(status.schemaVersion===1&&status.orderId===record.orderId&&status.clubId===a.clubId,'invalid_status');
      const current=await this.api.session();actor(current);need(sameActor(a,current),'session_changed');
      return Object.freeze({record,status});
    });
  }
  /** App backgrounding/account switches discard only the in-memory review. */
  invalidateReview(): void { ++this.generation; this.active=null; }
}
