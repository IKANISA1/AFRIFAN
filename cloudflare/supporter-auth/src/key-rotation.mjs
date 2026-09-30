import { assertRegisteredKeyMaterial, assertRegisteredKeyPolicy } from './key-state.mjs';
import { Vault, splitToken, KEY_RETENTION } from './crypto.mjs';
import { AuthError, requireValue as need, exactKeys, phoneNumber } from './errors.mjs';

const NOW="CAST(unixepoch('subsec') * 1000 AS INTEGER)";
const CONTACTS=[{table:'auth_accounts',id:'user_id',column:'phone_cipher',aad:r=>`phone:${r.phone_hash}`},
 {table:'auth_challenges',id:'challenge_id',column:'phone_cipher',aad:r=>`phone:${r.phone_hash}`}];
const TRANSIENT=[{table:'auth_challenges',id:'challenge_id',column:'delivery_cipher',aad:r=>`challenge:${r.challenge_id}`,kind:'delivery'},
 {table:'auth_challenges',id:'challenge_id',column:'verification_cipher',aad:r=>`verification:${r.challenge_id}:${r.verification_key_hash}`,kind:'tokens'},
 {table:'auth_refresh_receipts',id:'old_refresh_hash',column:'response_cipher',aad:r=>`refresh:${r.session_id}:${r.old_refresh_hash}:${r.request_key_hash}`,kind:'tokens'},
 {table:'auth_browser_sessions',id:'browser_id',column:'cookie_response_cipher',aad:r=>`browser-login:${r.browser_id}:${r.verify_key_hash}`,kind:'cookie'},
 {table:'auth_browser_rotations',id:'request_key_hash',column:'response_cipher',aad:r=>`browser-rotation:${r.browser_id}:${r.request_key_hash}`,kind:'cookie'}];
const safe=operation=>async(...args)=>{try{return await operation(...args);}catch(e){if(e instanceof AuthError)throw e;throw new AuthError('key_rotation_storage_unavailable',503);}};
const version=v=>typeof v==='string'&&/^[1-9][0-9]{0,2}$/.test(v);
function context(env,{clock=Date.now,expectedCurrentVersion,evidence,batchLimit=100}={}){
 need(typeof env.AUTH_DB?.withSession==='function','key_rotation_unavailable',503);
 need(version(expectedCurrentVersion)&&typeof evidence==='string'&&/^[A-Za-z0-9_.:-]{1,128}$/.test(evidence), 'invalid_key_rotation',400);
 need(Number.isInteger(batchLimit)&&batchLimit>=1&&batchLimit<=100,'invalid_key_rotation',400);
 const vault=new Vault(env,{clock});need(Number(vault.currentVersion)>Number(expectedCurrentVersion)&&vault.policy.versions.some(v=>v.version===expectedCurrentVersion), 'invalid_key_rotation',400);
 need(env.AUTH_DELIVERY_ENABLED==='false','key_rotation_requires_pause',409);
 const db=env.AUTH_DB.withSession('first-primary'),stmt=(sql,...args)=>db.prepare(sql).bind(...args);
 return {env,clock,vault,db,stmt,expectedCurrentVersion,evidence,batchLimit};
}
async function paused(c){const settings=await c.stmt(`SELECT x.* FROM auth_settings x,auth_delivery_control d
 WHERE x.singleton=1 AND x.import_ready=0 AND x.key_version=? AND d.singleton=1 AND d.enabled=0`,c.expectedCurrentVersion).first();
 need(settings,'key_rotation_requires_pause',409);return settings;}
function guard(c){const id=crypto.randomUUID();return {id,statement:c.stmt(`INSERT INTO auth_assertions(assertion_id,ok) VALUES(?,CASE WHEN EXISTS(
 SELECT 1 FROM auth_settings x,auth_delivery_control d WHERE x.singleton=1 AND x.import_ready=0 AND x.key_version=?
 AND d.singleton=1 AND d.enabled=0) THEN 1 ELSE 0 END)`,id,c.expectedCurrentVersion)};}
