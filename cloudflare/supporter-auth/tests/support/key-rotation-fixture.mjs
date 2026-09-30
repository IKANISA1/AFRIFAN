import assert from 'node:assert/strict';
import { IdentityService } from '../../src/identity-service.mjs';
import { randomSecret } from '../../src/crypto.mjs';
import { prepareIdentityKeyRotation, activateIdentityKeyRotation } from '../../src/key-rotation.mjs';
export const verificationInput=c=>({challengeId:c.challengeId,code:c.code,clientSecret:c.secret});
/** Synthetic key material only. Never used by a runtime template or provider. */
export function rotatedEnv(f,{missing=false,until=f.clock.now+900000,activatedAt=f.clock.now}={}){
 const env={...f.env,AUTH_KEY_VERSION:'2',AUTH_KEY_POLICY_JSON:JSON.stringify({schemaVersion:1,currentVersion:'2',activatedAt,
  versions:[{version:'1',notBefore:0,readUntil:until},{version:'2',notBefore:activatedAt,readUntil:null}]}),
 AUTH_KEYRING_JSON:JSON.stringify({schemaVersion:1,keys:{...(!missing?{'1':{hmac:'a'.repeat(64),encryption:'b'.repeat(64)}}:{}),'2':{hmac:'e'.repeat(64),encryption:'f'.repeat(64)}}})};
 delete env.AUTH_HMAC_KEY;delete env.AUTH_ENCRYPTION_KEY;return env;
}
export function pause(f,env){env.AUTH_DELIVERY_ENABLED='false';f.db.sqlite.exec('UPDATE auth_settings SET import_ready=0;UPDATE auth_delivery_control SET enabled=0');}
export function rotationOptions(f,extra={}){return {clock:()=>f.clock.now,expectedCurrentVersion:'1',evidence:'synthetic-local-key-rotation',batchLimit:100,...extra};}
export async function rotate(f,env=rotatedEnv(f)){
 pause(f,env);const options=rotationOptions(f);let prepared;let batches=0;
 do{prepared=await prepareIdentityKeyRotation(env,options);assert(++batches<=100);}while(!prepared.complete);
 await activateIdentityKeyRotation(env,options);f.db.sqlite.exec('UPDATE auth_settings SET import_ready=1');
 return new IdentityService(env,{clock:()=>f.clock.now});
}
export async function issue(f,service,{phone,club=24,key=f.key(),secret=randomSecret()}={}){
 const c=await service.challenge(club,{phone,clientSecret:secret},key,'c'.repeat(64));
 const row=f.sql('SELECT * FROM auth_challenges WHERE challenge_id=?',c.challengeId)[0],payload=await service.vault.open(row.delivery_cipher,`challenge:${c.challengeId}`);
 return {...c,phone,requestKey:key,secret,code:payload.code};
}
export async function login(f,service,options){const c=await issue(f,service,options),key=f.key(),tokens=await service.verify(c.clubId,verificationInput(c),key);return {c,key,tokens};}
export function replaceEnv(f,env){for(const name of ['AUTH_HMAC_KEY','AUTH_ENCRYPTION_KEY','AUTH_KEY_POLICY_JSON','AUTH_KEYRING_JSON'])delete f.env[name];Object.assign(f.env,env);}
