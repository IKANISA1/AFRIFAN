import fs from 'node:fs';
import path from 'node:path';
/** Only reviewed public settings may become byte literals in an artifact.
 * Runtime privileged credentials must be provided by the Worker environment.
 */
export const PUBLIC_ARTIFACT_ENVIRONMENT_KEYS=Object.freeze([
 'NEXT_PUBLIC_SITE_URL','NEXT_PUBLIC_ADMIN_URL','NEXT_PUBLIC_SUPABASE_URL',
 'NEXT_PUBLIC_SUPABASE_ANON_KEY','SUPABASE_URL','SUPABASE_ANON_KEY',
 'GIKUNDIRO_PUBLIC_SUPABASE_URL','GIKUNDIRO_PUBLIC_SUPABASE_ANON_KEY',
 'RAYON_PUBLIC_CLOUDFLARE_URL','NEXT_PUBLIC_FAN_APP_URL',
 'NEXT_PUBLIC_ANDROID_APP_LINK_SHA256_FINGERPRINTS','NEXT_PUBLIC_CLUB_CURRENCY_CODE',
 'NEXT_PUBLIC_CLUB_CURRENCY_SYMBOL','NEXT_PUBLIC_CLUB_HOST_MAP_JSON',
 'NEXT_PUBLIC_DEFAULT_CLUB_ID','NEXT_PUBLIC_DEFAULT_CLUB_SLUG','NEXT_PUBLIC_GSC_TOKEN',
 'NEXT_PUBLIC_SITE_DESCRIPTION','NEXT_PUBLIC_SITE_SHORT_TITLE','NEXT_PUBLIC_SITE_TITLE',
 'NEXT_PUBLIC_VAPID_PUBLIC_KEY','VAPID_PUBLIC_KEY','NEXT_PUBLIC_WEB_OBSERVATIONS_ENABLED',
]);
function publicValue(value){
 if(typeof value!=='string'||value.length>16384||value.includes('\0')||
  /-----BEGIN[^\n]*PRIVATE KEY-----|\bsb_secret_[A-Za-z0-9_-]+/.test(value))return false;
 // Adapter dotenv parsers evaluate commands and expand variables. A bare '$'
 // currency symbol is data; expressions are never accepted as public values.
 if(/\$[({A-Za-z_]/.test(value))return false;
 // Keep the high-confidence families aligned with the complete artifact audit.
 if(/(?:sb_secret_|sk_live_|rk_live_)[A-Za-z0-9_-]{16,}|(?:ghp_|gho_|ghu_|ghs_|ghr_)[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|(?:AKIA|ASIA)[A-Z0-9]{16}|xox[baprs]-[A-Za-z0-9-]{20,}|SG\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sk-(?:proj-|svcacct-)[A-Za-z0-9_-]{20,}/.test(value))return false;
 if(/(?:auth_hmac_key|auth_encryption_key|supabase_service_role_key|aws_secret_access_key|cloudflare_api_token|client_secret|api_secret|private_key|access_token|refresh_token)\b["']?\s*[:=]\s*["'][A-Za-z0-9_+/=.-]{32,}["']/i.test(value))return false;
 for(const token of value.matchAll(/\beyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g)){
  try{
   const claims=JSON.parse(Buffer.from(token[0].split('.')[1],'base64url').toString('utf8'));
   // An anonymous project key is public. Other JWT roles are runtime authority.
   if(claims?.role!=='anon')return false;
  }catch{return false;}
 }
 return true;
}
export function publicArtifactEnvironment(input){
 const selected={};
 for(const key of PUBLIC_ARTIFACT_ENVIRONMENT_KEYS){
  if(!Object.hasOwn(input,key))continue;
  const value=input[key];
  if(!publicValue(value))throw Error('unsafe_public_artifact_environment');
  selected[key]=value;
 }
 return selected;
}
export function dotenvPublicEnvironment(input){
 return Object.entries(publicArtifactEnvironment(input)).map(([key,value])=>{
  // Raw quoted literals preserve quotes/newlines without JSON escape changes.
  // Prefer single quotes so adapter expansion is disabled altogether.
  const quote=["'",'`','"'].find(candidate=>!value.includes(candidate)&&
   (candidate!=='"'||!/\\[nrt]/.test(value)));
  if(!quote)throw Error('unrepresentable_public_artifact_environment');
  const literal=quote==="'"?value:value.replace(/\\(?=\$)/g,'\\\\');
  return `${key}=${quote}${literal}${quote}\n`;
 }).join('');
}
/** Parse public settings without evaluation, decryption, ambient environment
 * lookup or private-value projection. File ordering follows the adapter. */
export function parsePublicArtifactDotenv(source){
 const selected={};
 const line=/(?:^|^)\s*(?:export\s+)?([\w.-]+)(?:\s*=\s*?|:\s+?)(\s*'(?:\\'|[^'])*'|\s*"(?:\\"|[^"])*"|\s*`(?:\\`|[^`])*`|[^#\r\n]+)?\s*(?:#.*)?(?:$|$)/mg;
 for(const match of source.replace(/\r\n?/g,'\n').matchAll(line)){
  if(!PUBLIC_ARTIFACT_ENVIRONMENT_KEYS.includes(match[1]))continue;
  let value=(match[2]??'').trim();const quote=value[0];
  if(["'",'"','`'].includes(quote)&&value.at(-1)===quote)value=value.slice(1,-1);
  if(quote==='"')value=value.replace(/\\n/g,'\n').replace(/\\r/g,'\r').replace(/\\t/g,'\t');
  selected[match[1]]=value;
 }
 return publicArtifactEnvironment(selected);
}
export function extractPublicArtifactEnvironment(mode,appPath){
 if(!['production','development','test'].includes(mode))throw Error('invalid_public_artifact_environment_mode');
 const selected={};
 for(const file of ['.env',`.env.${mode}`,...(mode==='test'?[]:['.env.local']),`.env.${mode}.local`]){
  const full=path.join(appPath,file);
  if(fs.existsSync(full)&&fs.statSync(full).isFile())Object.assign(selected,parsePublicArtifactDotenv(fs.readFileSync(full,'utf8')));
 }
 return publicArtifactEnvironment(selected);
}
