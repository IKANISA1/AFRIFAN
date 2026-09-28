/** Explicit publication state machine. No background confirmation or write retry.
 * Persist only operation identifiers, never identities, tokens, content or evidence.
 */
export const KEY_PREFIX='africlub:public-source:v1:';
const hash=/^[a-f0-9]{64}$/,uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/;
function fail(code){const e=new Error(code);e.code=code;throw e;}
export function recoveryRecord(raw,scopeKey,clubId){
  let x;try{x=JSON.parse(raw);}catch{fail('local_recovery_corrupt');}
  const fields=['version','scopeKey','clubId','reviewId','snapshotId','previousSnapshotId','key','phase','createdAt','operationId'];
  if(!x||typeof x!=='object'||Array.isArray(x)||Object.keys(x).some(k=>!fields.includes(k))||x.version!==1||x.scopeKey!==scopeKey||x.clubId!==clubId||
    !uuid.test(x.reviewId??'')||!hash.test(x.snapshotId??'')||!(x.previousSnapshotId===null||hash.test(x.previousSnapshotId??''))||
    typeof x.key!=='string'||!/^[A-Za-z0-9_-]{16,128}$/.test(x.key)||!['reviewed','unknown','published'].includes(x.phase)||
    !Number.isSafeInteger(x.createdAt)||x.createdAt<=0||(x.phase==='published'?!uuid.test(x.operationId??''):x.operationId!==null))fail('local_recovery_corrupt');
  return x;
}
export class PublicationController {
  constructor(client,clubId,{storage,locks,now=()=>performance.now(),wallNow=()=>Date.now(),newKey=()=>crypto.randomUUID(),onChange=()=>{}}={}){
    this.client=client;this.clubId=clubId;this.storage=storage;this.locks=locks;this.now=now;this.wallNow=wallNow;this.newKey=newKey;this.onChange=onChange;
    this.state={phase:'loading',busy:false,error:null,session:null,head:null,candidates:[],hasMore:false,candidate:null,review:null,preview:null,pending:null,receipt:null,canMutate:false,currentHeadUnavailable:false};
    this.deadline=0;this.localKey=null;
  }
  emit(){this.onChange(structuredClone(this.state));}
  get confirmationText(){return this.state.pending?`PUBLISH ${this.state.pending.snapshotId.slice(-8)}`:'';}
  get remainingSeconds(){return Math.max(0,Math.ceil((this.deadline-this.now())/1000));}
  setError(error){this.state.error=typeof error?.code==='string'?error.code:'request_failed';}
  async run(task){
    if(this.state.busy)return;this.state.busy=true;this.state.error=null;this.emit();
    try{await task();}catch(error){this.setError(error);if(this.state.phase==='loading')this.state.phase='unavailable';}
    finally{this.state.busy=false;this.emit();}
  }
  readPending(){
    let raw;try{raw=this.storage.getItem(this.localKey);}catch{fail('local_recovery_unavailable');}
    return raw===null?null:recoveryRecord(raw,this.state.session.scopeKey,this.clubId);
  }
  save(pending){
    try{const raw=JSON.stringify(pending);this.storage.setItem(this.localKey,raw);if(this.storage.getItem(this.localKey)!==raw)throw Error();}
    catch{fail('local_recovery_unavailable');}
    this.state.pending=pending;
  }
  async identity(){
    const s=await this.client.session(this.clubId);
    if(s.scopeKey!==this.state.session.scopeKey){this.state.canMutate=false;this.state.phase='identity_changed';fail('operator_identity_changed');}
    this.state.session=s;return s;
  }
  async locked(task){
    if(!this.state.canMutate||!this.locks?.request)fail('local_recovery_unavailable');
    return this.locks.request(this.localKey,{ifAvailable:true,mode:'exclusive'},async lock=>{
      if(!lock)fail('another_tab_busy');await this.identity();return task();
    });
  }
  async init(){return this.run(async()=>{
    // Clear the prior operator's in-memory display before awaiting identity.
    // Pending identifiers remain in their original scoped storage for recovery.
    Object.assign(this.state,{phase:'loading',session:null,head:null,candidates:[],hasMore:false,candidate:null,review:null,preview:null,pending:null,receipt:null,canMutate:false,currentHeadUnavailable:false});
    this.deadline=0;this.localKey=null;this.emit();
    this.state.session=await this.client.session(this.clubId);this.localKey=KEY_PREFIX+this.state.session.scopeKey;
    this.state.canMutate=false;
    try{const k=this.localKey+':probe';this.storage.setItem(k,'1');if(this.storage.getItem(k)!=='1')throw Error();this.storage.removeItem(k);this.state.canMutate=typeof this.locks?.request==='function';}catch{}
    this.state.head=await this.client.head(this.clubId);
    const list=await this.client.candidates(this.clubId);this.state.candidates=list.items;this.state.hasMore=list.hasMore;
    const pending=this.readPending();this.state.pending=pending;
    if(pending)await this.restorePending(pending);else this.state.phase='select';
    if(!this.state.canMutate)this.state.error='local_recovery_unavailable';
  });}
  async inspect(snapshotId){return this.run(async()=>{
    if(this.state.pending)fail('pending_operation_exists');
    this.state.candidate=null;this.state.review=null;this.state.preview=null;this.state.phase='select';this.emit();
    this.state.candidate=await this.client.candidate(this.clubId,snapshotId);
    this.state.review=null;this.state.preview=null;this.state.phase='inspect';
  });}
  async review(reviewRef){return this.run(()=>this.locked(async()=>{
    if(this.readPending())fail('pending_operation_exists');
    if(!this.state.session.canReview)fail('operator_not_authorized');
    const c=this.state.candidate;
    if(!c||!c.fresh||!['importing','sealed','verified'].includes(c.status)||c.snapshotId!==c.manifestHash)fail('snapshot_not_reviewable');
    if(typeof reviewRef!=='string'||!/^[A-Za-z0-9_.:/-]{3,160}$/.test(reviewRef))fail('invalid_review_reference');
    const h=await this.client.head(this.clubId);
    if(h.snapshotId!==this.state.head.snapshotId){this.state.head=h;fail('publication_conflict');}
    const review=await this.client.review(this.clubId,{snapshotId:c.snapshotId,expectedPreviousId:h.snapshotId,reviewRef});
    this.save({version:1,scopeKey:this.state.session.scopeKey,clubId:this.clubId,reviewId:review.reviewId,snapshotId:c.snapshotId,
      previousSnapshotId:h.snapshotId,key:this.newKey(),phase:'reviewed',createdAt:this.wallNow(),operationId:null});
    await this.restorePending(this.state.pending);
  }));}
  matchReview(r,p){if(r.reviewId!==p.reviewId||r.snapshotId!==p.snapshotId||r.expectedPreviousId!==p.previousSnapshotId)fail('recovery_mismatch');}
  matchReceipt(r,p){if(r.reviewId!==p.reviewId||r.snapshotId!==p.snapshotId||r.previousSnapshotId!==p.previousSnapshotId||r.clubId!==this.clubId)fail('recovery_mismatch');}
  async restorePending(p){
    const status=await this.client.reviewStatus(this.clubId,p.reviewId);this.matchReview(status,p);
    this.state.review=status;this.state.pending=p;this.deadline=this.now()+Math.max(0,Date.parse(status.expiresAt)-Date.parse(status.serverNow));
    if(status.publication){
      this.matchReceipt(status.publication,p);this.state.receipt=status.publication;this.state.phase='published';
      // Preserve the receipt in memory even if browser storage fails after commit.
      this.save({...p,phase:'published',operationId:status.publication.operationId});
      await this.refreshHead();return;
    }
    if(p.phase==='published')fail('recovery_mismatch');
    this.state.phase=p.phase==='unknown'?'unknown':status.state==='ready'?'reviewed':status.state;
    this.state.candidate=await this.client.candidate(this.clubId,p.snapshotId);
    if(this.state.candidate.manifestHash!==p.snapshotId)fail('recovery_mismatch');
    this.state.preview=null;
  }
  async refreshHead(){try{this.state.head=await this.client.head(this.clubId);this.state.currentHeadUnavailable=false;}
    catch{this.state.head=null;this.state.currentHeadUnavailable=true;}}
  async checkResult(){return this.run(async()=>{
    await this.identity();const p=this.readPending();if(!p)fail('no_pending_operation');await this.restorePending(p);
  });}
  async loadPreview(route,offset=0){return this.run(async()=>{
    const p=this.state.pending;if(!p||!this.state.review)fail('review_required');
    this.state.preview=await this.client.preview(this.clubId,p.snapshotId,route,offset);
  });}
  async confirm({acknowledged=false,confirmation=''}={}){return this.run(()=>this.locked(async()=>{
    const p=this.readPending();if(!p)fail('no_pending_operation');
    if(p.reviewId!==this.state.pending?.reviewId||p.key!==this.state.pending?.key)fail('another_tab_changed');
    if(p.phase==='published'){await this.restorePending(p);return;}
    if(!this.state.session.canPublish)fail('operator_not_authorized');
    if(acknowledged!==true||confirmation!==this.confirmationText)fail('explicit_confirmation_required');
    const r=await this.client.reviewStatus(this.clubId,p.reviewId);this.matchReview(r,p);
    if(r.publication){await this.restorePending(p);return;}
    if(r.state!=='ready'||Date.parse(r.expiresAt)<=Date.parse(r.serverNow))fail(r.state==='invalidated'?'review_no_longer_authorized':'review_expired');
    const h=await this.client.head(this.clubId);if(h.snapshotId!==p.previousSnapshotId)fail('publication_conflict');
    // The persisted marker precedes the network call and survives reload/close.
    // No later action generates a replacement key for an uncertain operation.
    this.save({...p,phase:'unknown'});this.state.phase='unknown';this.emit();
    try{
      const receipt=await this.client.confirm(this.clubId,p.reviewId,p.key);this.matchReceipt(receipt,p);
      this.state.receipt=receipt;this.state.phase='published';
      this.save({...p,phase:'published',operationId:receipt.operationId});await this.refreshHead();
    }catch(error){this.setError(error);if(!this.state.receipt)this.state.phase='unknown';}
  }));}
  async reset(){return this.run(()=>this.locked(async()=>{
    const p=this.readPending();if(p?.phase==='unknown')fail('unknown_outcome_unresolved');
    // A pre-confirmation review has no publication side effect. This removes only
    // the local pending marker; server review/audit history remains untouched.
    if(p){await this.restorePending(p);if(this.state.pending?.phase==='unknown')fail('unknown_outcome_unresolved');}
    try{this.storage.removeItem(this.localKey);if(this.storage.getItem(this.localKey)!==null)throw Error();}catch{fail('local_recovery_unavailable');}
    this.state.pending=null;this.state.review=null;this.state.candidate=null;this.state.preview=null;this.state.receipt=null;
    this.state.head=await this.client.head(this.clubId);const list=await this.client.candidates(this.clubId);this.state.candidates=list.items;this.state.hasMore=list.hasMore;this.state.phase='select';
  }));}
}
