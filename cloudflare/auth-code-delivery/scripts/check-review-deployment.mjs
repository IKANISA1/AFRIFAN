import {readFileSync} from 'node:fs';import {fileURLToPath} from 'node:url';
export function validateReview(config){
 const errors=[],check=(x,code)=>{if(!x)errors.push(code);},vars=config.vars??{};
 check(Object.keys(config).every(key=>['compatibility_date','name','main','workers_dev','preview_urls','routes','observability','logpush','vars','d1_databases'].includes(key)),'unknown_configuration_field');
 check(Object.keys(vars).every(key=>['AUTH_DISPATCH_REVIEW_ENABLED','AUTH_DISPATCH_REVIEW_ENVIRONMENT','AUTH_DISPATCH_REVIEW_CLUB_IDS',
  'PRIVATE_METRICS_ENABLED','PRIVATE_METRICS_RETENTION_MS','PRIVATE_METRICS_POLICY_REF'].includes(key)),'unknown_configuration_var');
 check(config.main==='src/review-worker.mjs','entrypoint');check(config.workers_dev===false&&config.preview_urls===false&&Array.isArray(config.routes)&&config.routes.length===0&&!config.triggers,'public_route_or_schedule');
 check(config.observability?.enabled===false&&config.logpush===false,'implicit_logging');
 for(const key of ['services','queues','r2_buckets','kv_namespaces','durable_objects','send_email'])check(!config[key],`unexpected_${key}`);
 check(config.d1_databases?.length===1&&config.d1_databases[0].binding==='DELIVERY_DB','database_binding');
 check(vars.AUTH_DISPATCH_REVIEW_ENABLED==='false'&&vars.AUTH_DISPATCH_REVIEW_ENVIRONMENT==='isolated-staging'&&vars.AUTH_DISPATCH_REVIEW_CLUB_IDS==='[]','enabled_template');
 check(vars.PRIVATE_METRICS_ENABLED==='false'&&vars.PRIVATE_METRICS_RETENTION_MS===''&&vars.PRIVATE_METRICS_POLICY_REF==='','unreviewed_metrics_configuration');
 for(const key of ['WA_ACCESS_TOKEN','DISPATCH_HMAC_KEY'])check(!Object.hasOwn(vars,key),'provider_credential_in_reader');return errors;
}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 const errors=validateReview(JSON.parse(readFileSync(new URL('../wrangler.review.staging.jsonc',import.meta.url),'utf8')));
 console.log(JSON.stringify({configurationOnly:true,productionReady:false,errors}));process.exitCode=errors.length?1:0;
}
