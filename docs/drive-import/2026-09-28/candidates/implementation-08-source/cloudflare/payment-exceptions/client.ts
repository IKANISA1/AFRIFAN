export type CaseState = 'open'|'investigating'|'awaiting_review'|'reviewed'|'closed';
export type CaseAction = 'open'|'triage'|'propose'|'approve'|'reject'|'close'|'reopen';
export type Category = 'late'|'partial'|'duplicate'|'ambiguous'|'missing_reference'|'cancelled_order'|'refund_request';
export type Disposition = 'no_financial_change'|'refer_reconciliation'|'refer_refund_review';
export type Reason = 'support_request'|'evidence_received'|'needs_investigation'|'review_complete'|'insufficient_evidence'|'external_referral'|'new_evidence';
export type Detail = {reasonCode:Reason;evidenceDigest:string|null;category?:Category;orderId?:string|null;evidenceId?:string|null;disposition?:Disposition};
export interface CaseRecord {
  caseId:string;clubId:number;category:Category;orderId:string|null;evidenceId:string|null;state:CaseState;revision:number;
  headEventId:string;disposition:Disposition|null;proposerSubject:string|null;proposalDigest:string|null;
  reviewerSubject:string|null;reviewEventId:string|null;createdAt:number;updatedAt:number;
  financialEffect:'none';referencesVerified:false;
}
export interface CaseEvent {
  eventId:string;operationId:string;caseId:string;clubId:number;revision:number;actorSubject:string;
  action:CaseAction;reasonCode:Reason;evidenceDigest:string|null;disposition:Disposition|null;recordedAt:number;financialEffect:'none';
}
export interface CaseAccess {schemaVersion:1;subject:string;clubId:number;canRead:true;canMake:boolean;canReview:boolean;financialEffect:'none';}
export interface CommandResult {schemaVersion:1;replayed:boolean;outcome:CaseEvent;currentCase:CaseRecord;}
export class CaseClientError extends Error {
  constructor(public readonly code:string,public readonly status:number,public readonly outcomeUnknown=false) {super(code);}
}
const uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/;
const hex=/^[a-f0-9]{64}$/;
const states=['open','investigating','awaiting_review','reviewed','closed'];
const actions=['open','triage','propose','approve','reject','close','reopen'];
const categories=['late','partial','duplicate','ambiguous','missing_reference','cancelled_order','refund_request'];
const dispositions=['no_financial_change','refer_reconciliation','refer_refund_review'];
const reasons=['support_request','evidence_received','needs_investigation','review_complete','insufficient_evidence','external_referral','new_evidence'];
function valid(ok:unknown):asserts ok {if(!ok)throw new CaseClientError('invalid_response',503,true);}
function obj(x:unknown):Record<string,unknown> {valid(x!==null&&typeof x==='object'&&!Array.isArray(x));return x as Record<string,unknown>;}
function id(x:unknown):x is string {return typeof x==='string'&&uuid.test(x);}
function nullableId(x:unknown):boolean {return x===null||id(x);}
function nullableDigest(x:unknown):boolean {return x===null||(typeof x==='string'&&hex.test(x));}
function integer(x:unknown,min=0):x is number {return Number.isSafeInteger(x)&&Number(x)>=min;}
function nullableEnum(x:unknown,allowed:string[]):boolean {return x===null||(typeof x==='string'&&allowed.includes(x));}
export function decodeCase(value:unknown):CaseRecord {
  const r=obj(value);
  valid(id(r.caseId)&&integer(r.clubId,1)&&typeof r.category==='string'&&categories.includes(r.category)&&
    nullableId(r.orderId)&&nullableId(r.evidenceId)&&typeof r.state==='string'&&states.includes(r.state)&&integer(r.revision,1)&&
    id(r.headEventId)&&nullableEnum(r.disposition,dispositions)&&nullableId(r.proposerSubject)&&nullableDigest(r.proposalDigest)&&
    nullableId(r.reviewerSubject)&&nullableId(r.reviewEventId)&&integer(r.createdAt)&&integer(r.updatedAt)&&
    r.financialEffect==='none'&&r.referencesVerified===false);
  return r as unknown as CaseRecord;
}
function decodeEvent(value:unknown):CaseEvent {
  const r=obj(value);
  valid(id(r.eventId)&&id(r.operationId)&&id(r.caseId)&&integer(r.clubId,1)&&integer(r.revision,1)&&id(r.actorSubject)&&
    typeof r.action==='string'&&actions.includes(r.action)&&typeof r.reasonCode==='string'&&reasons.includes(r.reasonCode)&&
    nullableDigest(r.evidenceDigest)&&nullableEnum(r.disposition,dispositions)&&integer(r.recordedAt)&&r.financialEffect==='none');
  return r as unknown as CaseEvent;
}
/** Cookies stay same-origin; the browser never supplies an operator identity. */
export class PaymentCaseClient {
  private readonly origin:string;
  constructor(origin:string,private readonly transport:typeof fetch=fetch) {
    const u=new URL(origin);if(u.protocol!=='https:'||u.href!==u.origin+'/'||u.username||u.password)throw new CaseClientError('invalid_origin',400);
    this.origin=u.origin;
  }
  private path(clubId:number,caseId?:string):string {
    if(!integer(clubId,1)|| (caseId!==undefined&&!id(caseId)))throw new CaseClientError('invalid_request',400);
    return `/v1/admin/clubs/${clubId}/payment-exceptions${caseId?'/'+caseId:''}`;
  }
  private async request(path:string,body?:unknown,operationId?:string):Promise<unknown> {
    const write=body!==undefined;
    let response:Response;
    try {response=await this.transport(this.origin+path,{method:write?'POST':'GET',credentials:'same-origin',cache:'no-store',redirect:'error',
      headers:write?{'content-type':'application/json','x-africlub-action':'payment-case-review','idempotency-key':operationId!}:{},
      ...(write?{body:JSON.stringify(body)}:{})});}
    catch {throw new CaseClientError('transport_unavailable',0,write);}
    let payload:Record<string,unknown>;
    try {payload=obj(await response.json());}catch {throw new CaseClientError('invalid_response',503,write);}
    if(!response.ok) {
      const e=payload.error&&typeof payload.error==='object'?payload.error as Record<string,unknown>:{};
      const code=typeof e.code==='string'&&/^[a-z_]{3,80}$/.test(e.code)?e.code:'request_failed';
      throw new CaseClientError(code,response.status,write&&(response.status>=500||[401,403].includes(response.status)));
    }
    valid(payload.schemaVersion===1&&id(payload.requestId));return payload.data;
  }
  async access(clubId:number):Promise<CaseAccess> {
    const r=obj(await this.request(this.path(clubId)+'/session'));
    valid(r.schemaVersion===1 && id(r.subject) && r.clubId===clubId && r.canRead===true &&
      typeof r.canMake==='boolean' && typeof r.canReview==='boolean' && r.financialEffect==='none');
    return r as unknown as CaseAccess;
  }
  async operation(clubId:number,operationId:string):Promise<CommandResult> {
    if(!id(operationId))throw new CaseClientError('invalid_request',400);
    const r=obj(await this.request(this.path(clubId)+'/operations/'+operationId));
    valid(r.schemaVersion===1 && r.replayed===true);
    const outcome=decodeEvent(r.outcome),currentCase=decodeCase(r.currentCase);
    valid(outcome.operationId===operationId && outcome.clubId===clubId && currentCase.clubId===clubId &&
      outcome.caseId===currentCase.caseId && currentCase.revision>=outcome.revision);
    return {schemaVersion:1,replayed:true,outcome,currentCase};
  }
  async get(clubId:number,caseId:string):Promise<CaseRecord> {
    const r=decodeCase(await this.request(this.path(clubId,caseId)));valid(r.clubId===clubId&&r.caseId===caseId);return r;
  }
  async list(clubId:number,options:{afterCaseId?:string;limit?:number;state?:CaseState}={}):Promise<{cases:CaseRecord[];nextCaseId:string|null;snapshot:false}> {
    const q=new URLSearchParams();if(options.afterCaseId)q.set('after',options.afterCaseId);if(options.limit!==undefined)q.set('limit',String(options.limit));if(options.state)q.set('state',options.state);
    const r=obj(await this.request(this.path(clubId)+(q.size?'?'+q.toString():'')));
    valid(Array.isArray(r.cases)&&r.cases.length<=50&&nullableId(r.nextCaseId)&&r.snapshot===false);
    const cases=r.cases.map(decodeCase);valid(cases.every(c=>c.clubId===clubId));
    return {cases,nextCaseId:r.nextCaseId as string|null,snapshot:false};
  }
  async history(clubId:number,caseId:string,afterRevision=0,limit=25):Promise<{events:CaseEvent[];nextRevision:number|null}> {
    if(!integer(afterRevision)||!integer(limit,1)||limit>50)throw new CaseClientError('invalid_request',400);
    const r=obj(await this.request(this.path(clubId,caseId)+`/history?after=${afterRevision}&limit=${limit}`));
    valid(Array.isArray(r.events)&&r.events.length<=50&&(r.nextRevision===null||integer(r.nextRevision,1)));
    const events=r.events.map(decodeEvent);valid(events.every(e=>e.clubId===clubId&&e.caseId===caseId));
    return {events,nextRevision:r.nextRevision as number|null};
  }
  async command(clubId:number,caseId:string,operationId:string,expectedRevision:number,action:CaseAction,detail:Detail):Promise<CommandResult> {
    if(!id(operationId)||!integer(expectedRevision)||!actions.includes(action))throw new CaseClientError('invalid_request',400);
    const r=obj(await this.request(this.path(clubId,caseId)+'/commands',{expectedRevision,action,detail},operationId));
    valid(r.schemaVersion===1&&typeof r.replayed==='boolean');const outcome=decodeEvent(r.outcome),currentCase=decodeCase(r.currentCase);
    valid(outcome.caseId===caseId&&outcome.clubId===clubId&&outcome.operationId===operationId&&outcome.action===action&&
      outcome.revision===expectedRevision+1&&currentCase.caseId===caseId&&currentCase.clubId===clubId&&currentCase.revision>=outcome.revision);
    return {schemaVersion:1,replayed:r.replayed,outcome,currentCase};
  }
}
