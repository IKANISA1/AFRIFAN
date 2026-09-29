import { IdentityService, POLICY } from './identity-service.mjs';
import { AuthError, requireValue as need, exactKeys, UUID, phoneNumber } from './errors.mjs';
import { randomSecret, splitToken, sha256 } from './crypto.mjs';

const NOW = "CAST(unixepoch('subsec') * 1000 AS INTEGER)";
const BOOT_MS = 600000;
const JOIN = `auth_browser_sessions b
 JOIN auth_sessions s ON s.session_id=b.auth_session_id
 JOIN auth_accounts a ON a.user_id=s.user_id
 JOIN auth_clubs c ON c.club_id=b.club_id
 JOIN auth_browser_origins o ON o.origin=b.origin
 JOIN auth_browser_control x ON x.singleton=1`;
const LIVE = `b.revoked_ms IS NULL AND b.expires_ms>${NOW} AND b.absolute_ms>${NOW}
 AND s.revoked_at_ms IS NULL AND s.absolute_expires_ms>${NOW}
 AND s.club_id=b.club_id AND s.account_epoch=a.auth_epoch AND a.status='active'
 AND c.enabled=1 AND c.revision=s.club_revision AND o.enabled=1 AND o.club_id=b.club_id
 AND o.revision=b.origin_revision AND x.enabled=1 AND x.revision=b.control_revision
 AND EXISTS(SELECT 1 FROM auth_settings WHERE singleton=1 AND import_ready=1
 AND length(import_evidence)>0 AND key_version='1')`;
const TIME = n => Number.isSafeInteger(n) && n >= 0 && n <= 253402300799999;
function key(value) { need(typeof value === 'string' && UUID.test(value)); return value; }
export function browserConfig(env) {
 need(env.AUTH_BROWSER_ENABLED === 'true', 'browser_disabled', 503);
 need(typeof env.BROWSER_ORIGIN === 'string', 'browser_not_configured', 503);
 let url;
 try { url = new URL(env.BROWSER_ORIGIN); } catch { throw new AuthError('browser_not_configured',503); }
 need(url.protocol === 'https:' && url.origin === env.BROWSER_ORIGIN && !url.username && !url.password,
  'browser_not_configured',503);
 const clubId = Number(env.BROWSER_CLUB_ID);
 need(typeof env.BROWSER_CLUB_ID === 'string' && /^[1-9][0-9]{0,9}$/.test(env.BROWSER_CLUB_ID)
  && Number.isSafeInteger(clubId), 'browser_not_configured',503);
 return {origin:url.origin, clubId};
}
/** A distinct cookie credential; native tokens are never returned by this service.
 * Identity, session, origin and policy epochs are in the SAME AUTH_DB.
 * Each new instance begins a first-primary D1 session; later reads are not a snapshot.
 */
