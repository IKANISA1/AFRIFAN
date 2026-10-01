/** Convert a sealed Next build in a disposable source copy with public dotenv.
 * Original source/private settings are neither renamed nor edited. No deploy.
 */
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {createHash,randomUUID} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {validateProductionBuild,productionSourceSnapshot,productionArtifactSnapshot} from './web-build-provenance.mjs';
import {dotenvPublicEnvironment,extractPublicArtifactEnvironment} from './artifact-public-environment.mjs';
import {snapshotInstalledArtifactInputs,stageInstalledArtifactInputs} from './artifact-installed-inputs.mjs';

const web=path.resolve(fileURLToPath(new URL('..',import.meta.url)));
const id=randomUUID(),scratch=path.join(web,'tmp','isolated-opennext-'+id);
const stagedWeb=path.join(scratch,'apps/rayon_sports/web');
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const before=validateProductionBuild(web);
const sources=productionSourceSnapshot(web);
const result={schemaVersion:1,build:before,passed:false,providerCalls:0,deploymentActions:0,
 stagingDirectory:scratch,publicEnvironment:[],sourceSha256:sources.sha256};
const guardEntry=sources.files.find(entry=>entry.file==='../../../tools/scripts/local_ops_rehearsal_no_network.cjs');
result.nodeNetworkControl={path:guardEntry?.file,sha256:guardEntry?.sha256,
 scope:'Preloaded Node TCP/UDP/HTTP/fetch/DNS rejection; local Unix-domain IPC remains available. This is not operating-system network isolation.'};
