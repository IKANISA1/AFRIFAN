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
