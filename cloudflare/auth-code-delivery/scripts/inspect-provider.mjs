#!/usr/bin/env node
// Optional read-only provider check. Never sends a code, provisions a template or changes a role.
import {pathToFileURL} from 'node:url';
import {configuration} from '../src/policy.mjs';
import {inspectTemplate,withDeadline} from '../src/graph.mjs';
export async function inspectProvider(env,{execute=false,fetcher=(...a)=>fetch(...a),clock=()=>Date.now()}={}) {
 const config=configuration({...env,DELIVERY_DB:env.DELIVERY_DB??{prepare(){}}},clock());
 if(!execute)return {dryRun:true,requests:config.routes.map(r=>({method:'GET',templateId:r.templateId,clubId:r.clubId})),messagesSent:0,providerVerified:false};
 const checks=[];
 for(const route of config.routes){
   const metadata=await withDeadline(signal=>inspectTemplate(fetcher,config,route,env.WA_ACCESS_TOKEN,signal));
   checks.push({clubId:route.clubId,...metadata});
 }
 return {dryRun:false,checks,messagesSent:0,templateMetadataVerified:true,senderOwnershipVerified:false,copyCodeButtonReviewed:false,releaseAuthorized:false};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 try{const args=process.argv.slice(2);if(args.some(x=>x!=='--execute'))throw new Error();
  console.log(JSON.stringify(await inspectProvider(process.env,{execute:args.includes('--execute')}),null,2));
 }catch{console.error('Provider inspection failed; no diagnostic provider body or credential is emitted.');process.exitCode=1;}
}