function assertion(c,sql,...args){const id=crypto.randomUUID();return [c.stmt(`INSERT INTO auth_assertions VALUES(?,CASE WHEN (${sql}) THEN 1 ELSE 0 END)`,id,...args),c.stmt('DELETE FROM auth_assertions WHERE assertion_id=?',id)];}
async function execute(c,steps){const check=guard(c);await c.db.batch([check.statement,...steps,c.stmt('DELETE FROM auth_assertions WHERE assertion_id=?',check.id)]);}
async function countNotCurrent(c,table,column){const r=await c.stmt(`SELECT count(*) AS n FROM ${table} WHERE ${column} IS NOT NULL AND ${column} NOT LIKE ?`,`${c.vault.currentVersion}.%`).first();return r.n;}
async function readiness(c){const missing=await c.stmt(`SELECT count(*) AS n FROM auth_accounts a WHERE NOT EXISTS
 (SELECT 1 FROM auth_phone_aliases p WHERE p.user_id=a.user_id AND p.key_version=?)`,c.vault.currentVersion).first();
 let oldCiphertexts=0;for(const spec of [...CONTACTS,...TRANSIENT])oldCiphertexts+=await countNotCurrent(c,spec.table,spec.column);
 return {missingPhoneAliases:missing.n,oldCiphertexts,complete:missing.n===0&&oldCiphertexts===0};}
function validatePayload(spec,row,payload){
 if(spec.kind==='delivery'){exactKeys(payload,['phone','code']);phoneNumber(payload.phone);need(typeof payload.code==='string'&&/^\d{6}$/.test(payload.code),'key_rotation_payload_invalid',503);}
 else if(spec.kind==='tokens'){exactKeys(payload,['sessionId','accessToken','refreshToken']);
  need(payload.sessionId===row.session_id&&splitToken(payload.accessToken).id===row.session_id&&splitToken(payload.refreshToken).id===row.session_id,'key_rotation_payload_invalid',503);}
 else if(spec.kind==='cookie'){exactKeys(payload,['cookie']);need(splitToken(payload.cookie).id===row.browser_id,'key_rotation_payload_invalid',503);}
 else{exactKeys(payload,['phone']);phoneNumber(payload.phone);}
}
function recordWhere(spec,row){
 if(spec.table==='auth_refresh_receipts')return {sql:'session_id=? AND old_refresh_hash=?',args:[row.session_id,row.old_refresh_hash]};
 if(spec.table==='auth_browser_rotations')return {sql:'browser_id=? AND request_key_hash=?',args:[row.browser_id,row.request_key_hash]};
 return {sql:`${spec.id}=?`,args:[row[spec.id]]};
}
/** Explicit local/admin-library operation. It exposes no Worker route or automatic retry.
 * Import and delivery stay paused. A bounded transaction preserves UUIDs, canonical
 * phone hashes, auth epochs, operation hashes, response payloads and timestamps.
 * Call again explicitly to process another batch; an unknown acknowledgement is
 * safe to reconcile by inspecting/re-running this same bounded preparation.
 */
async function doprepareIdentityKeyRotation(env,options){const c=context(env,options);await paused(c);let processed=0;
 const missing=await assertRegisteredKeyMaterial(c.db,c.vault,{allowCurrentMissing:true}),steps=[];
 const previous=await c.stmt('SELECT retained_versions_json FROM auth_key_rotations WHERE to_version=?',c.expectedCurrentVersion).first();
 if(previous){let versions;try{versions=JSON.parse(previous.retained_versions_json);}catch{need(false,'key_policy_changed',503);}
  need(versions.every(v=>c.clock()>=v.readUntil),'key_rotation_overlap',409);}
 for(const m of missing)steps.push(c.stmt('INSERT INTO auth_key_versions VALUES(?,?,?,?,?)',m.version,m.hmac,m.encryption,c.evidence,c.clock()));
 const accounts=await c.stmt(`SELECT a.* FROM auth_accounts a WHERE a.phone_cipher NOT LIKE ? OR NOT EXISTS
  (SELECT 1 FROM auth_phone_aliases p WHERE p.user_id=a.user_id AND p.key_version=?) ORDER BY a.user_id LIMIT ?`,
 `${c.vault.currentVersion}.%`,c.vault.currentVersion,c.batchLimit).all();
 for(const row of accounts.results){const payload=await c.vault.open(row.phone_cipher,`phone:${row.phone_hash}`);validatePayload(CONTACTS[0],row,payload);
  const candidates=await c.vault.hashes('phone',payload.phone),currentHash=await c.vault.hash('phone',payload.phone);
  const aliases=await c.stmt('SELECT phone_hash FROM auth_phone_aliases WHERE user_id=?',row.user_id).all();
  need(candidates.some(v=>v.hash===row.phone_hash||aliases.results.some(a=>a.phone_hash===v.hash)),'identity_mapping_conflict',503);
  const cipher=await c.vault.seal(payload,`phone:${row.phone_hash}`);
  steps.push(c.stmt(`UPDATE auth_accounts SET phone_cipher=? WHERE user_id=? AND phone_cipher=?`,cipher,row.user_id,row.phone_cipher),
   ...assertion(c,'changes()=1'),c.stmt('INSERT INTO auth_phone_aliases VALUES(?,?,?,?) ON CONFLICT DO NOTHING',c.vault.currentVersion,currentHash,row.user_id,c.clock()),
   ...assertion(c,'EXISTS(SELECT 1 FROM auth_phone_aliases WHERE key_version=? AND phone_hash=? AND user_id=?)',c.vault.currentVersion,currentHash,row.user_id));processed++;
 }
 for(const spec of [...CONTACTS.slice(1),...TRANSIENT]){if(processed>=c.batchLimit)break;
  const rows=await c.stmt(`SELECT * FROM ${spec.table} WHERE ${spec.column} IS NOT NULL AND ${spec.column} NOT LIKE ? ORDER BY ${spec.id} LIMIT ?`,`${c.vault.currentVersion}.%`,c.batchLimit-processed).all();
  for(const row of rows.results){const payload=await c.vault.open(row[spec.column],spec.aad(row));validatePayload(spec,row,payload);
   const cipher=await c.vault.seal(payload,spec.aad(row)),where=recordWhere(spec,row);
   steps.push(c.stmt(`UPDATE ${spec.table} SET ${spec.column}=? WHERE ${where.sql} AND ${spec.column}=?`,cipher,...where.args,row[spec.column]),...assertion(c,'changes()=1'));processed++;
  }
 }
 if(steps.length)await execute(c,steps);
 return {schemaVersion:1,fromVersion:c.expectedCurrentVersion,toVersion:c.vault.currentVersion,processed,...await readiness(c),
  importEnabled:false,deliveryEnabled:false,identityIdsChanged:false,authenticationTimestampsChanged:false};
}
/** Commits only the prepared key version and immutable evidence identifier. It never
 * enables import/delivery, changes active credentials or creates an identity.
 */
