import {readFileSync} from 'node:fs';import {fileURLToPath} from 'node:url';
export function validate(config,kind){
 const errors=[];const check=(x,msg)=>{if(!x)errors.push(msg);};
 check(['source','inbox','dispatch'].includes(kind),'unknown_kind');
 check(config.workers_dev===false&&config.preview_urls===false,'public_preview_enabled');
 check(Array.isArray(config.routes)&&config.routes.length===0&&!config.triggers,'routes_or_schedule_present');
 check(config.main===`src/${kind==='dispatch'?'dispatch':kind}-worker.mjs`,'wrong_entrypoint');
 const vars=config.vars??{};
 const forbidden=['kv_namespaces','r2_buckets','queues','durable_objects','send_email'];
 for(const k of forbidden)check(!config[k],`unexpected_${k}`);
 if(kind==='source'){
  check(vars.PAYMENT_ALLOCATION_ENABLED==='false'&&vars.ALLOCATION_DELIVERY_ENABLED==='false','source_enabled');
  check(vars.ALLOCATION_ENVIRONMENT==='isolated-staging','wrong_environment');
  check(config.d1_databases?.length===1&&config.d1_databases[0].binding==='ALLOCATION_DB','wrong_source_db_binding');
  check(!config.services,'unexpected_source_service');
 }else if(kind==='inbox'){
  check(vars.INBOX_ENABLED==='false'&&vars.DELIVERY_ENVIRONMENT==='isolated-staging','inbox_enabled_or_wrong_environment');
  check(config.d1_databases?.length===1&&config.d1_databases[0].binding==='INBOX_DB','wrong_inbox_db_binding');
  check(!config.services,'unexpected_inbox_service');
 }else if(kind==='dispatch'){
  check(vars.DELIVERY_DISPATCH_ENABLED==='false'&&vars.DELIVERY_ENVIRONMENT==='isolated-staging','dispatch_enabled_or_wrong_environment');
  check(vars.DELIVERY_CLUB_IDS==='[]','configured_clubs_in_template');
  check(!config.d1_databases,'dispatcher_database_capability');
  check(config.services?.length===2,'wrong_binding_count');
  check(config.services?.some(x=>x.binding==='SOURCE'&&x.entrypoint==='AllocationEventSource'),'missing_source_binding');
  check(config.services?.some(x=>x.binding==='INBOX'&&x.entrypoint==='AllocationEventInbox'),'missing_inbox_binding');
 }
 return errors;
}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 const results=['source','inbox','dispatch'].map(kind=>({kind,errors:validate(JSON.parse(readFileSync(new URL(`../wrangler.${kind}.staging.jsonc`,import.meta.url),'utf8')),kind)}));
 console.log(JSON.stringify({templatesOnly:true,deployable:false,results}));process.exit(results.some(x=>x.errors.length)?1:0);
}