export class BrowserSessionService {
 constructor(env,{clock=Date.now}={}) {
  this.config=browserConfig(env); this.clock=clock;
  need(typeof env.AUTH_DB?.withSession==='function','browser_not_configured',503);
  this.identity=new IdentityService({...env,AUTH_DB:env.AUTH_DB.withSession('first-primary')},{clock});
  this.db=this.identity.db; this.vault=this.identity.vault;
 }
 stmt(sql,...args) { return this.db.prepare(sql).bind(...args); }
 async ready() {
  const {origin,clubId}=this.config; await this.identity.ready(clubId);
  const row=await this.stmt(`SELECT o.revision AS origin_revision,x.revision AS control_revision,
   x.idle_ms,x.absolute_ms FROM auth_browser_origins o,auth_browser_control x
   WHERE o.origin=? AND o.club_id=? AND o.enabled=1 AND x.singleton=1 AND x.enabled=1`,origin,clubId).first();
  need(row,'browser_disabled',503); return row;
 }
 hashCookie(cookie) { splitToken(cookie); return this.vault.hash('browser-session',cookie); }
 csrf(cookie) { return this.vault.hash('browser-csrf',cookie); }
 async checkCsrf(cookie,csrf) {
  need(await this.vault.verifyHash('browser-csrf',cookie,csrf),'csrf_rejected',403);
 }
 async bootstrap(cookie,csrf) {
  need(typeof cookie==='string' && cookie.length<=2048,'bootstrap_required',401);
  let b;
  try { b=await this.vault.open(cookie,`browser-bootstrap:${this.config.origin}:${this.config.clubId}`); }
  catch { throw new AuthError('bootstrap_required',401); }
  exactKeys(b,['version','origin','clubId','clientSecret','issuedAt','expiresAt']);
  need(b.version===1 && b.origin===this.config.origin && b.clubId===this.config.clubId &&
   TIME(b.issuedAt) && TIME(b.expiresAt) && b.issuedAt<=this.clock() &&
   b.expiresAt===b.issuedAt+BOOT_MS && b.expiresAt>this.clock(),'bootstrap_required',401);
  if(csrf!==undefined) await this.checkCsrf(cookie,csrf);
  return {...b,hash:await this.vault.hash('browser-bootstrap',cookie)};
 }
 async start({sessionCookie=null}={}) {
  await this.ready();
  if(sessionCookie) {
   try { await this.current(sessionCookie); throw new AuthError('already_authenticated',409); }
   catch(e) { if(e.code!=='unauthenticated') throw e; }
  }
  const issuedAt=this.clock();
  const cookie=await this.vault.seal({version:1,...this.config,clientSecret:randomSecret(),
   issuedAt,expiresAt:issuedAt+BOOT_MS},`browser-bootstrap:${this.config.origin}:${this.config.clubId}`);
  return {bootstrapCookie:cookie,view:{schemaVersion:1,clubId:this.config.clubId,
   csrfToken:await this.csrf(cookie),expiresAt:issuedAt+BOOT_MS}};
 }
 async bootstrapView(cookie) {
  await this.ready(); const b=await this.bootstrap(cookie);
  return {schemaVersion:1,clubId:b.clubId,csrfToken:await this.csrf(cookie),expiresAt:b.expiresAt};
 }
 async challenge({bootstrapCookie,csrfToken,requestId,ipKey,input}) {
  exactKeys(input,['phone']); phoneNumber(input.phone); key(requestId);
  const policy=await this.ready(),b=await this.bootstrap(bootstrapCookie,csrfToken);
  const issueHash=await this.identity.key(requestId),phoneHash=await this.vault.hash('phone',input.phone);
  need(!await this.stmt('SELECT 1 FROM auth_browser_sessions WHERE bootstrap_hash=?',b.hash).first(),
   'bootstrap_consumed',409);
  // Reserve ONE issuance identity before dispatch; retries cannot change phone or key.
  const exists=`EXISTS(SELECT 1 FROM auth_browser_origins o,auth_browser_control x WHERE
   o.origin=? AND o.club_id=? AND o.enabled=1 AND o.revision=? AND x.singleton=1 AND x.enabled=1 AND x.revision=?)`;
  await this.identity.batch([
   this.identity.assertion(exists,b.origin,b.clubId,policy.origin_revision,policy.control_revision),
   this.stmt(`INSERT INTO auth_browser_challenges VALUES(?,?,?,?,?,?,?,?,?)
    ON CONFLICT(bootstrap_hash) DO NOTHING`,b.hash,b.origin,b.clubId,policy.origin_revision,
     policy.control_revision,issueHash,phoneHash,b.expiresAt,this.clock())
  ]);
  const bound=await this.stmt('SELECT * FROM auth_browser_challenges WHERE bootstrap_hash=?',b.hash).first();
  need(bound && bound.request_key_hash===issueHash && bound.phone_hash===phoneHash &&
   bound.origin_revision===policy.origin_revision && bound.control_revision===policy.control_revision,
   'idempotency_conflict',409);
  const result=await this.identity.challenge(b.clubId,{phone:input.phone,clientSecret:b.clientSecret},requestId,ipKey);
  await this.ready();
  return {...result,expiresAt:Math.min(b.expiresAt,result.expiresAt)};
 }
 async row(browserId,live=true) {
  const {origin,clubId}=this.config;
  return this.stmt(`SELECT b.*,s.user_id,s.authenticated_at_ms FROM ${JOIN}
   WHERE b.browser_id=? AND b.origin=? AND b.club_id=? ${live?`AND ${LIVE}`:''}`,
    browserId,origin,clubId).first();
 }
 async view(row,cookie) {
  return {schemaVersion:1,clubId:row.club_id,userId:row.user_id,sessionId:row.browser_id,
   authenticatedAt:row.authenticated_at_ms,expiresAt:row.expires_ms,absoluteExpiresAt:row.absolute_ms,
   role:'supporter',phoneVerified:true,csrfToken:await this.csrf(cookie)};
 }
 async current(cookie) {
  await this.ready(); const {id}=splitToken(cookie),hash=await this.hashCookie(cookie),row=await this.row(id);
  need(row && row.cookie_hash===hash,'unauthenticated',401); return this.view(row,cookie);
 }
 async loginReplay(row,requestHash,keyHash,sessionCookie) {
  need(row.verify_key_hash===keyHash && row.verify_request_hash===requestHash,'idempotency_conflict',409);
  const head=await this.row(row.browser_id);
  need(head && head.generation===0 && head.cookie_response_cipher && head.replay_until_ms>this.clock(),
   'reauthentication_required',401);
  if(sessionCookie) need(await this.hashCookie(sessionCookie)===head.cookie_hash,'session_changed',409);
  const data=await this.vault.open(head.cookie_response_cipher,`browser-login:${head.browser_id}:${keyHash}`);
  need(await this.hashCookie(data.cookie)===head.cookie_hash,'service_unavailable',503);
  return {sessionCookie:data.cookie,view:await this.view(head,data.cookie)};
 }
 async verify({bootstrapCookie,csrfToken,requestId,input,sessionCookie=null}) {
  exactKeys(input,['challengeId','code']);key(requestId);
  need(typeof input.challengeId==='string' && UUID.test(input.challengeId));
  need(typeof input.code==='string' && /^[0-9]{6}$/.test(input.code));
  const policy=await this.ready(),b=await this.bootstrap(bootstrapCookie,csrfToken);
  const keyHash=await this.identity.key(requestId);
  const requestHash=await this.vault.hash('browser-verification',JSON.stringify([b.hash,input.challengeId,input.code]));
  const prior=await this.stmt('SELECT * FROM auth_browser_sessions WHERE bootstrap_hash=?',b.hash).first();
  if(prior) return this.loginReplay(prior,requestHash,keyHash,sessionCookie);
  if(sessionCookie) {
   try { await this.current(sessionCookie); throw new AuthError('already_authenticated',409); }
   catch(e) { if(e.code!=='unauthenticated') throw e; }
  }
  const bound=await this.stmt(`SELECT bc.* FROM auth_browser_challenges bc JOIN auth_challenges c
   ON c.club_id=bc.club_id AND c.request_key_hash=bc.request_key_hash
   WHERE bc.bootstrap_hash=? AND c.challenge_id=? AND bc.origin=? AND bc.club_id=?
   AND bc.origin_revision=? AND bc.control_revision=? AND bc.expires_ms>${NOW}`,
   b.hash,input.challengeId,b.origin,b.clubId,policy.origin_revision,policy.control_revision).first();
  need(bound,'invalid_code',401);
  const tokens=await this.identity.verify(b.clubId,{...input,clientSecret:b.clientSecret},requestId);
  const browserId=crypto.randomUUID(),cookie=`${browserId}.${randomSecret()}`;
  const hash=await this.hashCookie(cookie),now=this.clock();
  const absolute=Math.min(now+policy.absolute_ms,tokens.refreshExpiresAt),expires=Math.min(now+policy.idle_ms,absolute);
  const cipher=await this.vault.seal({cookie},`browser-login:${browserId}:${keyHash}`);
  try {
   await this.identity.batch([
    this.identity.assertion(`EXISTS(SELECT 1 FROM auth_sessions s JOIN auth_accounts a ON a.user_id=s.user_id
     JOIN auth_clubs c ON c.club_id=s.club_id,auth_settings x,auth_browser_origins o,auth_browser_control bc
     WHERE s.session_id=? AND s.club_id=? AND s.access_hash=? AND s.access_expires_ms>${NOW}
     AND s.revoked_at_ms IS NULL AND s.account_epoch=a.auth_epoch AND a.status='active'
     AND c.enabled=1 AND c.revision=s.club_revision AND x.singleton=1 AND x.import_ready=1
     AND length(x.import_evidence)>0 AND x.key_version='1' AND o.origin=? AND o.club_id=s.club_id
     AND o.enabled=1 AND o.revision=? AND bc.singleton=1 AND bc.enabled=1 AND bc.revision=?)`,
     tokens.sessionId,b.clubId,await sha256(tokens.accessToken),b.origin,policy.origin_revision,policy.control_revision),
    this.stmt(`INSERT INTO auth_browser_sessions(browser_id,auth_session_id,origin,club_id,origin_revision,
     control_revision,bootstrap_hash,verify_key_hash,verify_request_hash,cookie_hash,expires_ms,absolute_ms,
     created_ms,cookie_response_cipher,replay_until_ms) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
     browserId,tokens.sessionId,b.origin,b.clubId,policy.origin_revision,policy.control_revision,b.hash,keyHash,
     requestHash,hash,expires,absolute,now,cipher,now+POLICY.replayMs),
    this.identity.audit('browser_session_created',tokens.userId,b.clubId,tokens.sessionId)
   ]);
  } catch(e) {
   const raced=await this.stmt('SELECT * FROM auth_browser_sessions WHERE bootstrap_hash=?',b.hash).first();
   if(raced) return this.loginReplay(raced,requestHash,keyHash,sessionCookie);
   throw e;
  }
  return this.loginReplay(await this.row(browserId),requestHash,keyHash,sessionCookie);
 }
 async rotationReplay(receipt,row,hash) {
  need(row && [receipt.old_cookie_hash,receipt.new_cookie_hash].includes(hash) &&
   row.generation===receipt.generation && row.cookie_hash===receipt.new_cookie_hash &&
   receipt.replay_until_ms>this.clock() && receipt.response_cipher,'reauthentication_required',401);
  const data=await this.vault.open(receipt.response_cipher,`browser-rotation:${row.browser_id}:${receipt.request_key_hash}`);
  need(await this.hashCookie(data.cookie)===row.cookie_hash,'service_unavailable',503);
  return {sessionCookie:data.cookie,view:await this.view(row,data.cookie)};
 }
 async rotate({sessionCookie,csrfToken,requestId}) {
  key(requestId); const policy=await this.ready(); await this.checkCsrf(sessionCookie,csrfToken);
  const {id}=splitToken(sessionCookie),hash=await this.hashCookie(sessionCookie),keyHash=await this.identity.key(requestId);
  const row=await this.row(id),prior=await this.stmt('SELECT * FROM auth_browser_rotations WHERE browser_id=? AND request_key_hash=?',id,keyHash).first();
  if(prior) return this.rotationReplay(prior,row,hash);
  need(row && row.cookie_hash===hash,'unauthenticated',401);
  const cookie=`${id}.${randomSecret()}`,nextHash=await this.hashCookie(cookie),now=this.clock();
  const cipher=await this.vault.seal({cookie},`browser-rotation:${id}:${keyHash}`);
  try {
   await this.identity.batch([
    this.identity.assertion(`EXISTS(SELECT 1 FROM ${JOIN} WHERE b.browser_id=? AND b.cookie_hash=? AND ${LIVE})`,id,hash),
    this.stmt(`UPDATE auth_browser_sessions SET cookie_hash=?,generation=generation+1,
     expires_ms=MIN(?,absolute_ms),cookie_response_cipher=NULL WHERE browser_id=? AND cookie_hash=? AND revoked_ms IS NULL`,
     nextHash,now+policy.idle_ms,id,hash),this.identity.assertion('changes()=1'),
    this.stmt('INSERT INTO auth_browser_rotations VALUES(?,?,?,?,?,?,?,?)',id,keyHash,hash,nextHash,row.generation+1,cipher,now+POLICY.replayMs,now),
    this.identity.audit('browser_session_rotated',row.user_id,row.club_id,row.auth_session_id)
   ]);
  } catch(e) {
   const raced=await this.stmt('SELECT * FROM auth_browser_rotations WHERE browser_id=? AND request_key_hash=?',id,keyHash).first();
   if(raced) return this.rotationReplay(raced,await this.row(id),hash);
   throw e;
  }
  return this.rotationReplay(await this.stmt('SELECT * FROM auth_browser_rotations WHERE browser_id=? AND request_key_hash=?',id,keyHash).first(),await this.row(id),hash);
 }
 async logout({sessionCookie,csrfToken,requestId}) {
  key(requestId);await this.checkCsrf(sessionCookie,csrfToken);
  const {id}=splitToken(sessionCookie),hash=await this.hashCookie(sessionCookie),keyHash=await this.identity.key(requestId);
  const row=await this.row(id,false);
  need(row && row.cookie_hash===hash,'unauthenticated',401);
  if(row.revoked_ms!==null) {
   need(row.logout_key_hash===keyHash,'unauthenticated',401);
   return {schemaVersion:1,loggedOut:true,scope:'current'};
  }
  // Revocation remains possible for an expired/paused cookie, but only its exact owner credential.
  // The retired cookie can replay ONLY this original logout; it authorizes no other operation.
  try {
   await this.identity.batch([
    this.stmt(`UPDATE auth_browser_sessions SET revoked_ms=?,logout_key_hash=?,cookie_response_cipher=NULL
     WHERE browser_id=? AND cookie_hash=? AND revoked_ms IS NULL`,this.clock(),keyHash,id,hash),
    this.identity.assertion('changes()=1'),
    this.stmt('UPDATE auth_sessions SET revoked_at_ms=COALESCE(revoked_at_ms,?) WHERE session_id=?',this.clock(),row.auth_session_id),
    this.stmt('UPDATE auth_browser_rotations SET response_cipher=NULL WHERE browser_id=?',id),
    this.identity.audit('browser_session_revoked',row.user_id,row.club_id,row.auth_session_id)
   ]);
  } catch(e) {
   const head=await this.row(id,false);
   if(!(head?.cookie_hash===hash && head.logout_key_hash===keyHash && head.revoked_ms!==null)) throw e;
  }
  return {schemaVersion:1,loggedOut:true,scope:'current'};
 }
}
/** Bounded cipher expiry does not require keys, enabled login, or provider bindings. No audit rows are deleted. */
export async function expireBrowserSecrets(db) {
 need(typeof db?.prepare==='function' && typeof db.batch==='function','service_unavailable',503);
 return db.batch([
  db.prepare(`UPDATE auth_browser_sessions SET cookie_response_cipher=NULL WHERE browser_id IN
   (SELECT browser_id FROM auth_browser_sessions WHERE cookie_response_cipher IS NOT NULL AND replay_until_ms<=${NOW} LIMIT 100)`),
  db.prepare(`UPDATE auth_browser_rotations SET response_cipher=NULL WHERE rowid IN
   (SELECT rowid FROM auth_browser_rotations WHERE response_cipher IS NOT NULL AND replay_until_ms<=${NOW} LIMIT 100)`)
 ]);
}
