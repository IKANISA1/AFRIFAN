import {readFileSync} from 'node:fs';import {pathToFileURL} from 'node:url';
import {checkDeployment} from './check-deployment.mjs';
import {uuid} from '../src/policy.mjs';
import {requireCheckout as need} from '../src/checkout-policy.mjs';
export function checkCheckoutDeployment(c,allocation,{ready=false}={}){
 checkDeployment(allocation,{ready});
 need(c?.main==='src/checkout-worker.mjs','unexpected_entrypoint');
 need(c.workers_dev===false&&c.preview_urls===false&&c.observability?.enabled===false,'private_only');
 for(const k of ['route','routes','assets','services','triggers','env','durable_objects','r2_buckets','queues'])need(!Object.hasOwn(c,k),'unexpected_binding');
 need(Array.isArray(c.d1_databases)&&c.d1_databases.length===1,'shared_allocation_database_required');
 const d=c.d1_databases[0];need(d.binding==='ALLOCATION_DB'&&d.database_name==='africlub-payment-allocation-staging'&&d.migrations_dir==='migrations','shared_allocation_database_required');
 const v=c.vars,keys=['MEMBERSHIP_CHECKOUT_ENABLED','PAYMENT_ALLOCATION_ENABLED','ALLOCATION_ENVIRONMENT','CHECKOUT_PRINCIPAL_ID','CHECKOUT_READ_PRINCIPAL_ID'];
 need(v&&Object.keys(v).length===keys.length&&keys.every(k=>Object.hasOwn(v,k)),'unexpected_variable');
 need(v.ALLOCATION_ENVIRONMENT==='isolated-staging','staging_only');
 need(v.MEMBERSHIP_CHECKOUT_ENABLED===(ready?'true':'false')&&v.PAYMENT_ALLOCATION_ENABLED===(ready?'true':'false'),'unexpected_enablement');
 if(ready){
  need(c.account_id===allocation.account_id&&uuid(d.database_id)&&d.database_id===allocation.d1_databases[0].database_id,'shared_allocation_database_required');
  const ids=[v.CHECKOUT_PRINCIPAL_ID,v.CHECKOUT_READ_PRINCIPAL_ID];need(ids.every(uuid)&&new Set(ids).size===2,'distinct_principals_required');
  need(ids.every(id=>![allocation.vars.INGEST_PRINCIPAL_ID,allocation.vars.ALLOCATE_PRINCIPAL_ID,allocation.vars.READ_PRINCIPAL_ID,allocation.vars.OUTBOX_PRINCIPAL_ID].includes(id)),'distinct_principals_required');
 }else need(v.CHECKOUT_PRINCIPAL_ID===''&&v.CHECKOUT_READ_PRINCIPAL_ID==='','disabled_template_only');
 return {configurationValid:true,enabled:ready,stagingOnly:true,liveSharedDatabaseVerified:false,catalogReconciled:false,
  humanAuthenticationVerified:false,callerBindingsVerified:false,productionReleaseAuthorized:false};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){try{
 const a=process.argv.slice(2),ready=a.includes('--ready'),paths=a.filter(x=>x!=='--ready');need(a.filter(x=>x==='--ready').length<=1&&(paths.length===0||paths.length===2),'usage');
 console.log(JSON.stringify(checkCheckoutDeployment(JSON.parse(readFileSync(paths[0]??new URL('../wrangler.checkout.staging.jsonc',import.meta.url))),JSON.parse(readFileSync(paths[1]??new URL('../wrangler.staging.jsonc',import.meta.url))),{ready}),null,2));
 }catch(error){console.error(error.code??'invalid_configuration');process.exitCode=1;}}
