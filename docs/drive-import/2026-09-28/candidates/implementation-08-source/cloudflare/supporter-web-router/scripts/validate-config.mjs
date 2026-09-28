import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
export function validateRouterTemplate(config){
 if(!config||config.main!=='src/index.mjs'||config.workers_dev!==false||config.preview_urls!==false||
  !Array.isArray(config.routes)||config.routes.length||config.observability?.enabled!==false||config.vars?.WEB_ROUTER_ENABLED!=='false'||config.vars.WEB_ORIGIN!==''||
  !Array.isArray(config.services)||config.services.length!==2)throw Error('invalid_disabled_router_template');
 const names=config.services.map(x=>x.binding).sort();
 if(JSON.stringify(names)!==JSON.stringify(['BROWSER_API','NEXT_APP']))throw Error('invalid_bindings');
 for(const key of ['d1_databases','r2_buckets','kv_namespaces','queues','triggers','durable_objects'])if(config[key])throw Error('excess_capability');
 return {templateValid:true,enabled:false,deploymentAuthorized:false};
}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 const path=process.argv[2]??new URL('../wrangler.staging.jsonc',import.meta.url);
 try{console.log(JSON.stringify(validateRouterTemplate(JSON.parse(readFileSync(path,'utf8')))));}catch{console.error('invalid_router_template');process.exitCode=1;}
}
