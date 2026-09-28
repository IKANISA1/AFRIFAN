import {AllocationError,NOW_SQL,configure,demand,uuid,club,exact,normalizeEvidence,normalizeAllocation,hash,safeError} from './policy.mjs';

/** Service-role core only. RPC callers must be reviewed, not browsers/supporter apps. */
export class PaymentAllocationService {
  constructor(env,principalId) { this.env=env; this.db=configure(env); demand(uuid(principalId),'invalid_configuration'); this.principalId=principalId; }
  statement(sql,...args) { return this.db.prepare(sql).bind(...args); }
  async first(sql,...args) { return this.db.withSession('first-primary').prepare(sql).bind(...args).first(); }
  async authority(clubId,capability) {
    configure(this.env); demand(club(clubId));
    const row=await this.first(`SELECT p.revision principal_revision,g.revision grant_revision,c.revision club_revision
      FROM pa_principals p JOIN pa_grants g ON g.principal_id=p.principal_id JOIN pa_clubs c ON c.club_id=g.club_id CROSS JOIN pa_settings s
      WHERE p.principal_id=? AND g.club_id=? AND g.capability=? AND p.enabled=1 AND p.expires_at_ms>${NOW_SQL}
      AND g.enabled=1 AND c.enabled=1 AND s.singleton=1 AND s.purpose='africlub-payment-allocation'
      AND s.writer_mode='isolated-staging' AND s.source_reconciled=1 AND s.historical_claims_verified=1 AND length(s.evidence_ref)>0`,this.principalId,clubId,capability);
    demand(row,'permission_denied'); return row;
  }
  command(id,clubId,capability,requestId,requestHash,authority) {
    return this.statement(`INSERT INTO pa_commands(command_id,principal_id,club_id,capability,request_id,request_sha256,
      principal_revision,grant_revision,club_revision,recorded_at_ms) VALUES(?,?,?,?,?,?,?,?,?,${NOW_SQL})`,id,this.principalId,clubId,capability,requestId,requestHash,
      authority.principal_revision,authority.grant_revision,authority.club_revision);
  }
  async previous(clubId,requestId,requestHash,capability) {
    const row=await this.first('SELECT * FROM pa_commands WHERE principal_id=? AND club_id=? AND request_id=?',this.principalId,clubId,requestId);
    if(row) demand(row.request_sha256===requestHash&&row.capability===capability,'idempotency_conflict');
    return row;
  }
  async ingest(input) {
    try {
      const value=normalizeEvidence(input),{raw,parsed,attestationRef}=value;
      const authority=await this.authority(raw.clubId,'ingest');
      const digest=await hash({raw,parsed,attestationRef});
      const prior=await this.previous(raw.clubId,value.requestId,digest,'ingest');
      const lookup=async()=>{
        const row=await this.first('SELECT evidence_id,source_sha256,club_id FROM pa_evidence WHERE evidence_id=? AND club_id=?',parsed.id,parsed.clubId);
        if(row) demand(row.source_sha256===digest,'evidence_conflict'); return row;
      };
      const existing=await lookup();
      if(prior||existing) { demand(existing,'incomplete_operation'); await this.authority(raw.clubId,'ingest'); return {schemaVersion:1,evidenceId:parsed.id,clubId:parsed.clubId,recorded:true}; }
      const commandId=crypto.randomUUID();
      await this.db.batch([
        this.command(commandId,raw.clubId,'ingest',value.requestId,digest,authority),
        this.statement(`INSERT INTO pa_raw_evidence(raw_id,user_id,club_id,country,provider,raw_sha256,received_at_ms,is_mock) VALUES(?,?,?,?,?,?,?,0)`,raw.id,raw.userId,raw.clubId,raw.country,raw.provider,raw.sha256,raw.receivedAt),
        this.statement(`INSERT INTO pa_evidence(evidence_id,raw_id,command_id,user_id,club_id,country,provider_reference,amount,currency,recipient,direction,parse_status,is_mock,transaction_at_ms,attestation_ref,source_sha256)
          VALUES(?,?,?,?,?,?,?,?,?,?,'debit','parsed',0,?,?,?)`,parsed.id,raw.id,commandId,parsed.userId,parsed.clubId,parsed.country,parsed.providerReference,parsed.amount,parsed.currency,parsed.recipient,parsed.transactionAt,attestationRef,digest)
      ]).catch(async error=>{
        await this.authority(raw.clubId,'ingest');
        await this.previous(raw.clubId,value.requestId,digest,'ingest');
        if(await lookup()) return; throw error;
      });
      await this.authority(raw.clubId,'ingest'); demand(await lookup(),'allocation_unavailable');
      return {schemaVersion:1,evidenceId:parsed.id,clubId:parsed.clubId,recorded:true};
    } catch(error) { throw safeError(error); }
  }
  async receiptForOrder(clubId,orderId) {
    const row=await this.first(`SELECT r.receipt_json FROM pa_receipts r JOIN pa_allocations a ON a.allocation_id=r.allocation_id
      JOIN pa_orders o ON o.order_id=a.order_id WHERE a.order_id=? AND o.club_id=?`,orderId,clubId);
    return row?JSON.parse(row.receipt_json):null;
  }
  async allocate(input) {
    try {
      const value=normalizeAllocation(input),{clubId,orderId,evidenceId,requestId}=value;
      const authority=await this.authority(clubId,'allocate');
      const digest=await hash({clubId,orderId,evidenceId});
      const prior=await this.previous(clubId,requestId,digest,'allocate');
      const lookup=async()=>{
        const receipt=await this.receiptForOrder(clubId,orderId);
        if(receipt) demand(receipt.evidenceId===evidenceId,'allocation_conflict'); return receipt;
      };
      const existing=await lookup();
      if(prior||existing) { demand(existing,'incomplete_operation'); await this.authority(clubId,'allocate'); return existing; }
      const allocationId=crypto.randomUUID(),commandId=crypto.randomUUID(),memberId=crypto.randomUUID();
      // Rejection sampling is not necessary for this identifier: not a secret/authenticator.
      // A collision fails the entire transaction rather than assigning another member's code.
      const memberCode=String(100000+crypto.getRandomValues(new Uint32Array(1))[0]%900000);
      await this.db.batch([
        this.command(commandId,clubId,'allocate',requestId,digest,authority),
        this.statement(`INSERT INTO pa_allocations(allocation_id,command_id,order_id,evidence_id,new_member_id,new_member_code,recorded_at_ms)
          VALUES(?,?,?,?,?,?,${NOW_SQL})`,allocationId,commandId,orderId,evidenceId,memberId,memberCode)
      ]).catch(async error=>{
        await this.authority(clubId,'allocate');
        await this.previous(clubId,requestId,digest,'allocate');
        if(await lookup()) return; throw error;
      });
      await this.authority(clubId,'allocate'); const receipt=await lookup(); demand(receipt,'allocation_unavailable'); return receipt;
    } catch(error) { throw safeError(error); }
  }
  async readReceipt(input) {
    try {
      exact(input,['clubId','orderId']); demand(club(input.clubId)&&uuid(input.orderId));
      await this.authority(input.clubId,'read'); const result=await this.receiptForOrder(input.clubId,input.orderId);
      await this.authority(input.clubId,'read'); demand(result,'not_found'); return result;
    } catch(error) { throw safeError(error); }
  }
}
