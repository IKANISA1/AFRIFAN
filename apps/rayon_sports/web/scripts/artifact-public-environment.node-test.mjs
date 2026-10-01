import test from 'node:test';
import assert from 'node:assert/strict';
import {publicArtifactEnvironment,dotenvPublicEnvironment,parsePublicArtifactDotenv,extractPublicArtifactEnvironment} from './artifact-public-environment.mjs';
import {parse as parseAdapterDotenv} from '@dotenvx/dotenvx';
import {mkdtempSync,writeFileSync,rmSync,existsSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
const token=role=>[Buffer.from(JSON.stringify({alg:'HS256'})).toString('base64url'),
 Buffer.from(JSON.stringify({role})).toString('base64url'),'synthetic-signature'].join('.');
test('dotenv projection never inspects privileged or unknown public-prefixed inputs',()=>{
 const input={NEXT_PUBLIC_SITE_TITLE:'Synthetic Club'};
 for(const key of ['SUPABASE_SERVICE_ROLE_KEY','POSTGRES_URL','SUPABASE_ACCESS_TOKEN',
  'VAPID_PRIVATE_KEY','NEXT_PUBLIC_SERVICE_ROLE_KEY','NODE_OPTIONS'])
  Object.defineProperty(input,key,{get(){throw Error('private_value_read');},enumerable:true});
 assert.deepEqual(publicArtifactEnvironment(input),{NEXT_PUBLIC_SITE_TITLE:'Synthetic Club'});
});
for(const role of ['service_role','authenticated','admin',null])test('privileged JWT cannot hide in a public setting '+role,()=>{
 assert.throws(()=>publicArtifactEnvironment({NEXT_PUBLIC_SUPABASE_ANON_KEY:token(role)}),/unsafe_public_artifact_environment/);
});
test('anonymous project JWT remains an explicit public key',()=>{
 const key=token('anon');assert.deepEqual(publicArtifactEnvironment({SUPABASE_ANON_KEY:key}),{SUPABASE_ANON_KEY:key});
});
for(const [family,value] of [
 ['payment','sk_live_'+'S'.repeat(32)],['restricted-payment','rk_live_'+'S'.repeat(32)],
 ...['ghp_','gho_','ghu_','ghs_','ghr_'].map(prefix=>[prefix,prefix+'S'.repeat(36)]),
 ['github-pat','github_pat_'+'S'.repeat(48)],['aws','AKIA'+'S'.repeat(16)],
 ['slack','xoxb-'+'S'.repeat(32)],['sendgrid','SG.'+'S'.repeat(32)+'.'+'S'.repeat(32)],
 ['project-key','sk-proj-'+'S'.repeat(32)],['service-account','sk-svcacct-'+'S'.repeat(32)],
 ['assignment','access_token="'+'S'.repeat(48)+'"'],
])test('public description refuses high-confidence credential family '+family,()=>{
 assert.throws(()=>publicArtifactEnvironment({NEXT_PUBLIC_SITE_DESCRIPTION:value}),error=>error.message==='unsafe_public_artifact_environment');
});
for(const value of ['-----BEGIN PRIVATE KEY-----\nsynthetic','sb_secret_synthetic','x'.repeat(16385),'x\0private'])
 test('unsafe public value is rejected without echoing it '+value.length,()=>{
  assert.throws(()=>publicArtifactEnvironment({NEXT_PUBLIC_SITE_TITLE:value}),error=>error.message==='unsafe_public_artifact_environment');
 });
for(const value of ['Synthetic "club"\n$5',"Synthetic club's page",'Both \'single\' and "double" quotes',
 'literal\\n value','bare $ currency',"line one\nline two",'a backtick ` in a title',
 "club's literal\\n and \\$5",'club\'s "title" C:\\path\\$5'])
 test('actual adapter parser preserves public literal '+JSON.stringify(value),()=>{
  const selected={NEXT_PUBLIC_SITE_TITLE:value};
  assert.deepEqual(parseAdapterDotenv(dotenvPublicEnvironment(selected),{processEnv:{}}),selected);
 });
for(const value of ['$(printf synthetic_marker)','$PRIVATE_VARIABLE','${PRIVATE_VARIABLE}',"'\"`"])
 test('expressions or unrepresentable public values fail before adapter parsing '+JSON.stringify(value),()=>{
  assert.throws(()=>dotenvPublicEnvironment({NEXT_PUBLIC_SITE_TITLE:value}),/public_artifact_environment/);
 });
test('passive original extraction never executes discarded private or unknown commands',t=>{
 const dir=mkdtempSync(join(tmpdir(),'africlub-public-env-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));
 const marker=join(dir,'should-not-exist');
 const text=`PRIVATE_SETTING=$(touch ${marker})\nNEXT_PUBLIC_UNKNOWN=$(touch ${marker})\nNEXT_PUBLIC_SITE_TITLE='Synthetic Club'\n`;
 writeFileSync(join(dir,'.env'),text);
 assert.deepEqual(parsePublicArtifactDotenv(text),{NEXT_PUBLIC_SITE_TITLE:'Synthetic Club'});
 assert.deepEqual(extractPublicArtifactEnvironment('production',dir),{NEXT_PUBLIC_SITE_TITLE:'Synthetic Club'});
 assert.equal(existsSync(marker),false);
});
test('passive extraction follows all eight mode files without ambient process substitution',t=>{
 const dir=mkdtempSync(join(tmpdir(),'africlub-public-env-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));
 for(const file of ['.env','.env.local','.env.production','.env.production.local','.env.development','.env.development.local','.env.test','.env.test.local'])
  writeFileSync(join(dir,file),`NEXT_PUBLIC_SITE_TITLE='${file}'\nPRIVATE_SETTING=$(printf never_executed)\n`);
 for(const mode of ['production','development','test'])
  assert.deepEqual(extractPublicArtifactEnvironment(mode,dir),{NEXT_PUBLIC_SITE_TITLE:`.env.${mode}.local`});
 rmSync(join(dir,'.env.test.local'));assert.equal(extractPublicArtifactEnvironment('test',dir).NEXT_PUBLIC_SITE_TITLE,'.env.test');
 rmSync(join(dir,'.env.production.local'));assert.equal(extractPublicArtifactEnvironment('production',dir).NEXT_PUBLIC_SITE_TITLE,'.env.local');
});
