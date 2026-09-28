#!/usr/bin/env node
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {configuration} from '../src/policy.mjs';
export function checkDeployment(c,{ready=false,now=Date.now()}={}) {
  const errors=[],check=(ok,message)=>{if(!ok)errors.push(message);};
  check(c?.name==='africlub-auth-code-delivery-staging'&&c.main==='src/worker.mjs','wrong private delivery Worker');
  check(c?.workers_dev===false&&c.preview_urls===false&&c.routes?.length===0,'delivery RPC must have no public ingress');
  check(!c?.assets&&!c?.env&&!c?.dispatch_namespaces&&!c?.durable_objects&&!c?.access,'unexpected router or override');
  check(c?.services?.length===0&&c?.triggers?.crons?.length===0,'unexpected service or automatic job');
  check(c?.observability?.enabled===false,'raw invocation logging must remain disabled');
  check(!c?.vars?.WA_ACCESS_TOKEN&&!c?.vars?.DISPATCH_HMAC_KEY,'do not place credentials in plaintext variables');
  const d=c?.d1_databases?.[0];
  check(c?.d1_databases?.length===1&&d?.binding==='DELIVERY_DB'&&d.database_name==='africlub-auth-delivery-staging'&&d.migrations_dir==='migrations','isolated dispatch database required');
  if(ready){
    check(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(d?.database_id??'')&&d.database_id!=='00000000-0000-0000-0000-000000000000','actual isolated database required');
    try{configuration({...c.vars,DELIVERY_DB:{prepare(){}},WA_ACCESS_TOKEN:'configuration-only-placeholder-not-a-credential',DISPATCH_HMAC_KEY:'a1'.repeat(32)},now);}catch{errors.push('invalid reviewed routes, version or enablement');}
  }else{
    check(c?.vars?.DELIVERY_ENABLED==='false'&&c.vars.WA_GRAPH_VERSION===''&&c.vars.DELIVERY_ROUTES_JSON==='[]','template must remain disabled and unconfigured');
    check(d?.database_id==='00000000-0000-0000-0000-000000000000','template must not select live database');
  }
  return {configurationPassed:errors.length===0,errors,liveProviderVerified:false,senderOwnershipVerified:false,copyCodeTemplateReviewed:false,
    consentVerified:false,actualCloudflareRuntimeVerified:false,releaseAuthorized:false,deploymentPerformed:false};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 try{const args=process.argv.slice(2),file=args.find(x=>!x.startsWith('--'))||new URL('../wrangler.staging.jsonc',import.meta.url);
  const result=checkDeployment(JSON.parse(readFileSync(file,'utf8')),{ready:args.includes('--ready')});console.log(JSON.stringify(result,null,2));if(!result.configurationPassed)process.exitCode=1;
 }catch{console.error('Invalid configuration input');process.exitCode=1;}
}
