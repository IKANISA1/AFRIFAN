import {NOW_SQL, CaseError, demand, exact, checkBase, checkCaseId, validateCommand, digest, safeError, STATES, UUID} from './policy.mjs';
const SNAPSHOT = `case_id,club_id,category,order_id,evidence_id,state,revision,head_event_id,disposition,
 proposer_subject,proposal_digest,reviewer_subject,review_event_id,created_at_ms,updated_at_ms`;
function publicCase(row) {
  if (!row) return null;
  return {caseId:row.case_id, clubId:row.club_id, category:row.category, orderId:row.order_id, evidenceId:row.evidence_id,
    state:row.state, revision:row.revision, headEventId:row.head_event_id, disposition:row.disposition,
    proposerSubject:row.proposer_subject, proposalDigest:row.proposal_digest, reviewerSubject:row.reviewer_subject,
    reviewEventId:row.review_event_id, createdAt:row.created_at_ms, updatedAt:row.updated_at_ms,
    financialEffect:'none', referencesVerified:false};
}
function publicEvent(row) {
  return {eventId:row.event_id, operationId:row.operation_id, caseId:row.case_id, clubId:row.club_id,
    revision:row.expected_revision+1, actorSubject:row.actor_subject, action:row.action,
    reasonCode:row.reason_code, evidenceDigest:row.evidence_digest, disposition:row.disposition,
    recordedAt:row.created_at_ms, financialEffect:'none'};
}
/** Bound callers must derive identity from trusted Access context. ACL and write
 * authorization are rechecked in the SAME case database at the insert boundary. */
