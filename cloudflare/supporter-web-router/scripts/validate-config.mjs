import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
function exact(value,keys){return value&&typeof value==='object'&&!Array.isArray(value)&&Object.keys(value).length===keys.length&&keys.every(k=>Object.hasOwn(value,k));}
export function validateRouterTemplate(config){
 const allowed=['name','main','compatibility_date','account_id','workers_dev','preview_urls','routes','observability','services','vars'];
 if(!config||Object.keys(config).some(k=>!allowed.includes(k))||config.account_id!==''||
  !exact(config.vars,['WEB_ROUTER_ENABLED','WEB_ORIGIN'])||!exact(config.observability,['enabled']))throw Error('unreviewed_router_authority');

 if(!config||config.main!=='src/index.mjs'||config.workers_dev!==false||config.preview_urls!==false||
  !Array.isArray(config.routes)||config.routes.length||config.observability?.enabled!==false||config.vars?.WEB_ROUTER_ENABLED!=='false'||config.vars.WEB_ORIGIN!==''||
  !Array.isArray(config.services)||config.services.length!==2)throw Error('invalid_disabled_router_template');
 for(const service of config.services){
  if(!exact(service,['binding','service'])||typeof service.service!=='string'||!/^[A-Za-z0-9_-]+$/.test(service.service))throw Error('unreviewed_service_authority');
 }
 const names=config.services.map(x=>x.binding).sort();
 if(JSON.stringify(names)!==JSON.stringify(['BROWSER_API','NEXT_APP']))throw Error('invalid_bindings');
 for(const key of ['d1_databases','r2_buckets','kv_namespaces','queues','triggers','durable_objects'])if(config[key])throw Error('excess_capability');
 return {templateValid:true,enabled:false,runtimeReady:false,requiredSecretsVerified:false,deploymentAuthorized:false};
}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 const path=process.argv[2]??new URL('../wrangler.staging.jsonc',import.meta.url);
 try{console.log(JSON.stringify(validateRouterTemplate(JSON.parse(readFileSync(path,'utf8')))));}catch{console.error('invalid_router_template');process.exitCode=1;}
}
