import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {checkHealthConfiguration} from '../scripts/check-reliable-delivery.mjs';
import {checkDeployment} from '../../auth-code-delivery/scripts/check-deployment.mjs';
import {checkReceiptsDeployment} from '../../auth-code-delivery/scripts/check-receipts-deployment.mjs';
const load = path => JSON.parse(readFileSync(new URL(path,import.meta.url),'utf8'));

for (const [name,mutate] of [
  ['alternate public route', c => {c.route = 'example.invalid/*';}],
  ['extra personal-data storage binding', c => {c.kv_namespaces = [{binding:'UNREVIEWED',id:'placeholder'}];}],
]) test(`private OTP transport rejects ${name}`, () => {
  const c = load('../../auth-code-delivery/wrangler.staging.jsonc');mutate(c);
  assert.equal(checkDeployment(c).configurationPassed,false);
});
test('private OTP transport rejects an unrecognized plaintext provider secret variable', () => {
  const c = load('../../auth-code-delivery/wrangler.staging.jsonc');c.vars.META_APP_SECRET = 'synthetic-placeholder';
  assert.equal(checkDeployment(c).configurationPassed,false);
});
for (const [name,mutate] of [
  ['alternate public route', c => {c.route = 'example.invalid/*';}],
  ['extra credential binding', c => {c.kv_namespaces = [{binding:'UNREVIEWED',id:'placeholder'}];}],
  ['wrong storage authority', c => {c.d1_databases[0].database_name = 'financial-ledger';}],
]) test(`private queue-health template rejects ${name}`, () => {
  const c = load('../wrangler.delivery-health.staging.jsonc');mutate(c);
  assert.throws(() => checkHealthConfiguration(c),/invalid_health_configuration/);
});
for (const index of [0,1,2]) test(`receipt worker ${index} rejects an alternate public route`, () => {
  const configs = ['wrangler.receipts-webhook.staging.jsonc','wrangler.status-aware.staging.jsonc',
    'wrangler.receipt-reader.staging.jsonc'].map(p => load('../../auth-code-delivery/'+p));
  configs[index].route = 'example.invalid/*';assert.equal(checkReceiptsDeployment(configs).configurationPassed,false);
});
