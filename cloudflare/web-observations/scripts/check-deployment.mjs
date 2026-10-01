import {readFileSync} from 'node:fs';import {fileURLToPath} from 'node:url';
export function validate(config){
 const errors=[],check=(x,code)=>{if(!x)errors.push(code);},vars=config.vars??{};
 check(Object.keys(config).every(k=>['name','main','compatibility_date','workers_dev','preview_urls',
  'routes','triggers','observability','logpush','vars','d1_databases'].includes(k)),'unknown_configuration_field');
 check(config.main==='worker.mjs','entrypoint');
 check(config.workers_dev===false&&config.preview_urls===false&&Array.isArray(config.routes)&&!config.routes.length,'public_route');
 check(config.observability?.enabled===false&&config.logpush===false,'implicit_logging');
 check(Object.keys(config.triggers??{}).length===1&&Array.isArray(config.triggers.crons)&&
  config.triggers.crons.length===1&&config.triggers.crons[0]==='* * * * *','retention_schedule');
 check(Object.keys(vars).length===6&&vars.WEB_OBSERVATIONS_STORE_ENABLED==='false'&&
  vars.WEB_OBSERVATIONS_ENVIRONMENT==='isolated-staging'&&
  ['ORIGIN','CLUB_ID','RETENTION_MS','POLICY_REF'].every(k=>vars['WEB_OBSERVATIONS_'+k]===''),'unreviewed_configuration');
 check(config.d1_databases?.length===1&&config.d1_databases[0].binding==='WEB_OBSERVATIONS_DB'&&
  config.d1_databases[0].migrations_dir==='migrations','database_binding');
 return errors;
}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 const errors=validate(JSON.parse(readFileSync(new URL('../wrangler.staging.jsonc',import.meta.url),'utf8')));
 console.log(JSON.stringify({templatesOnly:true,productionReady:false,errors}));process.exitCode=errors.length?1:0;
}
