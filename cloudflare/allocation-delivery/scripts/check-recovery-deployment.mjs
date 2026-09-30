import {readFileSync} from 'node:fs';import {fileURLToPath} from 'node:url';
const uuid=x=>typeof x==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(x);
export function validateRecovery(config,{ready=false}={}){
 const errors=[],check=(x,code)=>{if(!x)errors.push(code);};const vars=config.vars??{};
 check(Object.keys(config).every(key=>['compatibility_date','name','main','workers_dev','preview_urls','routes','observability','logpush','vars','d1_databases'].includes(key)),'unknown_configuration_field');
 check(Object.keys(vars).every(key=>['PAYMENT_ALLOCATION_ENABLED','ALLOCATION_DELIVERY_ENABLED','ALLOCATION_RECOVERY_ENABLED','ALLOCATION_ENVIRONMENT','DELIVERY_CONSUMER_ID',
  'RECOVERY_MAKER_PRINCIPAL_ID','RECOVERY_CHECKER_PRINCIPAL_ID','PRIVATE_METRICS_ENABLED','PRIVATE_METRICS_RETENTION_MS','PRIVATE_METRICS_POLICY_REF'].includes(key)),'unknown_configuration_var');
 check(config.main==='src/recovery-worker.mjs','entrypoint');check(config.workers_dev===false&&config.preview_urls===false&&Array.isArray(config.routes)&&config.routes.length===0&&!config.triggers,'public_route_or_schedule');
 check(config.observability?.enabled===false&&config.logpush===false,'implicit_logging');
 for(const key of ['services','queues','r2_buckets','kv_namespaces','durable_objects','send_email'])check(!config[key],`unexpected_${key}`);
 check(config.d1_databases?.length===1&&config.d1_databases[0].binding==='ALLOCATION_DB'&&config.d1_databases[0].migrations_dir==='migrations_source','database_binding');
 check(vars.ALLOCATION_ENVIRONMENT==='isolated-staging','environment');
 const expected=ready?'true':'false';for(const key of ['PAYMENT_ALLOCATION_ENABLED','ALLOCATION_DELIVERY_ENABLED','ALLOCATION_RECOVERY_ENABLED'])check(vars[key]===expected,`${key}_flag`);
 check(vars.PRIVATE_METRICS_ENABLED==='false'&&vars.PRIVATE_METRICS_RETENTION_MS===''&&vars.PRIVATE_METRICS_POLICY_REF==='','unreviewed_metrics_configuration');
 if(ready){check(uuid(config.d1_databases?.[0]?.database_id),'database_id');check(uuid(vars.DELIVERY_CONSUMER_ID),'consumer_id');
  check(uuid(vars.RECOVERY_MAKER_PRINCIPAL_ID)&&uuid(vars.RECOVERY_CHECKER_PRINCIPAL_ID)&&vars.RECOVERY_MAKER_PRINCIPAL_ID!==vars.RECOVERY_CHECKER_PRINCIPAL_ID,'reviewer_separation');}
 return errors;
}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 const ready=process.argv.includes('--ready'),config=JSON.parse(readFileSync(new URL('../wrangler.recovery.staging.jsonc',import.meta.url),'utf8'));
 const errors=validateRecovery(config,{ready});console.log(JSON.stringify({configurationOnly:true,productionReady:false,ready,errors}));process.exitCode=errors.length?1:0;
}
