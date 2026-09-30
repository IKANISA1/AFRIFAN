import {readFileSync} from 'node:fs';import {fileURLToPath} from 'node:url';
export function validate(config){
 const errors=[],check=(x,code)=>{if(!x)errors.push(code);},vars=config.vars??{};
 check(Object.keys(config).every(key=>['compatibility_date','name','main','workers_dev','preview_urls','routes','observability','logpush','vars','d1_databases'].includes(key)),'unknown_configuration_field');
 check(Object.keys(vars).every(key=>['PRIVATE_METRICS_STORE_ENABLED','PRIVATE_METRICS_ENVIRONMENT','PRIVATE_METRICS_RETENTION_MS','PRIVATE_METRICS_POLICY_REF'].includes(key)),'unknown_configuration_var');
 check(config.main==='worker.mjs','entrypoint');check(config.workers_dev===false&&config.preview_urls===false&&Array.isArray(config.routes)&&config.routes.length===0,'public_route');
 check(config.observability?.enabled===false&&config.logpush===false,'implicit_logging');
 check(config.d1_databases?.length===1&&config.d1_databases[0].binding==='METRICS_DB'&&config.d1_databases[0].migrations_dir==='migrations','database_binding');
 check(vars.PRIVATE_METRICS_STORE_ENABLED==='false'&&vars.PRIVATE_METRICS_ENVIRONMENT==='isolated-staging'&&vars.PRIVATE_METRICS_RETENTION_MS===''&&vars.PRIVATE_METRICS_POLICY_REF==='','enabled_or_unreviewed_retention');
 return errors;
}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 const errors=validate(JSON.parse(readFileSync(new URL('../wrangler.staging.jsonc',import.meta.url),'utf8')));console.log(JSON.stringify({templatesOnly:true,productionReady:false,errors}));process.exitCode=errors.length?1:0;
}
