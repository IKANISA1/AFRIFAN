import {readFileSync} from 'node:fs';import {pathToFileURL} from 'node:url';
import {checkDeployment} from './check-deployment.mjs';import {UUID} from '../src/policy.mjs';
const expected=[['HANDOFF_RESERVER','MembershipHandoffReserve'],['HANDOFF_RECOVERY','MembershipHandoffRecovery']];
function must(v,label){if(!v)throw Error(`handoff_configuration_rejected:${label}`);}
function exact(o,k){must(o&&typeof o==='object'&&!Array.isArray(o)&&Object.keys(o).length===k.length&&k.every(x=>Object.hasOwn(o,x)),'fields');}
export function checkHandoffDeployment(g,h,upstreams={},ready=false){
 must(g.name==='africlub-supporter-membership-handoff-staging'&&g.main==='src/handoff-index.mjs'&&g.compatibility_date==='2026-09-27','gateway');
 must(g.vars.SERVER_HANDOFF_API_ENABLED===(ready?'true':'false'),'gateway_enabled');
 must(Array.isArray(g.services)&&g.services.length===6,'service_count');
 for(const [i,[binding,entrypoint]] of expected.entries()){const s=g.services[i+4];exact(s,['binding','service','entrypoint']);must(s.binding===binding&&s.entrypoint===entrypoint&&s.service==='africlub-membership-handoff-staging','handoff_binding');}
 const legacy=structuredClone(g);legacy.name='africlub-supporter-membership-api-staging';legacy.main='src/index.mjs';legacy.compatibility_date='2026-09-26';legacy.services=legacy.services.slice(0,4);delete legacy.vars.SERVER_HANDOFF_API_ENABLED;
 const prior=checkDeployment(legacy,upstreams,ready);
 exact(h,['name','main','compatibility_date','account_id','workers_dev','preview_urls','routes','observability','d1_databases','vars']);
 must(h.name==='africlub-membership-handoff-staging'&&h.main==='src/handoff-worker.mjs'&&h.compatibility_date==='2026-09-27','private_identity');
 must(h.workers_dev===false&&h.preview_urls===false&&Array.isArray(h.routes)&&h.routes.length===0,'private_exposure');
 exact(h.observability,['enabled']);must(h.observability.enabled===false,'private_logging');
 must(Array.isArray(h.d1_databases)&&h.d1_databases.length===1,'database');
 const db=h.d1_databases[0];exact(db,['binding','database_name','database_id','migrations_dir']);must(db.binding==='ALLOCATION_DB'&&db.database_name==='africlub-payment-allocation-staging'&&db.migrations_dir==='migrations','database_binding');
 exact(h.vars,['SERVER_HANDOFF_ENABLED','PAYMENT_ALLOCATION_ENABLED','ALLOCATION_ENVIRONMENT','HANDOFF_RESERVE_PRINCIPAL_ID','HANDOFF_READ_PRINCIPAL_ID']);
 const v=h.vars;must(v.ALLOCATION_ENVIRONMENT==='isolated-staging'&&v.SERVER_HANDOFF_ENABLED===(ready?'true':'false')&&v.PAYMENT_ALLOCATION_ENABLED===(ready?'true':'false'),'private_environment');
 if(!ready)must(h.account_id===''&&db.database_id==='REPLACE_WITH_SHARED_ALLOCATION_STAGING_ID'&&v.HANDOFF_RESERVE_PRINCIPAL_ID===''&&v.HANDOFF_READ_PRINCIPAL_ID==='','disabled_private');
 else{
  must(h.account_id===g.account_id&&db.database_id===upstreams.allocation.d1_databases[0].database_id,'same_allocation_database');
  const p=[v.HANDOFF_RESERVE_PRINCIPAL_ID,v.HANDOFF_READ_PRINCIPAL_ID,upstreams.checkout.vars.CHECKOUT_PRINCIPAL_ID,upstreams.checkout.vars.CHECKOUT_READ_PRINCIPAL_ID,...['INGEST','ALLOCATE','READ','OUTBOX'].map(x=>upstreams.allocation.vars[`${x}_PRINCIPAL_ID`])];
  must(p.every(x=>typeof x==='string'&&UUID.test(x))&&new Set(p).size===8,'principals');
 }
 return {...prior,serverHandoffConfigured:true,legacyAttemptReconciliationVerified:false,exceptionResolutionImplemented:false,nativeServerGuardIntegrated:false,realCarrierVerified:false,productionApproved:false};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){try{
 const args=process.argv.slice(2),ready=args.includes('--ready'),paths=args.filter(x=>x!=='--ready');must(ready?paths.length===5:paths.length===0||paths.length===2,'arguments');
 const read=p=>JSON.parse(readFileSync(p,'utf8'));
 const g=read(paths[0]??new URL('../wrangler.handoff.staging.jsonc',import.meta.url));
 const h=read(paths[1]??new URL('../../payment-allocation/wrangler.handoff.staging.jsonc',import.meta.url));
 const up=ready?{identity:read(paths[2]),checkout:read(paths[3]),allocation:read(paths[4])}:{};
 console.log(JSON.stringify(checkHandoffDeployment(g,h,up,ready),null,2));
 }catch(e){console.error(String(e.message).startsWith('handoff_configuration_rejected:')||String(e.message).startsWith('configuration_rejected:')?e.message:'handoff_configuration_rejected:unreadable');process.exitCode=1;}}
