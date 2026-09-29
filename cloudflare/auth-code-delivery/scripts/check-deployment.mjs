#!/usr/bin/env node
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {configuration} from '../src/policy.mjs';
export function checkDeployment(c,{ready=false,now=Date.now()}={}) {
  const errors=[],check=(ok,message)=>{if(!ok)errors.push(message);};
  check(c?.name==='africlub-auth-code-delivery-staging'&&c.main==='src/worker.mjs','wrong private delivery Worker');
  check(c?.workers_dev===false&&c.preview_urls===false&&c.routes?.length===0,'delivery RPC must have no public ingress');
  const forbidden=['route','assets','env','dispatch_namespaces','durable_objects','access','kv_namespaces','r2_buckets','queues','tail_consumers','unsafe','ratelimits'];
  check(forbidden.every(k=>!Object.hasOwn(c??{},k)),'unexpected router, override or capability');
  check(c?.services?.length===0&&c?.triggers?.crons?.length===0,'unexpected service or automatic job');
  check(c?.observability?.enabled===false,'raw invocation logging must remain disabled');
  const variables=['DELIVERY_ENABLED','WA_GRAPH_VERSION','DELIVERY_ROUTES_JSON'];
  check(c?.vars&&Object.keys(c.vars).length===variables.length&&variables.every(k=>Object.hasOwn(c.vars,k)),
    'unexpected variables or plaintext secrets');
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
