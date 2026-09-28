/** Browser-side client for the same-origin Access-protected operator API only.
 * No token storage, no implicit approval, no new idempotency key on retry.
 */
export interface Head {
  clubId:number; snapshotId:string|null; capturedAt:string|null; activatedAt:string|null; fresh:boolean;
}
export interface ReviewInput { snapshotId:string; expectedPreviousId:string|null; reviewRef:string; }
export interface Review extends ReviewInput {
  reviewId:string; clubId:number; expiresAt:string; rowCount:number; mediaCount:number;
}
export interface Publication {
  operationId:string; clubId:number; snapshotId:string; previousSnapshotId:string|null;
  reviewId:string; publishedAt:string; status:'published'; replayed:boolean;
}
export interface Session {clubId:number;clubSlug:string;scopeKey:string;canReview:boolean;canPublish:boolean;serverNow:string;grantExpiresAt:string;}
export interface CandidateSummary {snapshotId:string;capturedAt:string;status:'importing'|'sealed'|'verified';fresh:boolean;}
export interface Candidate {clubId:number;snapshotId:string;manifestHash:string;capturedAt:string;status:string;serverNow:string;fresh:boolean;rowCount:number;mediaCount:number;tables:Array<{name:string;count:number}>;}
export interface ReviewStatus {clubId:number;reviewId:string;snapshotId:string;expectedPreviousId:string|null;reviewRef:string;expiresAt:string;serverNow:string;state:'ready'|'expired'|'invalidated'|'published'|'unavailable';publication:Publication|null;}
export interface Preview {clubId:number;snapshotId:string;route:string;offset:number;total:number;nextOffset:number|null;rows:Record<string,unknown>[];serverNow:string;mediaPreviewEnabled:false;}
export class OperatorApiError extends Error {
  constructor(public readonly code:string,public readonly status:number,public readonly requestId:string|null,
    public readonly mayHaveCommitted=false) {super(code);this.name='OperatorApiError';}
}
const hash=/^[a-f0-9]{64}$/,uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/;
const object=(v:unknown):v is Record<string,unknown>=>!!v&&typeof v==='object'&&!Array.isArray(v);
const date=(v:unknown):v is string=>typeof v==='string'&&Number.isFinite(Date.parse(v));
const nullableHash=(v:unknown)=>v===null||typeof v==='string'&&hash.test(v);
export class OperatorPublicationClient {
  private readonly origin:string;
  constructor(origin:string,private readonly fetcher:typeof fetch=fetch) {
    const parsed=new URL(origin);
    if(parsed.protocol!=='https:'||parsed.username||parsed.password||parsed.href!==`${parsed.origin}/`)
      throw new TypeError('Operator API requires an HTTPS origin, not a path');
    this.origin=parsed.origin;
  }
  static createIdempotencyKey():string {return crypto.randomUUID();}
  private async request(clubId:number,suffix:string,body?:unknown,key?:string):Promise<Record<string,unknown>> {
    if(!Number.isSafeInteger(clubId)||clubId<=0)throw new TypeError('Invalid club ID');
    const confirming=suffix==='publications'&&body!==undefined;
    let response:Response;
    try {
      response=await this.fetcher(`${this.origin}/v1/admin/clubs/${clubId}/public-source/${suffix}`,{
        method:body===undefined?'GET':'POST',credentials:'same-origin',cache:'no-store',redirect:'error',
        signal:AbortSignal.timeout(15_000),
        headers:body===undefined?{}:{'content-type':'application/json','x-africlub-action':'publish-review',...(key?{'idempotency-key':key}:{})},
        ...(body===undefined?{}:{body:JSON.stringify(body)}),
      });
    } catch {throw new OperatorApiError('request_interrupted',0,null,confirming);}
    let payload:unknown;
    try {payload=await response.json();} catch {throw new OperatorApiError('invalid_response',response.status,null,confirming);}
    if(!object(payload)||payload.schemaVersion!==1)throw new OperatorApiError('invalid_response',response.status,null,confirming);
    if(!response.ok) {
      const error=object(payload.error)?payload.error:{};
      throw new OperatorApiError(typeof error.code==='string'?error.code:'request_failed',response.status,
        typeof error.requestId==='string'?error.requestId:null,confirming&&response.status>=500);
    }
    if(!object(payload.data)||payload.data.clubId!==clubId)throw new OperatorApiError('invalid_response',response.status,null,confirming);
    return payload.data;
  }
  async session(clubId:number):Promise<Session> {
    const d=await this.request(clubId,'session');
    if(typeof d.clubSlug!=='string'||!/^[a-z0-9_-]{1,80}$/.test(d.clubSlug)||typeof d.scopeKey!=='string'||!hash.test(d.scopeKey)||
      typeof d.canReview!=='boolean'||typeof d.canPublish!=='boolean'||!date(d.serverNow)||!date(d.grantExpiresAt))throw new OperatorApiError('invalid_response',200,null);
    return d as unknown as Session;
  }
  async candidates(clubId:number):Promise<{clubId:number;items:CandidateSummary[];hasMore:boolean;serverNow:string}> {
    const d=await this.request(clubId,'candidates');
    if(!Array.isArray(d.items)||d.items.length>20||typeof d.hasMore!=='boolean'||!date(d.serverNow)||d.items.some(i=>!object(i)||
      typeof i.snapshotId!=='string'||!hash.test(i.snapshotId)||!date(i.capturedAt)||!['importing','sealed','verified'].includes(String(i.status))||typeof i.fresh!=='boolean'))throw new OperatorApiError('invalid_response',200,null);
    return d as unknown as {clubId:number;items:CandidateSummary[];hasMore:boolean;serverNow:string};
  }
  async candidate(clubId:number,snapshotId:string):Promise<Candidate> {
    if(!hash.test(snapshotId))throw new TypeError('Invalid snapshot');
    const d=await this.request(clubId,`candidates/${snapshotId}`);
    if(d.snapshotId!==snapshotId||typeof d.manifestHash!=='string'||!hash.test(d.manifestHash)||!date(d.capturedAt)||!date(d.serverNow)||
      !['importing','sealed','verified','active','retired'].includes(String(d.status))||typeof d.fresh!=='boolean'||
      !Number.isSafeInteger(d.rowCount)||Number(d.rowCount)<0||!Number.isSafeInteger(d.mediaCount)||Number(d.mediaCount)<0||
      !Array.isArray(d.tables)||d.tables.length>15||d.tables.some(t=>!object(t)||typeof t.name!=='string'||!/^[a-z_]+$/.test(t.name)||!Number.isSafeInteger(t.count)||Number(t.count)<0))
      throw new OperatorApiError('invalid_response',200,null);
    return d as unknown as Candidate;
  }
  async preview(clubId:number,snapshotId:string,route:string,offset=0):Promise<Preview> {
    if(!hash.test(snapshotId)||!['fixtures','news','squad','fanclubs','partners','shop','tickets','membership-tiers','predict-pools'].includes(route)||
      !Number.isSafeInteger(offset)||offset<0||offset>100_000)throw new TypeError('Invalid preview');
    const d=await this.request(clubId,`candidates/${snapshotId}/preview/${route}?offset=${offset}`);
    if(d.snapshotId!==snapshotId||d.route!==route||d.offset!==offset||!Number.isSafeInteger(d.total)||Number(d.total)<0||
      !Array.isArray(d.rows)||d.rows.length>25||d.rows.some(x=>!object(x))||!date(d.serverNow)||d.mediaPreviewEnabled!==false||
      !(d.nextOffset===null||Number.isSafeInteger(d.nextOffset)&&Number(d.nextOffset)===offset+d.rows.length&&Number(d.nextOffset)<Number(d.total)))
      throw new OperatorApiError('invalid_response',200,null);
    return d as unknown as Preview;
  }
  async reviewStatus(clubId:number,reviewId:string):Promise<ReviewStatus> {
    if(!uuid.test(reviewId))throw new TypeError('Invalid review');
    const d=await this.request(clubId,`reviews/${reviewId}`);
    if(d.reviewId!==reviewId||typeof d.snapshotId!=='string'||!hash.test(d.snapshotId)||!nullableHash(d.expectedPreviousId)||
      typeof d.reviewRef!=='string'||!/^[A-Za-z0-9_.:/-]{3,160}$/.test(d.reviewRef)||!date(d.expiresAt)||!date(d.serverNow)||
      !['ready','expired','invalidated','published','unavailable'].includes(String(d.state))||
      (d.state==='published'? !object(d.publication):d.publication!==null))throw new OperatorApiError('invalid_response',200,null);
    if(object(d.publication)) {
      const receipt=this.publication(d.publication,false);
      if(receipt.clubId!==clubId||receipt.reviewId!==reviewId||receipt.snapshotId!==d.snapshotId||receipt.previousSnapshotId!==d.expectedPreviousId)
        throw new OperatorApiError('invalid_response',200,null);
    }
    return d as unknown as ReviewStatus;
  }
  async head(clubId:number):Promise<Head> {
    const d=await this.request(clubId,'head');
    if(!nullableHash(d.snapshotId)||!(d.capturedAt===null||date(d.capturedAt))||!(d.activatedAt===null||date(d.activatedAt))||typeof d.fresh!=='boolean')
      throw new OperatorApiError('invalid_response',200,null);
    return d as unknown as Head;
  }
  async review(clubId:number,input:ReviewInput):Promise<Review> {
    if(!hash.test(input.snapshotId)||!nullableHash(input.expectedPreviousId)||!/^[A-Za-z0-9_.:/-]{3,160}$/.test(input.reviewRef))throw new TypeError('Invalid review');
    const d=await this.request(clubId,'reviews',input);
    if(typeof d.reviewId!=='string'||!uuid.test(d.reviewId)||d.snapshotId!==input.snapshotId||d.expectedPreviousId!==input.expectedPreviousId||
      d.reviewRef!==input.reviewRef||!date(d.expiresAt)||!Number.isSafeInteger(d.rowCount)||Number(d.rowCount)<0||!Number.isSafeInteger(d.mediaCount)||Number(d.mediaCount)<0)
      throw new OperatorApiError('invalid_response',201,null);
    return d as unknown as Review;
  }
  async confirm(clubId:number,reviewId:string,idempotencyKey:string):Promise<Publication> {
    if(!uuid.test(reviewId)||!/^[A-Za-z0-9_-]{16,128}$/.test(idempotencyKey))throw new TypeError('Invalid confirmation');
    const d=await this.request(clubId,'publications',{reviewId},idempotencyKey);
    const result=this.publication(d,true);
    if(result.reviewId!==reviewId)throw new OperatorApiError('invalid_response',200,null,true);
    return result;
  }
  async status(clubId:number,operationId:string):Promise<Publication> {
    if(!uuid.test(operationId))throw new TypeError('Invalid operation ID');
    const result=this.publication(await this.request(clubId,`publications/${operationId}`),false);
    if(result.operationId!==operationId)throw new OperatorApiError('invalid_response',200,null);
    return result;
  }
  private publication(d:Record<string,unknown>,confirming:boolean):Publication {
    if(typeof d.operationId!=='string'||!uuid.test(d.operationId)||typeof d.snapshotId!=='string'||!hash.test(d.snapshotId)||
      !nullableHash(d.previousSnapshotId)||typeof d.reviewId!=='string'||!uuid.test(d.reviewId)||!date(d.publishedAt)||d.status!=='published'||typeof d.replayed!=='boolean')
      throw new OperatorApiError('invalid_response',200,null,confirming);
    return d as unknown as Publication;
  }
}
