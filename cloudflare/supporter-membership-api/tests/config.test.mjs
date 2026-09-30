import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';
import {checkDeployment} from '../scripts/check-deployment.mjs';import {config} from '../src/policy.mjs';import {fixture} from './fixture.mjs';
const template=()=>JSON.parse(readFileSync(new URL('../wrangler.staging.jsonc',import.meta.url),'utf8'));
function ready(){const g=template(),id=()=>crypto.randomUUID();g.account_id='12'.repeat(16);g.vars.MEMBERSHIP_API_ENABLED='true';g.vars.NATIVE_ORIGIN='https://stage.africlub.test';g.vars.CLUB_ROUTES_JSON=JSON.stringify([{clubId:24,clubSlug:'rayon_sports_rw'}]);g.routes=[{pattern:'stage.africlub.test',custom_domain:true}];g.ratelimits[0].namespace_id='10201';g.ratelimits[1].namespace_id='10202';
 const common={account_id:g.account_id,workers_dev:false,preview_urls:false,routes:[]};const db=id(),other=id();
 const identity={...common,name:'africlub-supporter-identity-verifier-staging',main:'src/identity-verifier-worker.mjs',vars:{AUTH_SERVICE_ENABLED:'true',AUTH_KEY_VERSION:'1'},d1_databases:[{binding:'AUTH_DB',database_id:other}]};
 const checkout={...common,name:'africlub-membership-checkout-staging',main:'src/checkout-worker.mjs',vars:{MEMBERSHIP_CHECKOUT_ENABLED:'true',PAYMENT_ALLOCATION_ENABLED:'true',ALLOCATION_ENVIRONMENT:'isolated-staging',CHECKOUT_PRINCIPAL_ID:id(),CHECKOUT_READ_PRINCIPAL_ID:id()},d1_databases:[{binding:'ALLOCATION_DB',database_id:db}]};
 const allocation={...common,name:'africlub-payment-allocation-staging',main:'src/worker.mjs',vars:{PAYMENT_ALLOCATION_ENABLED:'true',ALLOCATION_ENVIRONMENT:'isolated-staging',INGEST_PRINCIPAL_ID:id(),ALLOCATE_PRINCIPAL_ID:id(),READ_PRINCIPAL_ID:id(),OUTBOX_PRINCIPAL_ID:id()},d1_databases:[{binding:'ALLOCATION_DB',database_id:db}]};return {g,u:{identity,checkout,allocation}};}
test('shipped template remains disabled',()=>{const r=checkDeployment(template());assert.equal(r.mode,'disabled-template');assert.equal(r.productionApproved,false);});
test('configured staging check is never live authorization',()=>{const {g,u}=ready(),r=checkDeployment(g,u,true);for(const k of ['liveBindingsVerified','sourceReconciliationVerified','nativeStorageVerified','atomicRevocationVerified','productionApproved'])assert.equal(r[k],false);});
test('configured rotated identity accepts reviewed public policy without secret material',()=>{
 const {g,u}=ready();u.identity.vars.AUTH_KEY_VERSION='2';u.identity.vars.AUTH_KEY_POLICY_JSON=JSON.stringify({schemaVersion:1,currentVersion:'2',activatedAt:1790700000000,versions:[{version:'1',notBefore:0,readUntil:1790700900000},{version:'2',notBefore:1790700000000,readUntil:null}]});
 const r=checkDeployment(g,u,true);assert.equal(r.configurationValid,true);assert.equal(r.requiredSecretsVerified,false);assert.equal(r.productionApproved,false);
});
for(const [name,policy] of [['missing',undefined],['invalid','{}'],['wrong_version',JSON.stringify({schemaVersion:1,currentVersion:'3',activatedAt:1790700000000,versions:[{version:'3',notBefore:1790700000000,readUntil:null}]})]])test(`rotated public policy rejects ${name}`,()=>{
 const {g,u}=ready();u.identity.vars.AUTH_KEY_VERSION='2';if(policy!==undefined)u.identity.vars.AUTH_KEY_POLICY_JSON=policy;assert.throws(()=>checkDeployment(g,u,true));
});
for(const field of ['AUTH_KEYRING_JSON','AUTH_HMAC_KEY','AUTH_ENCRYPTION_KEY'])test(`readiness refuses ${field} material in public vars`,()=>{
 const {g,u}=ready();u.identity.vars[field]='synthetic-private-material';assert.throws(()=>checkDeployment(g,u,true));
});
for(const [label,mutate] of [
 ['environment',g=>g.vars.MEMBERSHIP_ENVIRONMENT='production'],['extra vars',g=>g.vars.GATEWAY_RATE_KEY='secret'],['direct db',g=>g.d1_databases=[]],['environment override',g=>g.env={}],['public preview',g=>g.workers_dev=true],['logging',g=>g.observability.enabled=true],['wrong service',g=>g.services[1].entrypoint='PaymentAllocator'],['extra service',g=>g.services.push(g.services[0])],['duplicate rates',g=>g.ratelimits[1].namespace_id=g.ratelimits[0].namespace_id],['missing limiter',g=>g.ratelimits.pop()],['rate policy',g=>g.ratelimits[0].simple.limit=10000],['wildcard ingress',g=>g.routes[0].pattern='*'],['http origin',g=>g.vars.NATIVE_ORIGIN='http://stage.africlub.test'],['duplicate club',g=>g.vars.CLUB_ROUTES_JSON='[{"clubId":24,"clubSlug":"rayon"},{"clubId":24,"clubSlug":"other"}]'],['secret field',g=>g.vars.token='x'],['wrong main',g=>g.main='src/other.mjs']])test(`configuration rejects ${label}`,()=>{const {g,u}=ready();mutate(g);assert.throws(()=>checkDeployment(g,u,true));});
