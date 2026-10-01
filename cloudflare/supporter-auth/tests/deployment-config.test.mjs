import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {execFileSync,spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {checkDeployment} from '../scripts/check-deployment.mjs';

const templates = () => ['wrangler.native-identity.staging.jsonc','wrangler.identity-verifier.staging.jsonc']
  .map(path => JSON.parse(readFileSync(new URL('../'+path,import.meta.url),'utf8')));

test('current native gateway and private verifier templates are disabled, isolated and unapproved', () => {
  const result = checkDeployment(templates());
  assert.equal(result.configurationPassed,true);
  for (const key of ['deployable','enabled','liveImportVerified','secretsProvisioned','actualCloudflareRuntimeVerified',
    'providerAcceptanceVerified','supabaseRetired','releaseAuthorized','deploymentPerformed']) assert.equal(result[key],false);
});

const sharedChanges = [
  ['public workers.dev', c => {c.workers_dev = true;}],
  ['public preview', c => {c.preview_urls = true;}],
  ['public custom route', c => {c.routes = [{pattern:'identity.example.invalid',custom_domain:true}];}],
  ['hidden route alias', c => {c.route = 'identity.example.invalid/*';}],
  ['automatic Cron', c => {c.triggers = {crons:['* * * * *']};}],
  ['enabled sign-in', c => {c.vars.AUTH_SERVICE_ENABLED = 'true';}],
  ['unsupported key version', c => {c.vars.AUTH_KEY_VERSION = '2';}],
  ['plaintext encryption key', c => {c.vars.AUTH_ENCRYPTION_KEY = 'synthetic-not-a-live-key';}],
  ['provider token', c => {c.vars.WHATSAPP_CLOUD_API_TOKEN = 'synthetic-not-a-live-token';}],
  ['non-identity database', c => {c.d1_databases[0].database_name = 'public-content';}],
  ['real-shaped resource ID', c => {c.d1_databases[0].database_id = '11111111-1111-4111-8111-111111111111';}],
  ['competing database binding', c => {c.d1_databases.push({...c.d1_databases[0],binding:'FINANCE_DB'});}],
  ['environment override', c => {c.env = {production:{}};}],
  ['provider/identity logging', c => {c.observability.enabled = true;}],
  ['extra object storage capability', c => {c.r2_buckets = [];}],
];
for (const [name,change] of sharedChanges) for (const index of [0,1]) test(`${index ? 'verifier' : 'native'} rejects ${name}`, () => {
  const configs = templates(); change(configs[index]); assert.equal(checkDeployment(configs).configurationPassed,false);
});

for (const [name,change] of [
  ['missing private sender', c => {c.services = [];}],
  ['wrong sender entrypoint', c => {c.services[0].entrypoint = 'UnreviewedSender';}],
  ['additional private capability', c => {c.services.push({binding:'PAYMENTS',service:'payments'});}],
  ['legacy delivery fallback', c => {c.vars.AUTH_DELIVERY_MODE = 'legacy';}],
  ['delivery enablement', c => {c.vars.AUTH_DELIVERY_ENABLED = 'true';}],
  ['preselected public origin', c => {c.vars.AUTH_ORIGIN = 'https://identity.example.invalid';}],
  ['unreviewed issuance policy', c => {c.vars.AUTH_ISSUANCE_POLICY_JSON = '{}';}],
  ['missing ingress limiter', c => {c.ratelimits = [];}],
  ['shared/live rate namespace', c => {c.ratelimits[0].namespace_id = '1234';}],
  ['unexpected rate ceiling', c => {c.ratelimits[0].simple.limit = 10000;}],
]) test(`native rejects ${name}`, () => {
  const configs = templates(); change(configs[0]); assert.equal(checkDeployment(configs).configurationPassed,false);
});

test('private verifier cannot gain an outgoing OTP capability', () => {
  const configs = templates();configs[1].services = configs[0].services;
  assert.equal(checkDeployment(configs).configurationPassed,false);
});
test('malformed identity configurations fail closed without echoing input', () => {
  for (const value of [null,{},[],[null,null],[{},{}]]) assert.equal(checkDeployment(value).configurationPassed,false);
});
test('identity checker CLI validates the current templates and refuses an enabling flag', () => {
  const script = fileURLToPath(new URL('../scripts/check-deployment.mjs',import.meta.url));
  assert.equal(JSON.parse(execFileSync(process.execPath,[script],{encoding:'utf8'})).configurationPassed,true);
  const result = spawnSync(process.execPath,[script,'--ready'],{encoding:'utf8'});
  assert.equal(result.status,1);assert.equal(result.stdout,'');
  const diagnostics=result.stderr.trim().split(/\r?\n/);
  assert.equal(diagnostics[0],'invalid_identity_configuration');
  assert.ok(diagnostics.length===1||diagnostics.length===2);
  if(diagnostics.length===2)assert.deepEqual(JSON.parse(diagnostics[1]),{
    localValidationNetworkGuard:true,outboundNetworkAttemptsBlocked:0,
  });
});
