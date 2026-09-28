#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { requireValue,UUID } from '../src/errors.mjs';
export function checkDeployment(gateway,verifier,{ready=false}={}){
 for(const c of [gateway,verifier]){requireValue(c.workers_dev===false&&c.preview_urls===false,'public_preview_forbidden');
  requireValue(!c.env&&!c.assets&&!c.services&&!c.kv_namespaces&&!c.r2_buckets,'unexpected_runtime_binding');
  requireValue(!c.vars?.AUTH_HMAC_KEY&&!c.vars?.AUTH_ENCRYPTION_KEY&&!c.vars?.WHATSAPP_CLOUD_API_TOKEN,'secrets_must_not_be_configuration');
  requireValue(c.vars?.AUTH_KEY_VERSION==='1');requireValue(Array.isArray(c.d1_databases)&&c.d1_databases.length===1);
  requireValue(c.d1_databases[0].binding==='AUTH_DB'&&c.d1_databases[0].database_name==='africlub-identity-staging','wrong_identity_database');}
 requireValue(gateway.main==='src/index.mjs'&&verifier.main==='src/identity-verifier-worker.mjs','wrong_entrypoint');
 requireValue(verifier.routes?.length===0&&!verifier.triggers&&!verifier.ratelimits,'private_verifier_must_be_private');
 requireValue(gateway.account_id===verifier.account_id&&gateway.d1_databases[0].database_id===verifier.d1_databases[0].database_id,'identity_binding_mismatch');
 const rate=gateway.ratelimits;requireValue(Array.isArray(rate)&&rate.length===1&&rate[0].name==='AUTH_EDGE_LIMIT'&&rate[0].simple?.period===60&&rate[0].simple?.limit===100,'missing_edge_rate_control');
 if(ready){requireValue(/^[a-f0-9]{32}$/.test(gateway.account_id)&&UUID.test(gateway.d1_databases[0].database_id)&&/^[1-9]\d*$/.test(rate[0].namespace_id),'unresolved_account_resources');
  let origin;try{origin=new URL(gateway.vars.AUTH_ORIGIN);}catch{requireValue(false,'unresolved_origin');}
  requireValue(origin.protocol==='https:'&&origin.origin===gateway.vars.AUTH_ORIGIN&&!origin.hostname.endsWith('.invalid')&&!origin.hostname.endsWith('.workers.dev'),'unresolved_origin');
  requireValue(gateway.routes?.length===1&&gateway.routes[0].custom_domain===true&&gateway.routes[0].pattern===origin.hostname,'unprotected_or_wrong_ingress');
  requireValue(gateway.vars.AUTH_SERVICE_ENABLED==='true'&&verifier.vars.AUTH_SERVICE_ENABLED==='true','identity_disabled');
  requireValue(gateway.vars.AUTH_DELIVERY_ENABLED==='true'&&/^v\d+\.0$/.test(gateway.vars.WHATSAPP_GRAPH_API_VERSION)&&/^\d{5,32}$/.test(gateway.vars.WHATSAPP_PHONE_NUMBER_ID),'delivery_unconfigured');
  requireValue(gateway.triggers?.crons?.length===1&&gateway.triggers.crons[0]==='* * * * *','drain_schedule_missing');
 }else{requireValue(gateway.vars.AUTH_SERVICE_ENABLED==='false'&&gateway.vars.AUTH_DELIVERY_ENABLED==='false'&&verifier.vars.AUTH_SERVICE_ENABLED==='false','template_must_be_disabled');requireValue(gateway.routes?.length===0&&!gateway.triggers,'template_routes_or_schedule_enabled');}
 return {configurationPassed:true,mode:ready?'resolved-staging':'disabled-template',liveRuntimeVerified:false,providerDeliveryVerified:false,identityImportApproved:false,
  secretConfigurationVerified:false,releaseAuthorized:false};
}
if(process.argv[1]&&pathToFileURL(resolve(process.argv[1])).href===import.meta.url){try{const args=process.argv.slice(2),ready=args.includes('--ready'),paths=args.filter(x=>x!=='--ready');if(paths.length!==0&&paths.length!==2)throw Error('two configuration paths required');
 const a=JSON.parse(readFileSync(paths[0]??new URL('../wrangler.staging.jsonc',import.meta.url),'utf8')),b=JSON.parse(readFileSync(paths[1]??new URL('../wrangler.verifier.staging.jsonc',import.meta.url),'utf8'));console.log(JSON.stringify(checkDeployment(a,b,{ready})));}catch{console.error('Identity configuration rejected. No deployment performed.');process.exitCode=1;}}
