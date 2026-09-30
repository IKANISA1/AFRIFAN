import { requireValue, SECRET, UUID } from './errors.mjs';
const encoder=new TextEncoder(), decoder=new TextDecoder('utf-8',{fatal:true});
const hex=b=>Array.from(new Uint8Array(b),n=>n.toString(16).padStart(2,'0')).join('');
const own=(o,keys)=>o&&typeof o==='object'&&!Array.isArray(o)&&Object.keys(o).length===keys.length&&keys.every(k=>Object.hasOwn(o,k));
const version=v=>typeof v==='string'&&/^[1-9][0-9]{0,2}$/.test(v);
const stamp=v=>Number.isSafeInteger(v)&&v>=0&&v<=253402300799999;
export const KEY_RETENTION=Object.freeze({minMs:900000,maxMs:604800000,maxVersions:4});
export function randomSecret(){return base64url(crypto.getRandomValues(new Uint8Array(32)));}
export function base64url(bytes){return btoa(String.fromCharCode(...bytes)).replaceAll('+','-').replaceAll('/','_').replace(/=+$/,'');}
export function fromBase64url(text){requireValue(typeof text==='string'&&/^[A-Za-z0-9_-]+$/.test(text));
 const bytes=Uint8Array.from(atob(text.replaceAll('-','+').replaceAll('_','/')),c=>c.charCodeAt(0));
 requireValue(base64url(bytes)===text);return bytes;}
export function validSecret(value){requireValue(typeof value==='string'&&SECRET.test(value));requireValue(fromBase64url(value).length===32);return value;}
export async function sha256(value){return hex(await crypto.subtle.digest('SHA-256',typeof value==='string'?encoder.encode(value):value));}
export function randomCode(){
 const a=new Uint32Array(1),limit=Math.floor(2**32/1_000_000)*1_000_000;
 do{crypto.getRandomValues(a);}while(a[0]>=limit);
 return String(a[0]%1_000_000).padStart(6,'0');
}
function keyBytes(value){requireValue(typeof value==='string'&&/^[0-9a-f]{64}$/.test(value),'crypto_not_configured',503);
 return Uint8Array.from(value.match(/../g),x=>parseInt(x,16));}
function configured(ok){requireValue(ok,'crypto_not_configured',503);}
/** Public lifecycle policy and secret material are separate. Only one current version writes.
 * The legacy pair is accepted ONLY for version 1 with no keyring/policy variables present.
 */
export function publicKeyPolicy(env){
 if(env.AUTH_KEY_POLICY_JSON===undefined){
  configured(env.AUTH_KEY_VERSION==='1');return Object.freeze({schemaVersion:1,currentVersion:'1',activatedAt:0,
   versions:Object.freeze([{version:'1',notBefore:0,readUntil:null}]),legacy:true});
 }
 configured(typeof env.AUTH_KEY_POLICY_JSON==='string'&&env.AUTH_KEY_POLICY_JSON.length<=8192);
 let p;try{p=JSON.parse(env.AUTH_KEY_POLICY_JSON);}catch{configured(false);}
 configured(own(p,['schemaVersion','currentVersion','activatedAt','versions'])&&p.schemaVersion===1&&
  version(p.currentVersion)&&p.currentVersion===env.AUTH_KEY_VERSION&&stamp(p.activatedAt)&&
  Array.isArray(p.versions)&&p.versions.length>=1&&p.versions.length<=KEY_RETENTION.maxVersions);
 const seen=new Set();let current=0;
 for(const v of p.versions){
  configured(own(v,['version','notBefore','readUntil'])&&version(v.version)&&!seen.has(v.version)&&stamp(v.notBefore));seen.add(v.version);
  if(v.version===p.currentVersion){configured(v.notBefore===p.activatedAt&&v.readUntil===null);current++;}
  else configured(Number(v.version)<Number(p.currentVersion)&&stamp(v.readUntil)&&v.notBefore<=p.activatedAt&&
   v.readUntil>=p.activatedAt+KEY_RETENTION.minMs&&v.readUntil<=p.activatedAt+KEY_RETENTION.maxMs);
 }
 configured(current===1);return Object.freeze({...p,versions:Object.freeze(p.versions.map(v=>Object.freeze({...v}))),legacy:false});
}
export function keyPolicy(env){const policy=publicKeyPolicy(env);
 if(policy.legacy)configured(env.AUTH_KEYRING_JSON===undefined);
 else configured(typeof env.AUTH_KEYRING_JSON==='string'&&env.AUTH_KEYRING_JSON.length<=8192&&env.AUTH_HMAC_KEY===undefined&&env.AUTH_ENCRYPTION_KEY===undefined);
 return policy;}
