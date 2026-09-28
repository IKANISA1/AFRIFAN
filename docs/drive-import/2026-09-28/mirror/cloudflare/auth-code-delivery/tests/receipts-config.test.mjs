import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {checkReceiptsDeployment} from '../scripts/check-receipts-deployment.mjs';
const names=['wrangler.receipts-webhook.staging.jsonc','wrangler.status-aware.staging.jsonc','wrangler.receipt-reader.staging.jsonc'];
const load=()=>names.map(n=>JSON.parse(readFileSync(new URL('../'+n,import.meta.url))));
function prepared(){const c=load(),now=Date.now(),routes=[{clubId:24,businessAccountId:'100000000000099',phoneNumberId:'100000000000001'}];
 for(const x of c){x.d1_databases[0].database_id='11111111-2222-4333-8444-555555555555';x.vars.RECEIPT_ROUTES_JSON=JSON.stringify(routes);}
 c[0].vars.RECEIPT_WEBHOOK_ENABLED='true';c[0].vars.RECEIPT_RECONCILE_ENABLED='true';c[0].vars.RECEIPT_ORIGIN='https://receipts.africlub.example';
 c[0].routes=[{pattern:'receipts.africlub.example',custom_domain:true}];c[0].triggers.crons=['* * * * *'];c[0].ratelimits[0].namespace_id='10001';
 c[1].vars.DELIVERY_ENABLED='true';c[1].vars.RECEIPT_BINDING_ENABLED='true';c[1].vars.WA_GRAPH_VERSION='v99.0';
 c[1].vars.DELIVERY_ROUTES_JSON=JSON.stringify([{clubId:24,phoneNumberId:routes[0].phoneNumberId,templateId:'100000000000088',templateName:'synthetic_auth',language:'en_US',reviewRef:'test-only',reviewExpiresAt:now+86400000}]);
 c[2].vars.RECEIPT_READ_ENABLED='true';return {c,now};}
test('all shipped receipt configurations are disabled and contain no secret',()=>{const r=checkReceiptsDeployment(load());assert.equal(r.configurationPassed,true);assert.equal(r.releaseAuthorized,false);});
test('resolved configuration check never grants real runtime or signature approval',()=>{const {c,now}=prepared();const r=checkReceiptsDeployment(c,{ready:true,now});assert.equal(r.configurationPassed,true,JSON.stringify(r));assert.equal(r.liveSignatureVerified,false);assert.equal(r.deploymentPerformed,false);});
const cases={
 'public private-reader route':c=>c[2].routes=[{pattern:'example.com'}],
 'public sender preview':c=>c[1].preview_urls=true,
 'identity database instead of dispatch':c=>c[0].d1_databases[0].database_name='africlub-identity-staging',
 'different database IDs':c=>c[2].d1_databases[0].database_id='22222222-2222-4222-8222-222222222222',
 'secret plaintext':c=>c[0].vars.WA_WEBHOOK_APP_SECRET='DO_NOT_INCLUDE_A_REAL_SECRET',
 'unexpected assets':c=>c[0].assets={directory:'public'},
 'environment overrides':c=>c[0].env={},
 'outgoing service':c=>c[0].services=[{binding:'AUTH',service:'identity'}],
 'unbounded rate':c=>c[0].ratelimits[0].simple.limit=10000,
 'missing rate':c=>delete c[0].ratelimits,
 'raw logging':c=>c[0].observability.enabled=true,
 'mixed club route':c=>c[2].vars.RECEIPT_ROUTES_JSON='[{"clubId":44,"businessAccountId":"100000000000099","phoneNumberId":"100000000000001"}]',
 'sender template route mismatch':c=>{const r=JSON.parse(c[1].vars.DELIVERY_ROUTES_JSON);r[0].phoneNumberId='100000000000009';c[1].vars.DELIVERY_ROUTES_JSON=JSON.stringify(r);},
 'wrong callback domain':c=>c[0].routes[0].pattern='other.example',
 'reader main wrong':c=>c[2].main='src/worker.mjs',
 'no bounded reconciliation schedule':c=>c[0].triggers.crons=[],
 'unexpected sender schedule':c=>c[1].triggers.crons=['* * * * *'],
 'sender inactive for ready':c=>c[1].vars.DELIVERY_ENABLED='false',
 'unknown key format':c=>c[0].vars.RECEIPT_KEY_VERSION='2',
 'wildcard ingress':c=>c[0].routes.push({pattern:'*.example/*'}),
 'limiter namespace unset':c=>c[0].ratelimits[0].namespace_id='0',
};
for(const [name,mutate]of Object.entries(cases))test('configuration rejects '+name,()=>{const {c,now}=prepared();mutate(c);assert.equal(checkReceiptsDeployment(c,{ready:true,now}).configurationPassed,false);});
test('enabled template is rejected by template mode',()=>{const {c}=prepared();assert.equal(checkReceiptsDeployment(c).configurationPassed,false);});
test('insufficient config files fail closed',()=>{assert.equal(checkReceiptsDeployment([]).configurationPassed,false);});
test('contract matches all receipt fields and flags',()=>{const c=JSON.parse(readFileSync(new URL('../contracts/delivery-receipts.json',import.meta.url)));assert.equal(c.privateReader.informationOnly,true);assert.equal(c.operationalLimits.reconcileBatch,100);assert.equal(c.releaseAuthorized,false);});
