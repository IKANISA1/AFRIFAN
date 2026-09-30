import { requireValue as need } from './errors.mjs';
/** Version fingerprints and retirement bounds are immutable database commitments.
 * This function never creates/replaces keys or initializes an identity implicitly.
 */
export async function assertRegisteredKeyMaterial(db,vault,{allowCurrentMissing=false}={}){
 const missing=[];
 for(const v of vault.readVersions()){
  const fingerprint=await vault.fingerprint(v),row=await db.prepare('SELECT * FROM auth_key_versions WHERE key_version=?').bind(v).first();
  if(!row){need(allowCurrentMissing&&v===vault.currentVersion,'crypto_not_registered',503);missing.push({version:v,...fingerprint});continue;}
  need(row.hmac_fingerprint===fingerprint.hmac&&row.encryption_fingerprint===fingerprint.encryption,'key_material_changed',503);
 }
 return missing;
}
export async function assertRegisteredKeyPolicy(db,vault){
 await assertRegisteredKeyMaterial(db,vault);
 const settings=await db.prepare('SELECT key_version FROM auth_settings WHERE singleton=1').first();
 need(settings?.key_version===vault.currentVersion,'key_policy_changed',503);
 if(vault.currentVersion==='1')return;
 const row=await db.prepare('SELECT * FROM auth_key_rotations WHERE to_version=?').bind(vault.currentVersion).first();
 need(row&&row.policy_activated_at_ms===vault.policy.activatedAt,'key_policy_changed',503);
 let retained;try{retained=JSON.parse(row.retained_versions_json);}catch{need(false,'key_policy_changed',503);}
 need(Array.isArray(retained),'key_policy_changed',503);
 for(const expected of retained){const actual=vault.policy.versions.find(v=>v.version===expected.version);
  need((actual&&actual.notBefore===expected.notBefore&&actual.readUntil===expected.readUntil)||(!actual&&vault.clock()>=expected.readUntil),'key_policy_changed',503);
 }
 for(const actual of vault.policy.versions.filter(v=>v.version!==vault.currentVersion)){
  need(retained.some(v=>v.version===actual.version&&v.notBefore===actual.notBefore&&v.readUntil===actual.readUntil),'key_policy_changed',503);
 }
}