export class Vault {
 constructor(env,{clock=Date.now}={}){
  this.policy=keyPolicy(env);this.currentVersion=this.policy.currentVersion;this.clock=clock;this.keys=new Map();this.fingerprints=new Map();
  let ring;
  if(this.policy.legacy)ring={schemaVersion:1,keys:{'1':{hmac:env.AUTH_HMAC_KEY,encryption:env.AUTH_ENCRYPTION_KEY}}};
  else{try{ring=JSON.parse(env.AUTH_KEYRING_JSON);}catch{configured(false);}
   configured(own(ring,['schemaVersion','keys'])&&ring.schemaVersion===1&&ring.keys&&typeof ring.keys==='object'&&!Array.isArray(ring.keys));}
  configured(Object.keys(ring.keys).every(v=>this.policy.versions.some(p=>p.version===v)));
  const used=new Set();
  for(const p of this.policy.versions){
   const material=ring.keys[p.version];
   // Expired versions may have been explicitly removed. Declared live versions may not disappear.
   if(!material){configured(p.readUntil!==null&&this.clock()>=p.readUntil);continue;}
   configured(own(material,['hmac','encryption'])&&material.hmac!==material.encryption);
   const hmac=keyBytes(material.hmac),encryption=keyBytes(material.encryption);
   configured(!used.has(material.hmac)&&!used.has(material.encryption));used.add(material.hmac);used.add(material.encryption);
   this.fingerprints.set(p.version,Promise.all([sha256(material.hmac),sha256(material.encryption)]).then(([hmac,encryption])=>({hmac,encryption})));
   this.keys.set(p.version,{hmac:crypto.subtle.importKey('raw',hmac,{name:'HMAC',hash:'SHA-256'},false,['sign','verify']),
    encryption:crypto.subtle.importKey('raw',encryption,{name:'AES-GCM'},false,['encrypt','decrypt'])});
  }
  this.readKey(this.currentVersion);
 }
 async fingerprint(v){this.readKey(v);const result=await this.fingerprints.get(v);this.readKey(v);return result;}
 readDeadline(v){const p=this.policy.versions.find(p=>p.version===v);configured(p);return p.readUntil;}
 readKey(v){const p=this.policy.versions.find(p=>p.version===v),now=this.clock(),key=this.keys.get(v);
  configured(p&&key&&now>=p.notBefore&&(p.readUntil===null||now<p.readUntil));return key;}
 readVersions(){return this.policy.versions.filter(p=>this.clock()>=p.notBefore&&(p.readUntil===null||this.clock()<p.readUntil)).map(p=>p.version);}
 async hash(label,value,v=this.currentVersion){const out=hex(await crypto.subtle.sign('HMAC',await this.readKey(v).hmac,encoder.encode(`${label}\u0000${value}`)));this.readKey(v);return out;}
 async hashes(label,value){return Promise.all(this.readVersions().map(async v=>({version:v,hash:await this.hash(label,value,v)})));}
 async verifyHashVersion(label,value,expected,v){if(typeof expected!=='string'||!/^[0-9a-f]{64}$/.test(expected))return false;
  const matched=await crypto.subtle.verify('HMAC',await this.readKey(v).hmac,Uint8Array.from(expected.match(/../g),x=>parseInt(x,16)),encoder.encode(`${label}\u0000${value}`));this.readKey(v);return matched;}
 async verifyHash(label,value,expected){if(typeof expected!=='string'||!/^[0-9a-f]{64}$/.test(expected))return false;
  const bytes=Uint8Array.from(expected.match(/../g),x=>parseInt(x,16));
  for(const v of this.readVersions()){const matched=await crypto.subtle.verify('HMAC',await this.readKey(v).hmac,bytes,encoder.encode(`${label}\u0000${value}`));this.readKey(v);if(matched)return true;}
  return false;}
 aad(v,aad){return encoder.encode(v==='1'?aad:`auth-key:${v}\u0000${aad}`);}
 async seal(value,aad){const v=this.currentVersion,key=this.readKey(v),iv=crypto.getRandomValues(new Uint8Array(12));
  const cipher=await crypto.subtle.encrypt({name:'AES-GCM',iv,additionalData:this.aad(v,aad)},await key.encryption,encoder.encode(JSON.stringify(value)));
  // Check again after awaiting the cryptographic provider; never cross a retired-key deadline.
  this.readKey(v);return `${v}.${base64url(iv)}.${base64url(new Uint8Array(cipher))}`;}
 async open(value,aad){try{configured(typeof value==='string'&&value.length<=65536);const [v,iv,cipher,...extra]=value.split('.');configured(version(v)&&!extra.length);
  const key=this.readKey(v),ivBytes=fromBase64url(iv),cipherBytes=fromBase64url(cipher);configured(ivBytes.length===12&&cipherBytes.length>=16);
  const result=await crypto.subtle.decrypt({name:'AES-GCM',iv:ivBytes,additionalData:this.aad(v,aad)},await key.encryption,cipherBytes);
  this.readKey(v);return JSON.parse(decoder.decode(result));}catch{requireValue(false,'service_unavailable',503);}}
}
export function splitToken(token){requireValue(typeof token==='string'&&token.length===80,'unauthenticated',401);
 const [id,secret,...other]=token.split('.');requireValue(UUID.test(id)&&!other.length,'unauthenticated',401);
 try{validSecret(secret);}catch{requireValue(false,'unauthenticated',401);}return {id,secret};}