const expectedEnvironment={};
const need=(value,code)=>{if(!value)throw Error(code);};
function copy(source,target){fs.mkdirSync(path.dirname(target),{recursive:true});fs.cpSync(source,target,{recursive:true,dereference:true,errorOnExist:true});}
try{
 need(!fs.existsSync(scratch),'staging_already_exists');fs.mkdirSync(scratch,{recursive:true,mode:0o700});fs.chmodSync(scratch,0o700);fs.mkdirSync(stagedWeb,{recursive:true});
 need(guardEntry,'artifact_network_control_unbound');
 // Copy the exact source file inventory rather than rewalking mutable source
 // directories. Private dotenv files are replaced with the public projection.
 for(const entry of sources.files.filter(file=>!/^\.env(?:\.|$)/.test(file.file))){
  const source=path.resolve(web,entry.file),target=path.resolve(stagedWeb,entry.file);
  need(hash(fs.readFileSync(source))===entry.sha256,'source_input_hash_changed');
  copy(source,target);
  need(hash(fs.readFileSync(target))===entry.sha256,'staged_source_hash_changed');
 }
 // Runtime caches/diagnostics are deliberately excluded from the source seal.
 // Copy only hash-bound compilation files, never promote those mutable inputs.
 const nextArtifacts=productionArtifactSnapshot(web);
 need(nextArtifacts.sha256===before.artifact_sha256,'next_artifact_inventory_changed');
 for(const entry of nextArtifacts.files){
  const source=path.join(web,'.next',entry.file);
  need(hash(fs.readFileSync(source))===entry.sha256,'next_input_hash_changed');
  const target=path.join(stagedWeb,'.next',entry.file);copy(source,target);
  need(hash(fs.readFileSync(target))===entry.sha256,'staged_next_hash_changed');
 }
 const installed=snapshotInstalledArtifactInputs(web);
 need(installed.sha256===before.installed_inputs_sha256&&installed.sourceBindingSha256===before.installed_inputs_binding_sha256,'installed_inputs_differ_from_compilation');
 result.installedInputs=stageInstalledArtifactInputs(web,stagedWeb,installed);
 need(result.installedInputs.verified===true,'staged_installed_inputs_unverified');
 fs.writeFileSync(path.join(scratch,'installed-inputs.json'),JSON.stringify(installed)+'\n',{flag:'wx',mode:0o600});
 for(const mode of ['production','development','test']){
  const projected=extractPublicArtifactEnvironment(mode,web);
  const dotenv=dotenvPublicEnvironment(projected);
  expectedEnvironment[mode]=projected;
  fs.writeFileSync(path.join(stagedWeb,'.env.'+mode),dotenv,{flag:'wx',mode:0o600});
  result.publicEnvironment.push({mode,keys:Object.keys(projected).sort(),sha256:hash(dotenv)});
 }
 const env={};
 for(const key of ['PATH','HOME','TMPDIR','LANG','LC_ALL','LC_CTYPE'])if(process.env[key])env[key]=process.env[key];
 Object.assign(env,{CI:'1',NO_COLOR:'1',WRANGLER_SEND_METRICS:'false',
  NODE_OPTIONS:`--require=${path.resolve(stagedWeb,guardEntry.file)}`});
 // Execute package code only from the independently verified installed tree,
 // under the bound guard. Original private files never reach dotenvx.
 const preflight=spawnSync(process.execPath,['--input-type=module','-e',`
  import fs from 'node:fs'; import {parse} from '@dotenvx/dotenvx';
  const expected=JSON.parse(fs.readFileSync(0,'utf8'));
  for(const mode of ['production','development','test']) {
   const actual=parse(fs.readFileSync('.env.'+mode,'utf8'),{processEnv:{}});
   if(JSON.stringify(actual)!==JSON.stringify(expected[mode]))process.exit(1);
  }
 `],{cwd:stagedWeb,env,input:JSON.stringify(expectedEnvironment),encoding:'utf8',maxBuffer:1024*1024});
 result.publicDotenvPreflightExitCode=preflight.status;need(preflight.status===0,'public_dotenv_roundtrip_changed');
 const bundle=spawnSync(process.execPath,[path.join(stagedWeb,'node_modules/@opennextjs/cloudflare/dist/cli/index.js'),
  'build','--skipNextBuild'],{cwd:stagedWeb,env,encoding:'utf8',maxBuffer:64*1024*1024});
 fs.writeFileSync(path.join(scratch,'conversion.log'),(bundle.stdout??'')+(bundle.stderr??''),{mode:0o600});
 result.adapterExitCode=bundle.status;need(bundle.status===0,'isolated_adapter_failed');
 const fix=spawnSync(process.execPath,[path.join(stagedWeb,'scripts/fix-route-group-manifests.mjs'),'--open-next'],
  {cwd:stagedWeb,env,encoding:'utf8'});
 result.manifestRepairExitCode=fix.status;need(fix.status===0,'isolated_manifest_repair_failed');
 need(JSON.stringify(validateProductionBuild(web))===JSON.stringify(before),'source_or_next_artifact_changed_during_conversion');
 // Verify what OpenNext actually serialized, including the other two modes.
 const serialized=spawnSync(process.execPath,['--input-type=module','-e',`
  import fs from 'node:fs';
  import {publicArtifactEnvironment} from './scripts/artifact-public-environment.mjs';
  import * as serialized from './.open-next/cloudflare/next-env.mjs';
  const expected=JSON.parse(fs.readFileSync(0,'utf8'));
  for(const mode of ['production','development','test']) {
   const actual=publicArtifactEnvironment(serialized[mode]);
   if(JSON.stringify(actual)!==JSON.stringify(serialized[mode])||JSON.stringify(actual)!==JSON.stringify(expected[mode]))process.exit(1);
  }
 `],{cwd:stagedWeb,env,input:JSON.stringify(expectedEnvironment),encoding:'utf8',maxBuffer:1024*1024});
 result.serializedPublicEnvironmentExitCode=serialized.status;need(serialized.status===0,'serialized_public_environment_changed');
 const stagedAfter=snapshotInstalledArtifactInputs(stagedWeb);
 need(stagedAfter.sha256===installed.sha256&&stagedAfter.sourceBindingSha256===result.installedInputs.stagedBindingSha256,'staged_installed_inputs_changed_during_conversion');
 const installedAfter=snapshotInstalledArtifactInputs(web);
 need(installedAfter.sha256===installed.sha256&&installedAfter.sourceBindingSha256===installed.sourceBindingSha256,'installed_inputs_changed_during_conversion');
 result.installedInputs.afterConversionVerified=true;
 const target=path.join(web,'.open-next');
 if(fs.existsSync(target))fs.renameSync(target,path.join(web,'tmp','prior-opennext-'+id));
 fs.renameSync(path.join(stagedWeb,'.open-next'),target);
 result.passed=true;result.after=validateProductionBuild(web);
}catch(error){result.failure=/^(?:artifact_installed_input_|[a-z]+_)[a-z0-9_]+$/.test(error.message)?error.message:'isolated_conversion_failed';process.exitCode=1;}
finally{
 fs.mkdirSync(path.join(web,'tmp'),{recursive:true});
 fs.writeFileSync(path.join(web,'tmp','opennext-public-environment-build.json'),JSON.stringify(result,null,2)+'\n');
 console.log(JSON.stringify({passed:result.passed,adapterExitCode:result.adapterExitCode??null,
  failure:result.failure??null,report:'tmp/opennext-public-environment-build.json'}));
}