export class PaymentExceptionService {
  constructor(env) { this.env = env; this.db = env.PAYMENT_CASE_DB; }
  session() {
    demand(this.env.PAYMENT_CASES_ENABLED==='true' && ['isolated-staging','production'].includes(this.env.PAYMENT_CASES_ENVIRONMENT), 'case_service_disabled',503);
    demand(this.db && typeof this.db.withSession==='function','case_service_unavailable',503);
    return this.db.withSession('first-primary');
  }
  async first(sql,...args) { return this.session().prepare(sql).bind(...args).first(); }
  async authority(identity,clubId,role=null) {
    const row=await this.first(`SELECT 1 allowed FROM px_settings s JOIN px_clubs c ON c.club_id=?
      JOIN px_operators o ON o.subject=? JOIN px_grants g ON g.subject=o.subject AND g.club_id=c.club_id
      WHERE s.id=1 AND s.enabled=1 AND s.environment=? AND c.enabled=1 AND o.enabled=1 AND g.enabled=1
      AND o.expires_at_ms>${NOW_SQL} AND s.account_id=? AND s.audience=? AND o.account_id=s.account_id AND o.audience=s.audience
      AND (? IS NULL OR g.role=?) LIMIT 1`,clubId,identity.subject,this.env.PAYMENT_CASES_ENVIRONMENT,
      identity.accountId,identity.audience,role,role);
    demand(row,'forbidden',403);
  }
  /** Read-only UI capabilities; every later command rechecks actual authority. */
  async access(input) {
    try {
      checkBase(input,['identity','clubId']);
      await this.authority(input.identity,input.clubId);
      const rows=(await this.session().prepare(`SELECT role FROM px_grants WHERE subject=? AND club_id=? AND enabled=1`)
        .bind(input.identity.subject,input.clubId).all()).results;
      demand(Array.isArray(rows),'case_service_unavailable',503);
      await this.authority(input.identity,input.clubId);
      return {schemaVersion:1,subject:input.identity.subject,clubId:input.clubId,
        canRead:true,canMake:rows.some(r=>r.role==='maker'),canReview:rows.some(r=>r.role==='checker'),financialEffect:'none'};
    } catch(error) {throw safeError(error);}
  }
  /** Original actor only. Missing means not observed, never proof of no in-flight write. */
  async operation(input) {
    try {
      checkBase(input,['identity','clubId','operationId']);checkCaseId(input.operationId);
      await this.authority(input.identity,input.clubId);
      const row=await this.first(`SELECT * FROM px_events WHERE club_id=? AND actor_subject=? AND operation_id=?`,
        input.clubId,input.identity.subject,input.operationId);
      await this.authority(input.identity,input.clubId);demand(row,'not_found',404);
      const currentCase=await this.get({identity:input.identity,clubId:input.clubId,caseId:row.case_id});
      return {schemaVersion:1,replayed:true,outcome:publicEvent(row),currentCase};
    } catch(error) {throw safeError(error);}
  }
  async get(input) {
    try {
      checkBase(input,['identity','clubId','caseId']);checkCaseId(input.caseId);
      await this.authority(input.identity,input.clubId);
      const row=await this.first(`SELECT ${SNAPSHOT} FROM px_cases WHERE club_id=? AND case_id=?`,input.clubId,input.caseId);
      await this.authority(input.identity,input.clubId);demand(row,'not_found',404);
      return publicCase(row);
    } catch(error) { throw safeError(error); }
  }
  async list(input) {
    try {
      checkBase(input,['identity','clubId','afterCaseId','limit','state']);
      demand(input.afterCaseId===null || (typeof input.afterCaseId==='string' && UUID.test(input.afterCaseId)),'invalid_cursor');
      demand(Number.isInteger(input.limit)&&input.limit>=1&&input.limit<=50,'invalid_limit');
      demand(input.state===null || STATES.includes(input.state),'invalid_state');
      await this.authority(input.identity,input.clubId);
      const filter=input.state===null?'':' AND state=?';
      const args=[input.clubId,input.afterCaseId??'',...(input.state===null?[]:[input.state]),input.limit+1];
      const rows=(await this.session().prepare(`SELECT ${SNAPSHOT} FROM px_cases WHERE club_id=? AND case_id>?${filter} ORDER BY case_id LIMIT ?`).bind(...args).all()).results;
      demand(Array.isArray(rows),'case_service_unavailable',503);
      await this.authority(input.identity,input.clubId);
      const page=rows.slice(0,input.limit);
      return {cases:page.map(publicCase),nextCaseId:rows.length>input.limit?page.at(-1).case_id:null,snapshot:false};
    } catch(error) { throw safeError(error); }
  }
  async history(input) {
    try {
      checkBase(input,['identity','clubId','caseId','afterRevision','limit']);checkCaseId(input.caseId);
      demand(Number.isSafeInteger(input.afterRevision)&&input.afterRevision>=0&&input.afterRevision<=2147483647,'invalid_cursor');
      demand(Number.isInteger(input.limit)&&input.limit>=1&&input.limit<=50,'invalid_limit');
      await this.get({identity:input.identity,clubId:input.clubId,caseId:input.caseId});
      const rows=(await this.session().prepare(`SELECT * FROM px_events WHERE club_id=? AND case_id=? AND expected_revision>=? ORDER BY expected_revision LIMIT ?`)
        .bind(input.clubId,input.caseId,input.afterRevision,input.limit+1).all()).results;
      demand(Array.isArray(rows),'case_service_unavailable',503);
      await this.authority(input.identity,input.clubId);
      const page=rows.slice(0,input.limit);
      return {events:page.map(publicEvent),nextRevision:rows.length>input.limit?page.at(-1).expected_revision+1:null};
    } catch(error) { throw safeError(error); }
  }
  async command(input) {
    try {
      validateCommand(input);
      const role=['approve','reject'].includes(input.action)?'checker':'maker';
      await this.authority(input.identity,input.clubId,role);
      const requestHash=await digest(input);
      const outcome=()=>this.first(`SELECT * FROM px_events WHERE club_id=? AND actor_subject=? AND operation_id=?`,
        input.clubId,input.identity.subject,input.operationId);
      let recorded=await outcome();let replayed=Boolean(recorded);
      if(recorded) demand(recorded.request_hash===requestHash,'idempotency_conflict',409);
      else {
        // Current authorization, expected revision and state transition are checked
        // inside the INSERT trigger, not just by an earlier service-level read.
        const d=input.detail;
        try {
          const result=await this.session().prepare(`INSERT INTO px_events(event_id,case_id,club_id,operation_id,request_hash,
            expected_revision,actor_subject,account_id,audience,environment,action,reason_code,evidence_digest,category,order_id,evidence_id,disposition)
            VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`)
            .bind(crypto.randomUUID(),input.caseId,input.clubId,input.operationId,requestHash,input.expectedRevision,
              input.identity.subject,input.identity.accountId,input.identity.audience,this.env.PAYMENT_CASES_ENVIRONMENT,input.action,d.reasonCode,d.evidenceDigest,
              d.category??null,d.orderId??null,d.evidenceId??null,d.disposition??null).run();
          demand(result.success!==false && result.meta?.changes>=1,'case_service_unavailable',503);
        } catch(error) {
          // Includes a response lost AFTER commit. Never invent another operation.
          await this.authority(input.identity,input.clubId,role);
          recorded=await outcome();
          if(!recorded) throw error;
          demand(recorded.request_hash===requestHash,'idempotency_conflict',409);replayed=true;
        }
        recorded=recorded??await outcome();
        demand(recorded && recorded.request_hash===requestHash,'case_service_unavailable',503);
      }
      await this.authority(input.identity,input.clubId,role);
      const currentCase=await this.get({identity:input.identity,clubId:input.clubId,caseId:input.caseId});
      // The original outcome revision and the current head are deliberately distinct.
      return {schemaVersion:1,replayed,outcome:publicEvent(recorded),currentCase};
    } catch(error) { throw safeError(error); }
  }
}
