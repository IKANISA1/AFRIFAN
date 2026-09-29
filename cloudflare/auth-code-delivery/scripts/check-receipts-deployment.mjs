#!/usr/bin/env node
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {receiptRoutes} from '../src/receipts-policy.mjs';
import {configuration} from '../src/policy.mjs';
const zero='00000000-0000-0000-0000-000000000000';
const expected=[['africlub-auth-delivery-receipts-staging','src/receipts-webhook-worker.mjs'],
 ['africlub-auth-code-delivery-tracked-staging','src/status-aware-worker.mjs'],
 ['africlub-auth-delivery-receipts-reader-staging','src/receipt-reader-worker.mjs']];
const variableKeys=[['RECEIPT_WEBHOOK_ENABLED','RECEIPT_RECONCILE_ENABLED','RECEIPT_ORIGIN','RECEIPT_ROUTES_JSON','RECEIPT_KEY_VERSION'],
 ['DELIVERY_ENABLED','WA_GRAPH_VERSION','DELIVERY_ROUTES_JSON','RECEIPT_BINDING_ENABLED','RECEIPT_ROUTES_JSON','RECEIPT_KEY_VERSION'],
 ['RECEIPT_READ_ENABLED','RECEIPT_ROUTES_JSON','RECEIPT_KEY_VERSION']];
