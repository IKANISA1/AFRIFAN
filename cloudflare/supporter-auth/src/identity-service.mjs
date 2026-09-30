import { assertRegisteredKeyPolicy } from './key-state.mjs';
import { issuanceWindows } from './issuance-policy.mjs';
import { AuthError, requireValue, exactKeys, clubId, requestKey, phoneNumber, UUID } from './errors.mjs';
import { Vault, sha256, randomSecret, randomCode, validSecret, splitToken } from './crypto.mjs';
export const POLICY=Object.freeze({otpMs:600_000,accessMs:300_000,idleMs:86_400_000,absoluteMs:604_800_000,replayMs:60_000,freshMs:300_000});
const SQL_NOW="CAST(unixepoch('subsec') * 1000 AS INTEGER)";
const liveSession=`s.revoked_at_ms IS NULL AND a.status='active' AND a.auth_epoch=s.account_epoch
 AND c.enabled=1 AND c.revision=s.club_revision AND s.absolute_expires_ms>${SQL_NOW}
 AND EXISTS(SELECT 1 FROM auth_settings WHERE singleton=1 AND import_ready=1 AND length(import_evidence)>0 AND key_version='1')`;
const sessionJoin='auth_sessions s JOIN auth_accounts a ON a.user_id=s.user_id JOIN auth_clubs c ON c.club_id=s.club_id';
/** Identity-only candidate. Never grants paid membership, a role, points, or account merging. */
export class IdentityService {
 constructor(env,{clock=Date.now}={}){requireValue(env.AUTH_SERVICE_ENABLED==='true'&&env.AUTH_DB,'service_unavailable',503);
  this.env=env;this.db=env.AUTH_DB;this.vault=new Vault(env,{clock});this.clock=clock;
  this.liveSession=liveSession.replace("key_version='1'",`key_version='${this.vault.currentVersion}'`);}
 stmt(sql,...args){return this.db.prepare(sql).bind(...args);}
 async ready(id){clubId(id);await assertRegisteredKeyPolicy(this.db,this.vault);const row=await this.stmt(`SELECT c.* FROM auth_clubs c JOIN auth_settings x ON x.singleton=1
  WHERE c.club_id=? AND c.enabled=1 AND x.import_ready=1 AND x.import_evidence IS NOT NULL AND length(x.import_evidence)>0 AND x.key_version=?`,id,this.vault.currentVersion).first();
  requireValue(row,'service_unavailable',503);
  if(this.vault.currentVersion!=='1'){const missing=await this.stmt(`SELECT 1 FROM auth_accounts a WHERE NOT EXISTS
   (SELECT 1 FROM auth_phone_aliases p WHERE p.user_id=a.user_id AND p.key_version=?) LIMIT 1`,this.vault.currentVersion).first();
   requireValue(!missing,'key_rotation_incomplete',503);}
  return row;}
 assertion(expression,...args){const assertionId=crypto.randomUUID();return {assertionId,
  statement:this.stmt(`INSERT INTO auth_assertions(assertion_id,ok) VALUES(?,CASE WHEN (${expression}) THEN 1 ELSE 0 END)`,assertionId,...args)};}
 async batch(steps){const checks=steps.filter(x=>x.assertionId);return this.db.batch([
  ...steps.map(x=>x.statement??x),...checks.map(x=>this.stmt('DELETE FROM auth_assertions WHERE assertion_id=?',x.assertionId))]);}
 audit(kind,userId,id,sessionId){return this.stmt('INSERT INTO auth_audit VALUES(?,?,?,?,?,?)',crypto.randomUUID(),kind,userId,id,sessionId,this.clock());}
 async key(value){return this.vault.hash('request-key',requestKey(value));}
 rateSteps(key,windowStart,limit){return [this.stmt(`INSERT INTO auth_rate_windows VALUES(?,?,1)
  ON CONFLICT(rate_key,window_start_ms) DO UPDATE SET count=count+1`,key,windowStart),
  this.assertion('(SELECT count FROM auth_rate_windows WHERE rate_key=? AND window_start_ms=?)<=?',key,windowStart,limit)];}
 async rate(key,period,limit){const start=Math.floor(this.clock()/period)*period;
  try{await this.batch(this.rateSteps(key,start,limit));}catch(error){const row=await this.stmt('SELECT count FROM auth_rate_windows WHERE rate_key=? AND window_start_ms=?',key,start).first();
   if(row?.count>=limit)throw new AuthError('rate_limited',429);throw error;}}
 async rateMany(keys,period,limit){const start=Math.floor(this.clock()/period)*period;
  try{await this.batch(keys.flatMap(key=>this.rateSteps(key,start,limit)));}catch(error){
   for(const key of keys){const row=await this.stmt('SELECT count FROM auth_rate_windows WHERE rate_key=? AND window_start_ms=?',key,start).first();
    if(row?.count>=limit)throw new AuthError('rate_limited',429);}throw error;}}
 challengeView(c){return {schemaVersion:1,challengeId:c.challenge_id,clubId:c.club_id,expiresAt:c.expires_at_ms,delivery:'queued_or_pending'};}
 async keyHashes(value){return (await this.vault.hashes('request-key',requestKey(value))).map(v=>v.hash);}
 async accountForPhone(phone){const candidates=await this.vault.hashes('phone',phone),slots=candidates.map(()=>'?').join(',');
  const pairs=candidates.map(()=>'(p.key_version=? AND p.phone_hash=?)').join(' OR ');
  const rows=await this.stmt(`SELECT a.* FROM auth_accounts a WHERE a.phone_hash IN(${slots}) UNION
   SELECT a.* FROM auth_phone_aliases p JOIN auth_accounts a ON a.user_id=p.user_id WHERE ${pairs}`,...candidates.map(v=>v.hash),...candidates.flatMap(v=>[v.version,v.hash])).all();
  requireValue(rows.results.length<=1,'identity_mapping_conflict',503);
  const account=rows.results[0]??null;if(account){const contact=await this.vault.open(account.phone_cipher,`phone:${account.phone_hash}`);
   exactKeys(contact,['phone']);requireValue(contact.phone===phone,'identity_mapping_conflict',503);}
  return account;}
 async existingChallenge(id,key,input,account){const keys=await this.keyHashes(key),slots=keys.map(()=>'?').join(',');
  const c=await this.stmt(`SELECT * FROM auth_challenges WHERE club_id=? AND request_key_hash IN(${slots})`,id,...keys).first();
  if(!c)return null;
  const phoneMatches=c.phone_hash===account?.phone_hash||await this.vault.verifyHash('phone',input.phone,c.phone_hash);
  requireValue(phoneMatches&&await this.vault.verifyHash('challenge-request',JSON.stringify([id,c.phone_hash,await sha256(input.clientSecret)]),c.request_hash),'idempotency_conflict',409);
  requireValue(c.state==='open'&&c.expires_at_ms>this.clock(),'challenge_unavailable',409);return this.challengeView(c);}
 async challenge(id,input,key,ipKey){
  exactKeys(input,['phone','clientSecret']);phoneNumber(input.phone);validSecret(input.clientSecret);
  requireValue(typeof ipKey==='string'&&/^[0-9a-f]{64}$/.test(ipKey),'service_unavailable',503);
  const club=await this.ready(id),requestHashKey=await this.key(key),account=await this.accountForPhone(input.phone),
   phoneHash=account?.phone_hash??await this.vault.hash('phone',input.phone),clientHash=await sha256(input.clientSecret);
  const requestHash=await this.vault.hash('challenge-request',JSON.stringify([id,phoneHash,clientHash]));
  const prior=await this.existingChallenge(id,key,input,account);if(prior)return prior;
  const challengeId=crypto.randomUUID(),code=randomCode(),now=this.clock(),expires=now+POLICY.otpMs;
  const codeHash=await this.vault.hash('otp',`${id}:${challengeId}:${code}`);
  const phoneCipher=await this.vault.seal({phone:input.phone},`phone:${phoneHash}`);
  const deliveryCipher=await this.vault.seal({phone:input.phone,code},`challenge:${challengeId}`);
  const windows=issuanceWindows(this.env,id,ipKey,phoneHash);
  for(const {hash} of await this.vault.hashes('phone',input.phone))if(hash!==phoneHash)windows.push([`issue:phone:${hash}`,900_000,windows[3][2]]);
  const steps=windows.flatMap(([k,p,n])=>this.rateSteps(k,Math.floor(now/p)*p,n));
  steps.push(this.assertion(`EXISTS(SELECT 1 FROM auth_clubs c,auth_settings x WHERE c.club_id=? AND c.enabled=1 AND c.revision=? AND x.singleton=1 AND x.import_ready=1 AND length(x.import_evidence)>0 AND x.key_version='${this.vault.currentVersion}')`,id,club.revision));
  steps.push(this.stmt(`INSERT INTO auth_challenges(challenge_id,club_id,club_revision,request_key_hash,request_hash,phone_hash,client_hash,code_hash,
   phone_cipher,delivery_cipher,subject_at_request,subject_epoch,created_at_ms,expires_at_ms,next_attempt_ms,hmac_key_version) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
   challengeId,id,club.revision,requestHashKey,requestHash,phoneHash,clientHash,codeHash,phoneCipher,deliveryCipher,account?.user_id??null,account?.auth_epoch??null,now,expires,now,this.vault.currentVersion));
  try{await this.batch(steps);}catch(error){const raced=await this.existingChallenge(id,key,input,account);if(raced)return raced;
   for(const [k,p,n] of windows){const r=await this.stmt('SELECT count FROM auth_rate_windows WHERE rate_key=? AND window_start_ms=?',k,Math.floor(now/p)*p).first();if(r?.count>=n)throw new AuthError('rate_limited',429);}throw error;}
  return this.challengeView({challenge_id:challengeId,club_id:id,expires_at_ms:expires});
 }
 async tokenBundle(sessionId){return {sessionId,accessToken:`${sessionId}.${randomSecret()}`,refreshToken:`${sessionId}.${randomSecret()}`};}
 async bundleView(tokens,id){const s=await this.stmt(`SELECT s.* FROM ${sessionJoin} WHERE s.session_id=? AND s.club_id=? AND ${this.liveSession}
  AND s.access_expires_ms>${SQL_NOW} AND s.access_hash=? AND s.refresh_hash=?`,tokens.sessionId,id,await sha256(tokens.accessToken),await sha256(tokens.refreshToken)).first();
  requireValue(s,'reauthentication_required',401);
  return {schemaVersion:1,...tokens,userId:s.user_id,clubId:s.club_id,accessExpiresAt:s.access_expires_ms,refreshExpiresAt:s.refresh_expires_ms,authenticatedAt:s.authenticated_at_ms};}
 async verificationReplay(c,key,id){requireValue(await this.vault.verifyHash('request-key',requestKey(key),c.verification_key_hash),'challenge_consumed',409);
  requireValue(c.replay_until_ms>this.clock()&&c.verification_cipher,'reauthentication_required',401);
  return this.bundleView(await this.vault.open(c.verification_cipher,`verification:${c.challenge_id}:${c.verification_key_hash}`),id);}
 async verify(id,input,key){
  exactKeys(input,['challengeId','code','clientSecret']);requireValue(UUID.test(input.challengeId));requireValue(typeof input.code==='string'&&/^\d{6}$/.test(input.code));validSecret(input.clientSecret);
  const club=await this.ready(id),keyHash=await this.key(key);
  let c=await this.stmt('SELECT * FROM auth_challenges WHERE challenge_id=? AND club_id=?',input.challengeId,id).first();
  requireValue(c&&c.client_hash===await sha256(input.clientSecret),'invalid_code',401);
  const contact=await this.vault.open(c.phone_cipher,`phone:${c.phone_hash}`);exactKeys(contact,['phone']);phoneNumber(contact.phone);
  // Charge every retained phone lookup version atomically. Key changes and club changes cannot reset guessing limits.
  const rateHashes=[...new Set([c.phone_hash,...(await this.vault.hashes('phone',contact.phone)).map(v=>v.hash)])];
  await this.rateMany(rateHashes.map(hash=>`verify:phone:${hash}`),900_000,15);
  const codeMatches=await this.vault.verifyHashVersion('otp',`${id}:${c.challenge_id}:${input.code}`,c.code_hash,c.hmac_key_version);
  if(!codeMatches){await this.stmt(`UPDATE auth_challenges SET attempts=attempts+1 WHERE challenge_id=? AND state='open'
   AND attempts<5 AND expires_at_ms>${SQL_NOW}`,c.challenge_id).run();throw new AuthError('invalid_code',401);}
  if(c.state==='consumed')return this.verificationReplay(c,key,id);
  requireValue(c.state==='open'&&c.attempts<5&&c.expires_at_ms>this.clock()&&c.club_revision===club.revision,'invalid_code',401);
  const account=await this.accountForPhone(contact.phone);
  requireValue(account?account.status==='active'&&(c.subject_at_request===null||(account.user_id===c.subject_at_request&&account.auth_epoch===c.subject_epoch)):club.allow_signup===1,'account_unavailable',403);
  const currentPhoneHash=await this.vault.hash('phone',contact.phone),newPhoneCipher=await this.vault.seal(contact,`phone:${c.phone_hash}`);
  const now=this.clock(),sessionId=crypto.randomUUID(),candidateId=crypto.randomUUID(),tokens=await this.tokenBundle(sessionId);
  const encrypted=await this.vault.seal(tokens,`verification:${c.challenge_id}:${keyHash}`),accessHash=await sha256(tokens.accessToken),refreshHash=await sha256(tokens.refreshToken);
  const steps=[this.assertion(`EXISTS(SELECT 1 FROM auth_clubs c,auth_settings x WHERE c.club_id=? AND c.enabled=1 AND c.revision=? AND x.singleton=1 AND x.import_ready=1 AND length(x.import_evidence)>0 AND x.key_version='${this.vault.currentVersion}')`,id,c.club_revision),
   this.stmt(`UPDATE auth_challenges SET state='consumed',attempts=attempts+1,verification_key_hash=?,session_id=?,verification_cipher=?,replay_until_ms=?,delivery_cipher=NULL
    WHERE challenge_id=? AND state='open' AND attempts<5 AND expires_at_ms>${SQL_NOW} AND club_revision=?`,keyHash,sessionId,encrypted,now+POLICY.replayMs,c.challenge_id,c.club_revision),
   this.assertion('changes()=1'),
   this.stmt(`INSERT INTO auth_accounts(user_id,phone_hash,phone_cipher,status,verified_at_ms,created_at_ms)
    SELECT ?,?,?,'active',?,? WHERE EXISTS(SELECT 1 FROM auth_clubs WHERE club_id=? AND allow_signup=1)
    AND NOT EXISTS(SELECT 1 FROM auth_phone_aliases WHERE key_version=? AND phone_hash=?)
    ON CONFLICT(phone_hash) DO NOTHING`,candidateId,c.phone_hash,newPhoneCipher,now,now,id,this.vault.currentVersion,currentPhoneHash),
   this.stmt(`INSERT INTO auth_phone_aliases(key_version,phone_hash,user_id,created_at_ms)
    SELECT ?,?,user_id,? FROM auth_accounts WHERE phone_hash=? ON CONFLICT DO NOTHING`,this.vault.currentVersion,currentPhoneHash,now,c.phone_hash),
   this.assertion(`EXISTS(SELECT 1 FROM auth_phone_aliases p JOIN auth_accounts a ON a.user_id=p.user_id
    WHERE p.key_version=? AND p.phone_hash=? AND (? IS NULL OR a.user_id=?))`,this.vault.currentVersion,currentPhoneHash,account?.user_id??null,account?.user_id??null),
   this.assertion(`EXISTS(SELECT 1 FROM auth_accounts a JOIN auth_phone_aliases p ON p.user_id=a.user_id
    WHERE p.key_version=? AND p.phone_hash=? AND a.status='active'
    AND (? IS NULL OR (a.user_id=? AND a.auth_epoch=?)))`,this.vault.currentVersion,currentPhoneHash,c.subject_at_request,c.subject_at_request,c.subject_epoch),
   this.stmt(`INSERT INTO auth_sessions(session_id,user_id,club_id,account_epoch,club_revision,access_hash,refresh_hash,authenticated_at_ms,created_at_ms,access_expires_ms,refresh_expires_ms,absolute_expires_ms)
    SELECT ?,a.user_id,?,a.auth_epoch,?,?,?,?,?,?,?,? FROM auth_accounts a JOIN auth_phone_aliases p ON p.user_id=a.user_id
    WHERE p.key_version=? AND p.phone_hash=? AND a.status='active'`,
    sessionId,id,c.club_revision,accessHash,refreshHash,now,now,now+POLICY.accessMs,now+POLICY.idleMs,now+POLICY.absoluteMs,this.vault.currentVersion,currentPhoneHash),
   this.assertion('changes()=1'),
   this.stmt(`INSERT INTO auth_audit SELECT ?,'phone_verified',user_id,club_id,session_id,? FROM auth_sessions WHERE session_id=?`,crypto.randomUUID(),now,sessionId)];
  try{await this.batch(steps);}catch(error){c=await this.stmt('SELECT * FROM auth_challenges WHERE challenge_id=? AND club_id=?',input.challengeId,id).first();
   if(c?.state==='consumed'&&await this.vault.verifyHash('request-key',requestKey(key),c.verification_key_hash))return this.verificationReplay(c,key,id);throw error;}
  return this.bundleView(tokens,id);
 }
 async authenticate(id,accessToken){await this.ready(id);const {id:sessionId}=splitToken(accessToken);
  const s=await this.stmt(`SELECT s.* FROM ${sessionJoin} WHERE s.session_id=? AND s.club_id=? AND s.access_hash=? AND ${this.liveSession} AND s.access_expires_ms>${SQL_NOW}`,
    sessionId,id,await sha256(accessToken)).first();requireValue(s,'unauthenticated',401);return s;}
 async current(id,accessToken){const s=await this.authenticate(id,accessToken);return {schemaVersion:1,userId:s.user_id,clubId:s.club_id,sessionId:s.session_id,phoneVerified:true,role:'supporter',authenticatedAt:s.authenticated_at_ms};}
 async refreshReplay(id,sessionId,oldHash,key){const r=await this.stmt('SELECT * FROM auth_refresh_receipts WHERE session_id=? AND old_refresh_hash=?',sessionId,oldHash).first();if(!r)return null;
  if(!await this.vault.verifyHash('request-key',requestKey(key),r.request_key_hash)){await this.batch([
   this.stmt('UPDATE auth_sessions SET revoked_at_ms=COALESCE(revoked_at_ms,?) WHERE session_id=?',this.clock(),sessionId),
   this.stmt(`INSERT INTO auth_audit SELECT ?,'refresh_reuse_detected',user_id,club_id,session_id,? FROM auth_sessions WHERE session_id=?`,crypto.randomUUID(),this.clock(),sessionId)]);
   throw new AuthError('reauthentication_required',401);}
  requireValue(r.replay_until_ms>this.clock()&&r.response_cipher,'reauthentication_required',401);
  return this.bundleView(await this.vault.open(r.response_cipher,`refresh:${sessionId}:${oldHash}:${r.request_key_hash}`),id);}
 async refresh(id,input,key){exactKeys(input,['refreshToken']);await this.ready(id);
  const {id:sessionId}=splitToken(input.refreshToken),oldHash=await sha256(input.refreshToken),keyHash=await this.key(key);
  // Club check precedes replay/reuse effects: a token submitted to another club cannot revoke its owner.
  const owner=await this.stmt('SELECT club_id FROM auth_sessions WHERE session_id=?',sessionId).first();requireValue(owner?.club_id===id,'unauthenticated',401);
  const replay=await this.refreshReplay(id,sessionId,oldHash,key);if(replay)return replay;
  const s=await this.stmt(`SELECT s.* FROM ${sessionJoin} WHERE s.session_id=? AND s.club_id=? AND s.refresh_hash=? AND ${this.liveSession} AND s.refresh_expires_ms>${SQL_NOW}`,sessionId,id,oldHash).first();requireValue(s,'unauthenticated',401);
  const tokens=await this.tokenBundle(sessionId),now=this.clock(),accessHash=await sha256(tokens.accessToken),refreshHash=await sha256(tokens.refreshToken);
  const encrypted=await this.vault.seal(tokens,`refresh:${sessionId}:${oldHash}:${keyHash}`);
  try{await this.batch([
   this.assertion(`EXISTS(SELECT 1 FROM ${sessionJoin} WHERE s.session_id=? AND s.club_id=? AND s.refresh_hash=? AND ${this.liveSession} AND s.refresh_expires_ms>${SQL_NOW})`,sessionId,id,oldHash),
   this.stmt(`UPDATE auth_sessions SET access_hash=?,refresh_hash=?,generation=generation+1,access_expires_ms=MIN(?,absolute_expires_ms),refresh_expires_ms=MIN(?,absolute_expires_ms)
    WHERE session_id=? AND refresh_hash=? AND revoked_at_ms IS NULL`,accessHash,refreshHash,now+POLICY.accessMs,now+POLICY.idleMs,sessionId,oldHash),
   this.assertion('changes()=1'),
   this.stmt('INSERT INTO auth_refresh_receipts VALUES(?,?,?,?,?,?,?)',sessionId,oldHash,keyHash,s.generation+1,encrypted,now+POLICY.replayMs,now),
   this.audit('session_rotated',s.user_id,id,sessionId)]);
  }catch(error){const raced=await this.refreshReplay(id,sessionId,oldHash,key);if(raced)return raced;throw error;}
  return this.bundleView(tokens,id);
 }
 async revoke(id,token,input){exactKeys(input,['scope']);requireValue(['current','others','all'].includes(input.scope));const s=await this.authenticate(id,token);
  if(input.scope!=='current')requireValue(this.clock()-s.authenticated_at_ms<=POLICY.freshMs,'recent_verification_required',403);
  const predicate=input.scope==='current'?'session_id=?':input.scope==='others'?'user_id=? AND session_id<>?':'user_id=?';
  const args=input.scope==='current'?[s.session_id]:input.scope==='others'?[s.user_id,s.session_id]:[s.user_id];
  await this.batch([this.assertion(`EXISTS(SELECT 1 FROM ${sessionJoin} WHERE s.session_id=? AND s.access_hash=? AND ${this.liveSession} AND s.access_expires_ms>${SQL_NOW}
    AND (?='current' OR s.authenticated_at_ms>=${SQL_NOW}-?))`,s.session_id,await sha256(token),input.scope,POLICY.freshMs),
    this.stmt(`UPDATE auth_sessions SET revoked_at_ms=COALESCE(revoked_at_ms,?) WHERE ${predicate}`,this.clock(),...args),
    this.audit(`sessions_revoked_${input.scope}`,s.user_id,id,s.session_id)]);
  return {schemaVersion:1,scope:input.scope,revoked:true};
 }
 deletionView(r){return {schemaVersion:1,requestId:r.request_id,state:'pending_external_erasure',sessionsRevoked:true,erasureCompleted:false};}
 async deletionReplay(id,token,key){const {id:sessionId}=splitToken(token),keys=await this.keyHashes(key),slots=keys.map(()=>'?').join(',');
  const r=await this.stmt(`SELECT r.* FROM auth_deletion_requests r JOIN auth_accounts a ON a.user_id=r.user_id
   WHERE r.session_id=? AND r.club_id=? AND r.access_hash=? AND r.request_key_hash IN(${slots})
   AND r.requested_at_ms>${SQL_NOW}-? AND r.state='pending_external_erasure' AND a.status='deletion_pending'`,
   sessionId,id,await sha256(token),...keys,POLICY.replayMs).first();return r?this.deletionView(r):null;}
 async deletion(id,token,input,key){exactKeys(input,['confirmation']);requireValue(input.confirmation==='DELETE MY ACCOUNT');await this.ready(id);
  const keyHash=await this.key(key),replay=await this.deletionReplay(id,token,key);if(replay)return replay;const s=await this.authenticate(id,token);
  requireValue(this.clock()-s.authenticated_at_ms<=POLICY.freshMs,'recent_verification_required',403);const requestId=crypto.randomUUID(),now=this.clock();
  try{await this.batch([
   this.assertion(`EXISTS(SELECT 1 FROM ${sessionJoin} WHERE s.session_id=? AND s.access_hash=? AND ${this.liveSession} AND s.access_expires_ms>${SQL_NOW}
    AND s.authenticated_at_ms>=${SQL_NOW}-?)`,s.session_id,await sha256(token),POLICY.freshMs),
   this.stmt("UPDATE auth_accounts SET status='deletion_pending' WHERE user_id=? AND status='active'",s.user_id),this.assertion('changes()=1'),
   this.stmt("UPDATE auth_challenges SET state='cancelled',delivery_cipher=NULL WHERE phone_hash=(SELECT phone_hash FROM auth_accounts WHERE user_id=?) AND state='open'",s.user_id),
   this.stmt('UPDATE auth_sessions SET revoked_at_ms=COALESCE(revoked_at_ms,?) WHERE user_id=?',now,s.user_id),
   this.stmt('INSERT INTO auth_deletion_requests(request_id,user_id,request_key_hash,requested_at_ms,session_id,club_id,access_hash) VALUES(?,?,?,?,?,?,?)',requestId,s.user_id,keyHash,now,s.session_id,id,await sha256(token)),
   this.stmt("INSERT INTO auth_outbox(event_id,kind,user_id,created_at_ms) VALUES(?,'identity.deletion_requested',?,?)",requestId,s.user_id,now),
   this.audit('deletion_requested',s.user_id,id,s.session_id)]);
  }catch(error){const completed=await this.deletionReplay(id,token,key);if(completed)return completed;throw error;}
  return this.deletionView({request_id:requestId});
 }
}
