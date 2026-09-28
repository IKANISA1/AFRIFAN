/** Reference adapter for native/controlled-server transports. Never store these tokens in browser storage. */
export type Challenge = {schemaVersion:1;challengeId:string;clubId:number;expiresAt:number;delivery:'queued_or_pending'};
export type SessionBundle = {schemaVersion:1;userId:string;clubId:number;sessionId:string;accessToken:string;refreshToken:string;accessExpiresAt:number;refreshExpiresAt:number;authenticatedAt:number};
export type SessionInfo = {schemaVersion:1;userId:string;clubId:number;sessionId:string;phoneVerified:true;role:'supporter';authenticatedAt:number};
export type DeletionReceipt = {schemaVersion:1;requestId:string;state:'pending_external_erasure';sessionsRevoked:true;erasureCompleted:false};
export class IdentityClientError extends Error {
 constructor(public code:string,public outcome:'rejected'|'unknown',public status=0){super(code);this.name='IdentityClientError';}
}
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const token=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.[A-Za-z0-9_-]{43}$/;
const key=/^[A-Za-z0-9_-]{16,128}$/;
function requireInput(ok:unknown):asserts ok{if(!ok)throw new IdentityClientError('invalid_client_request','rejected');}
function object(value:unknown):Record<string,unknown>{if(!value||typeof value!=='object'||Array.isArray(value))throw Error('invalid_response');return value as Record<string,unknown>;}
function fields(value:unknown,names:string[]):Record<string,unknown>{const row=object(value);if(Object.keys(row).sort().join(',')!==[...names].sort().join(',')||row.schemaVersion!==1)throw Error('invalid_response');return row;}
const integer=(v:unknown)=>Number.isSafeInteger(v)&&Number(v)>0;
export function validateSession(value:unknown,club:number):SessionBundle {
 const r=fields(value,['schemaVersion','userId','clubId','sessionId','accessToken','refreshToken','accessExpiresAt','refreshExpiresAt','authenticatedAt']);
 if(r.clubId!==club||!uuid.test(String(r.userId))||!uuid.test(String(r.sessionId))||!token.test(String(r.accessToken))||!token.test(String(r.refreshToken))||
  !String(r.accessToken).startsWith(`${r.sessionId}.`)||!String(r.refreshToken).startsWith(`${r.sessionId}.`)||r.accessToken===r.refreshToken||
  !integer(r.accessExpiresAt)||!integer(r.refreshExpiresAt)||!integer(r.authenticatedAt)||Number(r.authenticatedAt)>=Number(r.accessExpiresAt)||Number(r.accessExpiresAt)>Number(r.refreshExpiresAt))throw Error('invalid_response');
 return r as SessionBundle;
}
async function boundedJson(response:Response):Promise<unknown>{
 const reader=response.body?.getReader();if(!reader)throw Error('empty_response');let size=0;const chunks:Uint8Array[]=[];
 try{while(true){const part=await reader.read();if(part.done)break;size+=part.value.length;if(size>16384)throw Error('response_too_large');chunks.push(part.value);}}
 finally{await reader.cancel().catch(()=>{});reader.releaseLock();}
 const bytes=new Uint8Array(size);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}
 return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));
}
export class SupporterIdentityClient {
 constructor(readonly origin:string,readonly clubId:number,private transport:typeof fetch=fetch,private timeoutMs=10000){
  const u=new URL(origin);requireInput(u.protocol==='https:'&&u.origin===origin&&Number.isSafeInteger(clubId)&&clubId>0&&timeoutMs>0&&timeoutMs<=30000);
 }
 private async call<T>(path:string,method:'GET'|'POST',body:unknown,parse:(value:unknown)=>T,operationKey?:string,accessToken?:string):Promise<T>{
  if(operationKey!==undefined)requireInput(key.test(operationKey));if(accessToken!==undefined)requireInput(token.test(accessToken));
  const abort=new AbortController();let timer:ReturnType<typeof setTimeout>|undefined;
  try{return await Promise.race([(async()=>{
   const response=await this.transport(`${this.origin}/v1/auth/clubs/${this.clubId}/${path}`,{method,redirect:'error',credentials:'omit',cache:'no-store',signal:abort.signal,
    headers:{'X-AFRICLUB-Client':'native-v1',...(method==='POST'?{'Content-Type':'application/json'}:{}),...(operationKey?{'Idempotency-Key':operationKey}:{}),...(accessToken?{Authorization:`Bearer ${accessToken}`}:{})},...(method==='POST'?{body:JSON.stringify(body)}:{})});
   // A server error may follow a committed mutation. Retain the original request key.
   if(!response.ok){let code='identity_request_failed';try{const data=object(await boundedJson(response));if(typeof data.error==='string'&&/^[a-z_]{1,80}$/.test(data.error))code=data.error;}catch{/* never echo provider/server bodies */}
    throw new IdentityClientError(code,method==='POST'&&response.status>=500?'unknown':'rejected',response.status);}
   return parse(await boundedJson(response));
  })(),new Promise<T>((_,reject)=>{timer=setTimeout(()=>{abort.abort();reject(new IdentityClientError('identity_timeout',method==='POST'?'unknown':'rejected'));},this.timeoutMs);})]);
  }catch(error){if(error instanceof IdentityClientError)throw error;throw new IdentityClientError('invalid_or_interrupted_identity_response',method==='POST'?'unknown':'rejected');}
  finally{if(timer)clearTimeout(timer);}
 }
 challenge(phone:string,clientSecret:string,operationKey:string):Promise<Challenge>{requireInput(/^\+[1-9]\d{7,14}$/.test(phone)&&/^[A-Za-z0-9_-]{43}$/.test(clientSecret));
  return this.call('otp/challenges','POST',{phone,clientSecret},v=>{const r=fields(v,['schemaVersion','challengeId','clubId','expiresAt','delivery']);if(r.clubId!==this.clubId||!uuid.test(String(r.challengeId))||!integer(r.expiresAt)||r.delivery!=='queued_or_pending')throw Error('invalid_response');return r as Challenge;},operationKey);}
 verify(challengeId:string,code:string,clientSecret:string,operationKey:string):Promise<SessionBundle>{requireInput(uuid.test(challengeId)&&/^\d{6}$/.test(code)&&/^[A-Za-z0-9_-]{43}$/.test(clientSecret));return this.call('otp/verifications','POST',{challengeId,code,clientSecret},v=>validateSession(v,this.clubId),operationKey);}
 refresh(refreshToken:string,operationKey:string):Promise<SessionBundle>{requireInput(token.test(refreshToken));return this.call('sessions/refresh','POST',{refreshToken},v=>validateSession(v,this.clubId),operationKey);}
 current(accessToken:string):Promise<SessionInfo>{return this.call('session','GET',undefined,v=>{const r=fields(v,['schemaVersion','userId','clubId','sessionId','phoneVerified','role','authenticatedAt']);if(r.clubId!==this.clubId||!uuid.test(String(r.userId))||!uuid.test(String(r.sessionId))||r.phoneVerified!==true||r.role!=='supporter'||!integer(r.authenticatedAt))throw Error('invalid_response');return r as SessionInfo;},undefined,accessToken);}
 revoke(accessToken:string,scope:'current'|'others'|'all'):Promise<{schemaVersion:1;scope:string;revoked:true}>{requireInput(['current','others','all'].includes(scope));return this.call('sessions/revoke','POST',{scope},v=>{const r=fields(v,['schemaVersion','scope','revoked']);if(r.scope!==scope||r.revoked!==true)throw Error('invalid_response');return r as {schemaVersion:1;scope:string;revoked:true};},undefined,accessToken);}
 deletion(accessToken:string,confirmation:string,operationKey:string):Promise<DeletionReceipt>{requireInput(confirmation==='DELETE MY ACCOUNT');return this.call('deletion-requests','POST',{confirmation},v=>{const r=fields(v,['schemaVersion','requestId','state','sessionsRevoked','erasureCompleted']);if(!uuid.test(String(r.requestId))||r.state!=='pending_external_erasure'||r.sessionsRevoked!==true||r.erasureCompleted!==false)throw Error('invalid_response');return r as DeletionReceipt;},operationKey,accessToken);}
}
export type PendingRefresh={sessionId:string;refreshToken:string;operationKey:string};
export type StoredIdentity={revision:number;session:SessionBundle|null;pendingRefresh:PendingRefresh|null};
/** Implement with OS-protected encrypted storage, atomic CAS, and a process-safe lock. Not localStorage. */
export interface SecureIdentityStore {
 exclusive<T>(work:()=>Promise<T>):Promise<T>;
 read():Promise<StoredIdentity>;
 compareAndSet(expectedRevision:number,next:Omit<StoredIdentity,'revision'>):Promise<boolean>;
}
/** Called explicitly by the application; construction/restart never automatically rotates credentials. */
export class RefreshCoordinator {
 constructor(private client:SupporterIdentityClient,private store:SecureIdentityStore){}
 async rotateOrRecover():Promise<SessionBundle>{return this.store.exclusive(async()=>{
  let state=await this.store.read();requireInput(state.session&&state.session.clubId===this.client.clubId);const prior=validateSession(state.session,this.client.clubId);
  if(!state.pendingRefresh){const next={session:prior,pendingRefresh:{sessionId:prior.sessionId,refreshToken:prior.refreshToken,operationKey:crypto.randomUUID()}};
   if(!await this.store.compareAndSet(state.revision,next))throw new IdentityClientError('secure_storage_conflict','rejected');state=await this.store.read();}
  const pending=state.pendingRefresh;
  if(!pending||pending.sessionId!==prior.sessionId||pending.refreshToken!==prior.refreshToken||!key.test(pending.operationKey))throw new IdentityClientError('secure_storage_conflict','rejected');
  // Persisted original token/key survive timeouts. No automatic retry, new key or token fallback.
  const rotated=await this.client.refresh(pending.refreshToken,pending.operationKey);
  if(rotated.sessionId!==prior.sessionId||rotated.userId!==prior.userId||rotated.clubId!==prior.clubId||rotated.authenticatedAt!==prior.authenticatedAt)throw new IdentityClientError('identity_response_mismatch','unknown');
  if(!await this.store.compareAndSet(state.revision,{session:rotated,pendingRefresh:null}))throw new IdentityClientError('secure_storage_conflict','unknown');
  return rotated;
 });}
}