const forbidden=['route','assets','env','access','dispatch_namespaces','durable_objects','kv_namespaces','r2_buckets','queues','tail_consumers','unsafe'];
export function checkReceiptsDeployment(configs,{ready=false,now=Date.now()}={}){
 const errors=[],check=(v,m)=>{if(!v)errors.push(m);};
 if(!Array.isArray(configs)||configs.length!==3)return {configurationPassed:false,errors:['three configurations required'],deploymentPerformed:false,releaseAuthorized:false};
 let referenceDb,referenceRoutes;
 configs.forEach((c,i)=>{
  check(c?.name===expected[i][0]&&c?.main===expected[i][1],`worker ${i}: wrong entrypoint`);
  check(c?.workers_dev===false&&c?.preview_urls===false,`worker ${i}: preview ingress forbidden`);
  check(forbidden.every(k=>!Object.hasOwn(c??{},k)),`worker ${i}: router/override/storage not allowed`);
  check(Array.isArray(c?.services)&&c.services.length===0,`worker ${i}: outbound service bindings forbidden`);
  check(c?.observability?.enabled===false,`worker ${i}: invocation logging must be disabled`);
  check(c?.vars&&Object.keys(c.vars).length===variableKeys[i].length&&variableKeys[i].every(k=>Object.hasOwn(c.vars,k)),`worker ${i}: unexpected variables or plaintext secrets`);
  check(c?.vars?.RECEIPT_KEY_VERSION==='1',`worker ${i}: key version must be 1`);
  const d=c?.d1_databases?.[0];
  check(c?.d1_databases?.length===1&&d?.binding==='DELIVERY_DB'&&d.database_name==='africlub-auth-delivery-staging'&&d.migrations_dir==='migrations',`worker ${i}: isolated dispatch database required`);
  if(i===0)referenceDb=d?.database_id;else check(referenceDb===d?.database_id,`worker ${i}: database mismatch`);
  const crons=c?.triggers?.crons;
  check(Array.isArray(crons),`worker ${i}: explicit schedule required`);
  if(i!==0||!ready)check(crons?.length===0,`worker ${i}: unexpected schedule`);
  if(i!==0||!ready)check(Array.isArray(c?.routes)&&c.routes.length===0,`worker ${i}: public ingress forbidden`);
  if(i!==0)check(!Object.hasOwn(c??{},'ratelimits'),`worker ${i}: unexpected rate binding`);
  if(i===0){const r=c?.ratelimits?.[0];check(c?.ratelimits?.length===1&&r.name==='RECEIPT_EDGE_LIMIT'&&r.simple?.period===60&&Number.isInteger(r.simple?.limit)&&r.simple.limit>0&&r.simple.limit<=600,`webhook: required isolated limiter`);
   check(ready?/^[1-9][0-9]*$/.test(r?.namespace_id??''):r?.namespace_id==='0','webhook: rate namespace configuration');}
  if(!ready){check(d?.database_id===zero,`worker ${i}: template has actual database`);
   check(c?.vars?.RECEIPT_ROUTES_JSON==='[]',`worker ${i}: template has configured routes`);
   if(i===0)check(c?.vars?.RECEIPT_WEBHOOK_ENABLED==='false'&&c.vars.RECEIPT_RECONCILE_ENABLED==='false'&&c.vars.RECEIPT_ORIGIN==='','webhook template must be disabled');
   if(i===1)check(c?.vars?.DELIVERY_ENABLED==='false'&&c.vars.RECEIPT_BINDING_ENABLED==='false'&&c.vars.WA_GRAPH_VERSION===''&&c.vars.DELIVERY_ROUTES_JSON==='[]','sender template must be disabled');
   if(i===2)check(c?.vars?.RECEIPT_READ_ENABLED==='false','reader template must be disabled');
  }else{
   check(typeof d?.database_id==='string'&&/^[0-9a-f-]{36}$/.test(d.database_id)&&d.database_id!==zero,`worker ${i}: actual database ID required`);
   let routes;try{routes=receiptRoutes(c.vars).sort((a,b)=>a.clubId-b.clubId);}catch{errors.push(`worker ${i}: invalid receipt routes`);}
   if(i===0)referenceRoutes=JSON.stringify(routes);else check(JSON.stringify(routes)===referenceRoutes,`worker ${i}: receipt route mismatch`);
   if(i===0){try{const u=new URL(c.vars.RECEIPT_ORIGIN);check(u.origin===c.vars.RECEIPT_ORIGIN&&u.protocol==='https:'&&!u.username&&!u.password,'webhook origin invalid');
    check(c.routes?.length===1&&c.routes[0]?.custom_domain===true&&c.routes[0]?.pattern===u.hostname,'webhook must have exact custom-domain ingress');}catch{errors.push('webhook origin invalid');}
    check(c?.vars?.RECEIPT_WEBHOOK_ENABLED==='true'&&c.vars.RECEIPT_RECONCILE_ENABLED==='true'&&crons?.length===1&&crons[0]==='* * * * *','webhook readiness requires intake and bounded reconciliation');
   }
   if(i===1){check(c?.vars?.RECEIPT_BINDING_ENABLED==='true','sender requires receipt binding');
    try{const delivery=configuration({...c.vars,DELIVERY_DB:{prepare(){}},WA_ACCESS_TOKEN:'configuration-validation-placeholder-only',DISPATCH_HMAC_KEY:'a1'.repeat(32)},now);
     check(delivery.routes.length===routes?.length&&delivery.routes.every(d=>routes?.some(r=>r.clubId===d.clubId&&r.phoneNumberId===d.phoneNumberId)),'sender and receipt mappings disagree');
    }catch{errors.push('invalid sender version/template/review configuration');}}
   if(i===2)check(c?.vars?.RECEIPT_READ_ENABLED==='true','reader must be explicitly enabled for ready check');
  }
 });
 return {configurationPassed:errors.length===0,errors,liveSignatureVerified:false,providerSubscriptionVerified:false,
  secretsProvisioned:false,privateCallerAuthorizationVerified:false,actualCloudflareRuntimeVerified:false,
  retentionApproved:false,releaseAuthorized:false,deploymentPerformed:false};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 try{const args=process.argv.slice(2),paths=args.filter(a=>!a.startsWith('--'));if(paths.length!==0&&paths.length!==3)throw Error();
  const defaults=['wrangler.receipts-webhook.staging.jsonc','wrangler.status-aware.staging.jsonc','wrangler.receipt-reader.staging.jsonc'];
  const configs=(paths.length?paths:defaults.map(p=>new URL('../'+p,import.meta.url))).map(p=>JSON.parse(readFileSync(p,'utf8')));
  const r=checkReceiptsDeployment(configs,{ready:args.includes('--ready')});console.log(JSON.stringify(r,null,2));if(!r.configurationPassed)process.exitCode=1;
 }catch{console.error('Invalid receipt configuration input');process.exitCode=1;}
}
