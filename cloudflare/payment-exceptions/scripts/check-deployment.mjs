import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const c=JSON.parse(readFileSync(new URL('../wrangler.staging.jsonc',import.meta.url),'utf8'));
assert.equal(c.workers_dev,false);assert.equal(c.preview_urls,false);assert.deepEqual(c.routes,[]);
assert.equal(c.vars.PAYMENT_CASES_ENABLED,'false');assert.equal(c.vars.PAYMENT_CASES_ENVIRONMENT,'isolated-staging');
assert.equal(c.d1_databases.length,1);assert.equal(c.d1_databases[0].binding,'PAYMENT_CASE_DB');
assert.equal(c.d1_databases[0].database_id,'00000000-0000-0000-0000-000000000000');
for(const k of ['services','queues','triggers','r2_buckets','kv_namespaces'])assert.equal(c[k],undefined);
console.log(JSON.stringify({passed:true,configuration:'disabled template',deployable:false,paymentCapabilities:false}));
