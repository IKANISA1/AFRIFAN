#!/usr/bin/env node
import { readFileSync,writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { Vault,sha256 } from '../src/crypto.mjs';
import { exactKeys,requireValue,UUID,phoneNumber } from '../src/errors.mjs';
const quote=s=>"'"+String(s).replaceAll("'","''")+"'";
/** Offline plan only; neither connects to a provider nor enables sign-in. */
export async function prepareImport(bytes,expectedHash,expectedUsers,env,{now=Date.now()}={}){
 requireValue(bytes instanceof Uint8Array&&bytes.byteLength<=10_000_000);
 const sourceHash=await sha256(bytes);requireValue(sourceHash===expectedHash,'source_checksum_mismatch');
 requireValue(Number.isSafeInteger(expectedUsers)&&expectedUsers>=0&&expectedUsers<=10000);
 let data;try{data=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));}catch{requireValue(false,'invalid_import');}
 exactKeys(data,['schemaVersion','sourceProject','users']);requireValue(data.schemaVersion===1&&typeof data.sourceProject==='string'&&/^[a-z0-9_-]{3,64}$/.test(data.sourceProject));
 requireValue(Array.isArray(data.users)&&data.users.length===expectedUsers,'user_count_mismatch');
 const vault=new Vault(env),ids=new Set(),phones=new Set(),statements=[];
 for(const u of data.users){exactKeys(u,['id','phone','phoneConfirmedAt','createdAt','status']);requireValue(typeof u.id==='string'&&UUID.test(u.id));phoneNumber(u.phone);
  requireValue(['active','suspended','deletion_pending'].includes(u.status));requireValue(!ids.has(u.id)&&!phones.has(u.phone),'duplicate_identity');ids.add(u.id);phones.add(u.phone);
  const verified=Date.parse(u.phoneConfirmedAt),created=Date.parse(u.createdAt);
  requireValue(typeof u.phoneConfirmedAt==='string'&&typeof u.createdAt==='string'&&Number.isSafeInteger(verified)&&Number.isSafeInteger(created)&&created<=verified&&verified<=now&&created>0,'unverified_identity');
  const hash=await vault.hash('phone',u.phone),cipher=await vault.seal({phone:u.phone},`phone:${hash}`);
  statements.push(`INSERT INTO auth_accounts(user_id,phone_hash,phone_cipher,status,verified_at_ms,created_at_ms,source_project,source_user_id) VALUES(${[u.id,hash,cipher,u.status].map(quote).join(',')},${verified},${created},${quote(data.sourceProject)},${quote(u.id)});`);
 }
 const guard=crypto.randomUUID();
 const sql=[`-- PRIVATE, OFFLINE, CREATE-ONLY PLAN. No activation, role or membership grant.`,
  `-- Source SHA-256 ${sourceHash}; verified-phone records ${expectedUsers}.`,
  `-- Apply only to an empty, isolated identity database with every gateway disabled.`,
  `INSERT INTO auth_assertions VALUES(${quote(guard)},CASE WHEN (SELECT count(*) FROM auth_accounts)=0 AND (SELECT import_ready FROM auth_settings WHERE singleton=1)=0 THEN 1 ELSE 0 END);`,
  `DELETE FROM auth_assertions WHERE assertion_id=${quote(guard)};`,...statements,
  `INSERT INTO auth_assertions VALUES(${quote(guard)},CASE WHEN (SELECT count(*) FROM auth_accounts)=${expectedUsers} AND (SELECT import_ready FROM auth_settings WHERE singleton=1)=0 THEN 1 ELSE 0 END);`,
  `DELETE FROM auth_assertions WHERE assertion_id=${quote(guard)};`].join('\n')+'\n';
 return {sql,report:{schemaVersion:1,sourceSha256:sourceHash,userCount:expectedUsers,sqlSha256:await sha256(sql),networkCalls:0,activationAuthorized:false,
  coverage:'only the supplied verified-phone identity records; anonymous/unverified identities and profiles are not migrated'}};
}
async function main(){const [input,output,hash,count,...rest]=process.argv.slice(2);if(!input||!output||!hash||count===undefined||rest.length)throw Error('usage: prepare-import.mjs input.private.json output.private.sql expected-sha256 expected-users');
 const result=await prepareImport(readFileSync(input),hash,Number(count),process.env);writeFileSync(output,result.sql,{mode:0o600,flag:'wx'});
 writeFileSync(`${output}.manifest.json`,JSON.stringify(result.report,null,2)+'\n',{mode:0o600,flag:'wx'});console.log(JSON.stringify(result.report));}
if(process.argv[1]&&pathToFileURL(resolve(process.argv[1])).href===import.meta.url)main().catch(()=>{console.error('Identity import plan rejected; no sign-in or remote state was changed.');process.exitCode=1;});
