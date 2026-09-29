import {readFileSync} from 'node:fs';import {fileURLToPath} from 'node:url';import {resolve} from 'node:path';
function need(ok,message){if(!ok)throw Error(message);}
function only(value,allowed,message){need(value&&typeof value==='object'&&!Array.isArray(value)&&Object.keys(value).every(k=>allowed.includes(k)),message);}
function exact(value,expected,message){only(value,expected,message);need(Object.keys(value).length===expected.length,message);}

/** Validates disabled distribution templates only, not authorization to deploy. */
export function validateTemplates(api,identity){
 const common=['name','main','compatibility_date','account_id','workers_dev','preview_urls','routes','observability','vars'];
 only(api,[...common,'services','ratelimits'],'Unreviewed gateway capability');
 only(identity,[...common,'triggers','d1_databases'],'Unreviewed identity capability');
 need(api.main==='src/index.mjs'&&identity.main==='src/browser-identity-worker.mjs','Unreviewed entrypoint');
 exact(api.vars,['BROWSER_API_ENABLED','BROWSER_MEMBERSHIP_ENABLED','BROWSER_CHECKOUT_ENABLED','BROWSER_ORIGIN','BROWSER_CLUB_ID'],'Unreviewed gateway variable');
 exact(identity.vars,['AUTH_SERVICE_ENABLED','AUTH_BROWSER_ENABLED','AUTH_KEY_VERSION','BROWSER_ORIGIN','BROWSER_CLUB_ID','AUTH_ISSUANCE_POLICY_JSON'],'Unreviewed identity variable');
 need(identity.vars.AUTH_KEY_VERSION==='1'&&identity.vars.AUTH_ISSUANCE_POLICY_JSON==='','Unassigned issuance policy required');
 for(const c of [api,identity]){
  need(c.account_id==='','Distribution account must be unassigned');
  exact(c.observability,['enabled'],'Unreviewed logging configuration');
  if(c.triggers)exact(c.triggers,['crons'],'Unreviewed trigger authority');
  need(c.workers_dev===false&&c.preview_urls===false&&Array.isArray(c.routes)&&c.routes.length===0,'Public routes must remain disabled');
  need(c.observability?.enabled===false,'Unapproved logging must remain disabled');
  need(!c.triggers?.crons?.length,'Schedules require separate approval');
  need(c.vars&&Object.keys(c.vars).every(k=>!/KEY$|TOKEN|SECRET/.test(k)),'Do not embed credentials');
  need(c.vars.BROWSER_ORIGIN===''&&c.vars.BROWSER_CLUB_ID==='','Template origin and club are unassigned');
 }
 for(const flag of ['BROWSER_API_ENABLED','BROWSER_MEMBERSHIP_ENABLED','BROWSER_CHECKOUT_ENABLED'])need(api.vars[flag]==='false','Browser features must remain disabled');
 need(identity.vars.AUTH_BROWSER_ENABLED==='false'&&identity.vars.AUTH_SERVICE_ENABLED==='false','Identity must remain disabled');
 need(!api.d1_databases?.length&&!api.r2_buckets?.length&&!api.kv_namespaces?.length,'Gateway must not bind a data store');
 need(identity.d1_databases?.length===1&&identity.d1_databases[0].binding==='AUTH_DB'&&identity.d1_databases[0].migrations_dir==='migrations','Identity requires its canonical AUTH_DB');
 need(!identity.services?.length,'Identity must not call provider/financial services');
 const db=identity.d1_databases[0];
 exact(db,['binding','database_name','database_id','migrations_dir'],'Unreviewed database configuration');
 need(db.database_id==='REPLACE_WITH_REVIEWED_IDENTITY_DATABASE'&&db.database_name==='africlub-supporter-identity-staging','Unassigned canonical identity database required');
 const expected={BROWSER_IDENTITY:'BrowserIdentity',CHECKOUT:'MembershipCheckout',CHECKOUT_READER:'MembershipCheckoutReader',PAYMENT_RECEIPTS:'PaymentReceiptReader'};
 need(Array.isArray(api.services)&&api.services.length===Object.keys(expected).length,'Unexpected service capabilities');
 const seen=new Set();
 for(const b of api.services){exact(b,['binding','service','entrypoint'],'Unreviewed service authority');need(expected[b.binding]===b.entrypoint&&!seen.has(b.binding)&&typeof b.service==='string'&&/^[A-Za-z0-9_-]+$/.test(b.service),'Invalid service binding');seen.add(b.binding);}
 need(api.ratelimits?.length===2&&['EDGE_LIMIT','SUBJECT_LIMIT'].every(n=>api.ratelimits.some(r=>r.name===n&&r.simple?.period===60&&r.simple?.limit>0)),'Rate boundaries required');
 for(const r of api.ratelimits){
  exact(r,['name','namespace_id','simple'],'Unreviewed rate authority');exact(r.simple,['limit','period'],'Unreviewed rate configuration');
  need(Number.isSafeInteger(r.simple.limit)&&r.simple.limit>0&&r.simple.limit<=1000&&typeof r.namespace_id==='string'&&r.namespace_id.startsWith('REPLACE_WITH_REVIEWED_BROWSER_'),'Unassigned bounded rate authority required');
 }
 return {passed:true,scope:'disabled templates only',runtimeReady:false,requiredSecretsVerified:false,deploymentAuthorized:false};
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{const api=JSON.parse(readFileSync(new URL('../wrangler.staging.jsonc',import.meta.url),'utf8'));
  const id=JSON.parse(readFileSync(new URL('../../supporter-auth/wrangler.browser-identity.staging.jsonc',import.meta.url),'utf8'));
  console.log(JSON.stringify(validateTemplates(api,id)));}catch(e){console.error(e.message);process.exitCode=1;}
}