async function doactivateIdentityKeyRotation(env,options){const c=context(env,options);
 await assertRegisteredKeyMaterial(c.db,c.vault);
 const prior=await c.stmt('SELECT * FROM auth_key_rotations WHERE to_version=?',c.vault.currentVersion).first();
 if(prior){need(prior.from_version===c.expectedCurrentVersion&&prior.evidence===c.evidence,'key_rotation_conflict',409);
  const row=await c.stmt('SELECT key_version,import_ready FROM auth_settings WHERE singleton=1').first();need(row?.key_version===c.vault.currentVersion&&row.import_ready===0,'key_rotation_conflict',409);
  return {schemaVersion:1,currentVersion:c.vault.currentVersion,activated:true,importEnabled:false,deliveryEnabled:false};}
 await paused(c);await assertRegisteredKeyMaterial(c.db,c.vault);const r=await readiness(c);need(r.complete,'key_rotation_incomplete',409);
 need(c.vault.policy.versions.filter(v=>v.version!==c.vault.currentVersion).every(v=>v.readUntil>=c.clock()+KEY_RETENTION.minMs),'key_retention_too_short',409);
 const check=guard(c),id=check.id;
 await c.db.batch([check.statement,
  c.stmt(`INSERT INTO auth_assertions VALUES(?,CASE WHEN NOT EXISTS(SELECT 1 FROM auth_accounts a WHERE NOT EXISTS
   (SELECT 1 FROM auth_phone_aliases p WHERE p.user_id=a.user_id AND p.key_version=?)) THEN 1 ELSE 0 END)`,id+'-coverage',c.vault.currentVersion),
  // Account aliases and all retained ciphertexts are checked inside the activation transaction.
  ...[...CONTACTS,...TRANSIENT].flatMap(spec=>assertion(c,`NOT EXISTS(SELECT 1 FROM ${spec.table} WHERE ${spec.column} IS NOT NULL AND ${spec.column} NOT LIKE ?)`,`${c.vault.currentVersion}.%`)),
  c.stmt('UPDATE auth_settings SET key_version=? WHERE singleton=1 AND import_ready=0 AND key_version=?',c.vault.currentVersion,c.expectedCurrentVersion),...assertion(c,'changes()=1'),
  c.stmt('INSERT INTO auth_key_rotations VALUES(?,?,?,?,?,?)',c.vault.currentVersion,c.expectedCurrentVersion,c.evidence,c.clock(),JSON.stringify(c.vault.policy.versions.filter(v=>v.version!==c.vault.currentVersion)),c.vault.policy.activatedAt),
  c.stmt('INSERT INTO auth_audit VALUES(?,?,?,?,?,?)',crypto.randomUUID(),'identity_key_version_activated',null,null,null,c.clock()),
  c.stmt('DELETE FROM auth_assertions WHERE assertion_id IN(?,?)',id,id+'-coverage')]);
 return {schemaVersion:1,currentVersion:c.vault.currentVersion,activated:true,importEnabled:false,deliveryEnabled:false};
}
/** Aggregate preflight; does not remove secrets or revoke sessions. Missing aliases,
 * retained old ciphertexts and live old-HMAC OTP/cookie credentials block retirement.
 * Native opaque bearer hashes are SHA-256 and do not depend on an old Vault key.
 */
