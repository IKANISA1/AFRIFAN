import {readFileSync} from 'node:fs';import {pathToFileURL} from 'node:url';
import {origin,UUID} from '../src/policy.mjs';
import {publicKeyPolicy} from '../../supporter-auth/src/crypto.mjs';
const expected=[['IDENTITY','africlub-supporter-identity-verifier-staging','SupporterIdentityVerifier'],['CHECKOUT','africlub-membership-checkout-staging','MembershipCheckout'],['CHECKOUT_READER','africlub-membership-checkout-staging','MembershipCheckoutReader'],['PAYMENT_RECEIPTS','africlub-payment-allocation-staging','PaymentReceiptReader']];
function must(v,why){if(!v)throw Error(`configuration_rejected:${why}`);}
function keys(o,ks){must(o&&typeof o==='object'&&!Array.isArray(o)&&Object.keys(o).length===ks.length&&ks.every(k=>Object.hasOwn(o,k)),'fields');}
function closed(c,main){must(c.main===main&&c.workers_dev===false&&c.preview_urls===false&&(!c.routes||c.routes.length===0),'upstream_public_or_main');for(const k of ['env','assets','services','queues','triggers','unsafe','durable_objects','kv_namespaces','r2_buckets'])must(!c[k],'upstream_extra_binding');}
export function checkDeployment(g,upstreams={},ready=false){
 keys(g,['name','main','compatibility_date','account_id','workers_dev','preview_urls','routes','observability','services','ratelimits','vars']);
 must(g.name==='africlub-supporter-membership-api-staging'&&g.main==='src/index.mjs'&&g.compatibility_date==='2026-09-26','gateway_identity');
 must(g.workers_dev===false&&g.preview_urls===false,'public_preview');keys(g.observability,['enabled']);must(g.observability.enabled===false,'logging');
 keys(g.vars,['MEMBERSHIP_API_ENABLED','MEMBERSHIP_ENVIRONMENT','NATIVE_ORIGIN','CLUB_ROUTES_JSON','MEMBERSHIP_HANDOFF_JOURNAL_ENABLED','MEMBERSHIP_HANDOFF_RELEASE_ENABLED']);
 must(['true','false'].includes(g.vars.MEMBERSHIP_HANDOFF_RELEASE_ENABLED) && (ready||g.vars.MEMBERSHIP_HANDOFF_RELEASE_ENABLED==='false'),'release_enablement');
 must(g.vars.MEMBERSHIP_HANDOFF_RELEASE_ENABLED!=='true'||g.vars.MEMBERSHIP_HANDOFF_JOURNAL_ENABLED==='true','release_requires_journal');
 must(g.vars.MEMBERSHIP_ENVIRONMENT==='isolated-staging','environment');must(['true','false'].includes(g.vars.MEMBERSHIP_HANDOFF_JOURNAL_ENABLED)&& (ready||g.vars.MEMBERSHIP_HANDOFF_JOURNAL_ENABLED==='false'),'journal_enablement');must(Array.isArray(g.services)&&g.services.length===4,'service_count');
 for(const [i,e] of expected.entries()){const s=g.services[i];keys(s,['binding','service','entrypoint']);must(s.binding===e[0]&&s.service===e[1]&&s.entrypoint===e[2],'service_boundary');}
 must(Array.isArray(g.ratelimits)&&g.ratelimits.length===2,'rate_count');const namespaces=[];
 for(const [i,r] of g.ratelimits.entries()){keys(r,['name','namespace_id','simple']);keys(r.simple,['limit','period']);must(r.name===(i?'SUBJECT_LIMIT':'EDGE_LIMIT')&&r.simple.limit===(i?60:120)&&r.simple.period===60,'rate_policy');
  must(typeof r.namespace_id==='string','rate_namespace');if(ready)must(/^[1-9][0-9]{0,15}$/.test(r.namespace_id),'rate_namespace');namespaces.push(r.namespace_id);}
 must(namespaces[0]!==namespaces[1],'shared_rate_namespace');
 if(!ready){must(g.vars.MEMBERSHIP_API_ENABLED==='false'&&g.account_id===''&&g.vars.NATIVE_ORIGIN===''&&g.vars.CLUB_ROUTES_JSON==='[]'&&Array.isArray(g.routes)&&g.routes.length===0,'disabled_template');}
 else {
  must(g.vars.MEMBERSHIP_API_ENABLED==='true'&&/^[0-9a-f]{32}$/.test(g.account_id),'account_or_enablement');
  must(origin(g.vars.NATIVE_ORIGIN),'origin');const u=new URL(g.vars.NATIVE_ORIGIN);must(!u.port&&!/\.(invalid|example)$/.test(u.hostname),'origin_placeholder');
  must(Array.isArray(g.routes)&&g.routes.length===1,'route_count');keys(g.routes[0],['pattern','custom_domain']);must(g.routes[0].pattern===u.hostname&&g.routes[0].custom_domain===true,'custom_domain');
  const clubs=JSON.parse(g.vars.CLUB_ROUTES_JSON);must(Array.isArray(clubs)&&clubs.length>0&&clubs.length<=5,'clubs');const ids=new Set(),slugs=new Set();for(const c of clubs){keys(c,['clubId','clubSlug']);must(Number.isSafeInteger(c.clubId)&&c.clubId>0&&typeof c.clubSlug==='string'&&/^[a-z][a-z0-9_-]{1,63}$/.test(c.clubSlug)&&!ids.has(c.clubId)&&!slugs.has(c.clubSlug),'clubs');ids.add(c.clubId);slugs.add(c.clubSlug);}
  keys(upstreams,['identity','checkout','allocation']);const {identity:i,checkout:c,allocation:a}=upstreams;
  for(const x of [i,c,a])must(x.account_id===g.account_id,'account_mismatch');closed(i,'src/identity-verifier-worker.mjs');closed(c,'src/checkout-worker.mjs');closed(a,'src/worker.mjs');
  must(i.name===expected[0][1]&&c.name===expected[1][1]&&a.name===expected[3][1],'upstream_identity');
  must(i.vars.AUTH_SERVICE_ENABLED==='true','identity_enabled');
  for(const field of ['AUTH_KEYRING_JSON','AUTH_HMAC_KEY','AUTH_ENCRYPTION_KEY'])must(!Object.hasOwn(i.vars,field),'identity_secret_in_public_config');
  try{publicKeyPolicy(i.vars);}catch{must(false,'identity_key_policy');}
  must(c.vars.MEMBERSHIP_CHECKOUT_ENABLED==='true'&&c.vars.PAYMENT_ALLOCATION_ENABLED==='true'&&c.vars.ALLOCATION_ENVIRONMENT==='isolated-staging'&&a.vars.PAYMENT_ALLOCATION_ENABLED==='true'&&a.vars.ALLOCATION_ENVIRONMENT==='isolated-staging','allocation_environment');
  must(g.vars.MEMBERSHIP_HANDOFF_JOURNAL_ENABLED!=='true'||c.vars.HANDOFF_JOURNAL_ENABLED==='true','journal_binding_disabled');
  must(g.vars.MEMBERSHIP_HANDOFF_RELEASE_ENABLED!=='true'||c.vars.HANDOFF_RELEASE_ENABLED==='true','release_binding_disabled');
  const databases=[];for(const [j,x] of [i,c,a].entries()){must(Array.isArray(x.d1_databases)&&x.d1_databases.length===1,'db_count');const d=x.d1_databases[0];must(d.binding===(j?'ALLOCATION_DB':'AUTH_DB')&&typeof d.database_id==='string'&&UUID.test(d.database_id),'db_identity');databases.push(d.database_id);}
  must(databases[1]===databases[2]&&databases[0]!==databases[1],'database_boundary');
  const principals=[c.vars.CHECKOUT_PRINCIPAL_ID,c.vars.CHECKOUT_READ_PRINCIPAL_ID,a.vars.INGEST_PRINCIPAL_ID,a.vars.ALLOCATE_PRINCIPAL_ID,a.vars.READ_PRINCIPAL_ID,a.vars.OUTBOX_PRINCIPAL_ID];must(principals.every(p=>typeof p==='string'&&UUID.test(p))&&new Set(principals).size===6,'principal_separation');
 }
 return {configurationValid:true,handoffEnabled:g.vars.MEMBERSHIP_HANDOFF_JOURNAL_ENABLED==='true',unclaimedReleaseEnabled:g.vars.MEMBERSHIP_HANDOFF_RELEASE_ENABLED==='true',serverRecoveryAccepted:false,mode:ready?'isolated-staging-candidate':'disabled-template',requiredSecretsVerified:false,runtimeReady:false,liveBindingsVerified:false,sourceReconciliationVerified:false,nativeStorageVerified:false,atomicRevocationVerified:false,productionApproved:false};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){try{const args=process.argv.slice(2),ready=args.includes('--ready'),files=args.filter(a=>a!=='--ready');must(ready?files.length===4:files.length<=1,'arguments');
 const read=p=>JSON.parse(readFileSync(p,'utf8'));const g=files[0]?read(files[0]):read(new URL('../wrangler.staging.jsonc',import.meta.url));
 const upstream=ready?{identity:read(files[1]),checkout:read(files[2]),allocation:read(files[3])}:{};
 console.log(JSON.stringify(checkDeployment(g,upstream,ready),null,2));}catch(e){console.error(e.message.startsWith('configuration_rejected:')?e.message:'configuration_rejected:unreadable');process.exitCode=1;}}
