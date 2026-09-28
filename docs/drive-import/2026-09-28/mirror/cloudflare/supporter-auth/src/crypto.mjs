import { requireValue, SECRET, UUID } from './errors.mjs';
const encoder=new TextEncoder(), decoder=new TextDecoder('utf-8',{fatal:true});
const hex=b=>Array.from(new Uint8Array(b),n=>n.toString(16).padStart(2,'0')).join('');
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
export class Vault {
 constructor(env){requireValue(env.AUTH_KEY_VERSION==='1'&&env.AUTH_HMAC_KEY!==env.AUTH_ENCRYPTION_KEY,'crypto_not_configured',503);
  this.hmacKey=crypto.subtle.importKey('raw',keyBytes(env.AUTH_HMAC_KEY),{name:'HMAC',hash:'SHA-256'},false,['sign','verify']);
  this.encryptionKey=crypto.subtle.importKey('raw',keyBytes(env.AUTH_ENCRYPTION_KEY),{name:'AES-GCM'},false,['encrypt','decrypt']);}
 async hash(label,value){return hex(await crypto.subtle.sign('HMAC',await this.hmacKey,encoder.encode(`${label}\u0000${value}`)));}
 async verifyHash(label,value,expected){if(typeof expected!=='string'||!/^[0-9a-f]{64}$/.test(expected))return false;return crypto.subtle.verify('HMAC',await this.hmacKey,Uint8Array.from(expected.match(/../g),x=>parseInt(x,16)),encoder.encode(`${label}\u0000${value}`));}
 async seal(value,aad){const iv=crypto.getRandomValues(new Uint8Array(12));
  const cipher=await crypto.subtle.encrypt({name:'AES-GCM',iv,additionalData:encoder.encode(aad)},await this.encryptionKey,encoder.encode(JSON.stringify(value)));
  return `1.${base64url(iv)}.${base64url(new Uint8Array(cipher))}`;}
 async open(value,aad){try{const [version,iv,cipher,...extra]=value.split('.');requireValue(version==='1'&&!extra.length);
  const result=await crypto.subtle.decrypt({name:'AES-GCM',iv:fromBase64url(iv),additionalData:encoder.encode(aad)},await this.encryptionKey,fromBase64url(cipher));
  return JSON.parse(decoder.decode(result));}catch{requireValue(false,'service_unavailable',503);}}
}
export function splitToken(token){requireValue(typeof token==='string'&&token.length===80,'unauthenticated',401);
 const [id,secret,...other]=token.split('.');requireValue(UUID.test(id)&&!other.length,'unauthenticated',401);
 try{validSecret(secret);}catch{requireValue(false,'unauthenticated',401);}return {id,secret};}