async function doidentityKeyRetirementReadiness(env,{retiringVersion,clock=Date.now}={}){
 const vault=new Vault(env,{clock}),db=env.AUTH_DB?.withSession?.('first-primary');need(db&&version(retiringVersion)&&Number(retiringVersion)<Number(vault.currentVersion),'invalid_key_retirement',400);
 await assertRegisteredKeyPolicy(db,vault);
 const policy=vault.policy.versions.find(v=>v.version===retiringVersion);need(policy&&policy.readUntil!==null,'invalid_key_retirement',400);
 const stmt=(sql,...args)=>db.prepare(sql).bind(...args),result={};
 result.missingPhoneAliases=(await stmt(`SELECT count(*) AS n FROM auth_accounts a WHERE NOT EXISTS(SELECT 1 FROM auth_phone_aliases p WHERE p.user_id=a.user_id AND p.key_version=?)`,vault.currentVersion).first()).n;
 result.retainedCiphertexts=0;for(const spec of [...CONTACTS,...TRANSIENT])result.retainedCiphertexts+=(await stmt(`SELECT count(*) AS n FROM ${spec.table} WHERE ${spec.column} LIKE ?`,`${retiringVersion}.%`).first()).n;
 result.liveChallenges=(await stmt(`SELECT count(*) AS n FROM auth_challenges WHERE hmac_key_version=? AND state='open' AND expires_at_ms>${NOW}`,retiringVersion).first()).n;
 result.liveBrowserCredentials=(await stmt(`SELECT count(*) AS n FROM auth_browser_sessions b JOIN auth_sessions s ON s.session_id=b.auth_session_id
  JOIN auth_accounts a ON a.user_id=s.user_id JOIN auth_clubs c ON c.club_id=b.club_id WHERE b.cookie_key_version=?
  AND b.revoked_ms IS NULL AND b.expires_ms>${NOW} AND b.absolute_ms>${NOW} AND s.revoked_at_ms IS NULL
  AND s.absolute_expires_ms>${NOW} AND a.status='active' AND a.auth_epoch=s.account_epoch AND c.enabled=1 AND c.revision=s.club_revision`,retiringVersion).first()).n;
 const gate=await stmt('SELECT key_version FROM auth_settings WHERE singleton=1').first();
 const dependencies=Object.values(result).reduce((a,b)=>a+b,0),deadlineReached=clock()>=policy.readUntil;
 return {schemaVersion:1,currentVersion:vault.currentVersion,retiringVersion,retireAt:policy.readUntil,deadlineReached,...result,
  retirementAllowed:gate?.key_version===vault.currentVersion&&deadlineReached&&dependencies===0,secretsRemoved:false,identitiesRegenerated:false};
}

/** First registration is permitted only in an empty, paused isolated version-one
 * database. It registers fingerprints; it cannot initialize or reconstruct users.
 */
async function doregisterInitialIdentityKeys(env,{clock=Date.now,evidence}={}){
 need(typeof env.AUTH_DB?.withSession==='function'&&env.AUTH_DELIVERY_ENABLED==='false','key_rotation_requires_pause',409);
 need(typeof evidence==='string'&&/^[A-Za-z0-9_.:-]{1,128}$/.test(evidence),'invalid_key_rotation',400);
 const vault=new Vault(env,{clock});need(vault.currentVersion==='1','invalid_key_rotation',400);
 const db=env.AUTH_DB.withSession('first-primary'),stmt=(sql,...args)=>db.prepare(sql).bind(...args),fp=await vault.fingerprint('1');
 const prior=await stmt("SELECT * FROM auth_key_versions WHERE key_version='1'").first();
 if(prior){need(prior.hmac_fingerprint===fp.hmac&&prior.encryption_fingerprint===fp.encryption&&prior.evidence===evidence,'key_material_changed',503);
  return {schemaVersion:1,keyVersion:'1',registered:true,identitiesCreated:false};}
 const id=crypto.randomUUID();
 await db.batch([stmt(`INSERT INTO auth_assertions VALUES(?,CASE WHEN EXISTS(SELECT 1 FROM auth_settings x,auth_delivery_control d
  WHERE x.singleton=1 AND x.import_ready=0 AND x.key_version='1' AND d.singleton=1 AND d.enabled=0)
  AND NOT EXISTS(SELECT 1 FROM auth_accounts) AND NOT EXISTS(SELECT 1 FROM auth_challenges)
  AND NOT EXISTS(SELECT 1 FROM auth_sessions) THEN 1 ELSE 0 END)`,id),
  stmt('INSERT INTO auth_key_versions VALUES(?,?,?,?,?)','1',fp.hmac,fp.encryption,evidence,clock()),stmt('DELETE FROM auth_assertions WHERE assertion_id=?',id)]);
 return {schemaVersion:1,keyVersion:'1',registered:true,identitiesCreated:false};
}