for(const [label,mutate] of [
 ['account mismatch',u=>u.identity.account_id='34'.repeat(16)],['same auth and financial db',u=>u.identity.d1_databases[0].database_id=u.allocation.d1_databases[0].database_id],['split checkout db',u=>u.checkout.d1_databases[0].database_id=crypto.randomUUID()],['reused principal',u=>u.checkout.vars.CHECKOUT_PRINCIPAL_ID=u.allocation.vars.ALLOCATE_PRINCIPAL_ID],['public upstream',u=>u.identity.routes=['https://*']],['upstream disabled',u=>u.identity.vars.AUTH_SERVICE_ENABLED='false'],['extra upstream binding',u=>u.checkout.services=[]],['upstream writer production',u=>u.allocation.vars.ALLOCATION_ENVIRONMENT='production']])test(`upstream check rejects ${label}`,()=>{const {g,u}=ready();mutate(u);assert.throws(()=>checkDeployment(g,u,true));});
for(const key of ['IDENTITY','CHECKOUT','CHECKOUT_READER','PAYMENT_RECEIPTS','EDGE_LIMIT','SUBJECT_LIMIT'])test(`runtime requires ${key}`,async t=>{const f=await fixture(t);delete f.env[key];assert.throws(()=>config(f.env));});
for(const key of ['AUTH_DB','ALLOCATION_DB','PAYMENT_ALLOCATOR','PAYMENT_INGESTOR','OTP_DELIVERY'])test(`runtime refuses extra capability ${key}`,async t=>{const f=await fixture(t);f.env[key]={};assert.throws(()=>config(f.env));});

test('unclaimed recovery is explicitly disabled in the shipped template',()=>{
 assert.equal(template().vars.MEMBERSHIP_HANDOFF_RELEASE_ENABLED,'false');
});
test('isolated staging release requires matching journal and release capabilities',()=>{
 const {g,u}=ready();g.vars.MEMBERSHIP_HANDOFF_JOURNAL_ENABLED='true';g.vars.MEMBERSHIP_HANDOFF_RELEASE_ENABLED='true';
 u.checkout.vars.HANDOFF_JOURNAL_ENABLED='true';u.checkout.vars.HANDOFF_RELEASE_ENABLED='true';
 const result=checkDeployment(g,u,true);assert.equal(result.handoffEnabled,true);assert.equal(result.unclaimedReleaseEnabled,true);assert.equal(result.productionApproved,false);
});
for(const [name,change] of [
 ['gateway journal',g=>g.vars.MEMBERSHIP_HANDOFF_JOURNAL_ENABLED='false'],
 ['upstream journal',(_g,u)=>u.checkout.vars.HANDOFF_JOURNAL_ENABLED='false'],
 ['upstream release',(_g,u)=>u.checkout.vars.HANDOFF_RELEASE_ENABLED='false'],
 ['invalid release flag',g=>g.vars.MEMBERSHIP_HANDOFF_RELEASE_ENABLED='yes'],
])test(`release configuration rejects missing ${name}`,()=>{
 const {g,u}=ready();g.vars.MEMBERSHIP_HANDOFF_JOURNAL_ENABLED='true';g.vars.MEMBERSHIP_HANDOFF_RELEASE_ENABLED='true';
 u.checkout.vars.HANDOFF_JOURNAL_ENABLED='true';u.checkout.vars.HANDOFF_RELEASE_ENABLED='true';change(g,u);
 assert.throws(()=>checkDeployment(g,u,true));
});
for(const [binding,method] of [['CHECKOUT','reserveHandoff'],['CHECKOUT','claimHandoff'],['CHECKOUT_READER','currentHandoff']]){
 test(`enabled journal refuses missing ${binding}.${method} before domain access`,async t=>{
  const f=await fixture(t);f.env.MEMBERSHIP_HANDOFF_JOURNAL_ENABLED='true';
  f.env.CHECKOUT.reserveHandoff=async()=>{};f.env.CHECKOUT.claimHandoff=async()=>{};f.env.CHECKOUT_READER.currentHandoff=async()=>{};
  delete f.env[binding][method];assert.throws(()=>config(f.env));
  const r=await f.call('membership/handoffs/reservations',{method:'POST',body:{orderId:crypto.randomUUID()},key:crypto.randomUUID()});
  assert.equal(r.status,503);assert.deepEqual(await r.json(),{schemaVersion:1,error:'invalid_configuration'});assert.deepEqual(f.calls,[]);
 });
}
test('enabled release requires a release capability and a journal before any RPC',async t=>{
 const f=await fixture(t);f.env.MEMBERSHIP_HANDOFF_RELEASE_ENABLED='true';assert.throws(()=>config(f.env));
 f.env.MEMBERSHIP_HANDOFF_JOURNAL_ENABLED='true';f.env.CHECKOUT.reserveHandoff=async()=>{};f.env.CHECKOUT.claimHandoff=async()=>{};f.env.CHECKOUT_READER.currentHandoff=async()=>{};
 assert.throws(()=>config(f.env));f.env.CHECKOUT.releaseHandoff=async()=>{};assert.doesNotThrow(()=>config(f.env));
});
test('disabled template cannot silently enable release',()=>{
 const g=template();g.vars.MEMBERSHIP_HANDOFF_RELEASE_ENABLED='true';assert.throws(()=>checkDeployment(g));
});
