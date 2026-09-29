import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {uuid,demand} from '../src/policy.mjs';
export function checkDeployment(config,{ready=false}={}) {
  demand(config&&config.main==='src/worker.mjs','unexpected_entrypoint');
  demand(config.workers_dev===false&&config.preview_urls===false,'public_ingress_forbidden');
  for(const key of ['route','routes','assets','services','triggers','env','durable_objects','r2_buckets','queues'])
    demand(!Object.hasOwn(config,key),'unexpected_deployment_binding');
  demand(config.observability?.enabled===false,'logging_not_approved');
  const db=config.d1_databases; demand(Array.isArray(db)&&db.length===1&&db[0].binding==='ALLOCATION_DB','isolated_database_required');
  demand(db[0].database_name==='africlub-payment-allocation-staging'&&db[0].migrations_dir==='migrations','isolated_database_required');
  const vars=config.vars; demand(vars&&vars.ALLOCATION_ENVIRONMENT==='isolated-staging','staging_only');
  const keys=['PAYMENT_ALLOCATION_ENABLED','ALLOCATION_ENVIRONMENT','INGEST_PRINCIPAL_ID','ALLOCATE_PRINCIPAL_ID','READ_PRINCIPAL_ID','OUTBOX_PRINCIPAL_ID'];
  demand(Object.keys(vars).length===keys.length&&keys.every(k=>Object.hasOwn(vars,k)),'unexpected_variable');
  demand(vars.PAYMENT_ALLOCATION_ENABLED===(ready?'true':'false'),'unexpected_enablement');
  const ids=keys.slice(2).map(k=>vars[k]);
  if(ready){
    demand(/^[0-9a-f]{32}$/.test(config.account_id??''),'account_required');
    demand(uuid(db[0].database_id),'database_id_required');
    demand(ids.every(uuid)&&new Set(ids).size===4,'distinct_principals_required');
  }else demand(ids.every(x=>x===''),'disabled_template_only');
  return {configurationValid:true,enabled:ready,stagingOnly:true,liveDatabaseVerified:false,sourceReconciled:false,
    historicalDeduplicationVerified:false,callerBindingsVerified:false,productionReleaseAuthorized:false};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
  try{const args=process.argv.slice(2);demand(args.filter(x=>x==='--ready').length<=1);
    const paths=args.filter(x=>x!=='--ready');demand(paths.length<=1);
    const target=paths[0]??new URL('../wrangler.staging.jsonc',import.meta.url);
    console.log(JSON.stringify(checkDeployment(JSON.parse(readFileSync(target,'utf8')),{ready:args.includes('--ready')}),null,2));
  }catch(error){console.error(error.code??'invalid_configuration');process.exitCode=1;}
}