/** Explicit emergency/release-library action for locally rehearsed retirement.
 * It revokes, rather than recreates, browser credentials that still rely on an
 * old HMAC key. There is no public endpoint and no automatic provider work.
 */
async function dorevokeRetiringBrowserCredentials(env,{retiringVersion,confirmation,evidence,clock=Date.now,batchLimit=100}={}){
 need(confirmation==='REVOKE OLD BROWSER CREDENTIALS'&&typeof evidence==='string'&&/^[A-Za-z0-9_.:-]{1,128}$/.test(evidence),'invalid_key_retirement',400);
 need(env.AUTH_DELIVERY_ENABLED==='false'&&Number.isInteger(batchLimit)&&batchLimit>=1&&batchLimit<=100,'key_rotation_requires_pause',409);
 const vault=new Vault(env,{clock}),db=env.AUTH_DB?.withSession?.('first-primary');need(db&&version(retiringVersion)&&Number(retiringVersion)<Number(vault.currentVersion),'invalid_key_retirement',400);
 await assertRegisteredKeyPolicy(db,vault);
 const stmt=(sql,...args)=>db.prepare(sql).bind(...args),gate=await stmt(`SELECT 1 FROM auth_settings x,auth_delivery_control d
  WHERE x.singleton=1 AND x.import_ready=0 AND x.key_version=? AND d.singleton=1 AND d.enabled=0`,vault.currentVersion).first();need(gate,'key_rotation_requires_pause',409);
 need(await stmt('SELECT 1 FROM auth_key_versions WHERE key_version=?',retiringVersion).first(),'invalid_key_retirement',400);
 const rows=await stmt(`SELECT * FROM auth_browser_sessions WHERE cookie_key_version=? AND revoked_ms IS NULL ORDER BY browser_id LIMIT ?`,retiringVersion,batchLimit).all();
 const steps=[],guardId=crypto.randomUUID();
 for(const row of rows.results){steps.push(stmt('UPDATE auth_browser_sessions SET revoked_ms=?,cookie_response_cipher=NULL WHERE browser_id=? AND cookie_key_version=? AND revoked_ms IS NULL',clock(),row.browser_id,retiringVersion),
  ...assertion({stmt},'changes()=1'),stmt('UPDATE auth_sessions SET revoked_at_ms=COALESCE(revoked_at_ms,?) WHERE session_id=?',clock(),row.auth_session_id),
  stmt('UPDATE auth_browser_rotations SET response_cipher=NULL WHERE browser_id=?',row.browser_id),
  stmt('INSERT INTO auth_audit VALUES(?,?,?,?,?,?)',crypto.randomUUID(),'browser_key_retired',null,row.club_id,row.auth_session_id,clock()));}
 if(steps.length)await db.batch([stmt(`INSERT INTO auth_assertions VALUES(?,CASE WHEN EXISTS(SELECT 1 FROM auth_settings x,auth_delivery_control d
  WHERE x.singleton=1 AND x.import_ready=0 AND x.key_version=? AND d.singleton=1 AND d.enabled=0) THEN 1 ELSE 0 END)`,guardId,vault.currentVersion),...steps,
  stmt('DELETE FROM auth_assertions WHERE assertion_id=?',guardId)]);
 const remaining=await stmt('SELECT count(*) AS n FROM auth_browser_sessions WHERE cookie_key_version=? AND revoked_ms IS NULL',retiringVersion).first();
 return {schemaVersion:1,retiringVersion,processed:rows.results.length,complete:remaining.n===0,identitiesCreated:false,secretsRemoved:false};
}

export const prepareIdentityKeyRotation=safe(doprepareIdentityKeyRotation);

export const activateIdentityKeyRotation=safe(doactivateIdentityKeyRotation);

export const identityKeyRetirementReadiness=safe(doidentityKeyRetirementReadiness);

export const registerInitialIdentityKeys=safe(doregisterInitialIdentityKeys);

export const revokeRetiringBrowserCredentials=safe(dorevokeRetiringBrowserCredentials);
