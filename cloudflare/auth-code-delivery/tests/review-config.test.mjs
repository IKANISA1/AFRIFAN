import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';import {validateReview} from '../scripts/check-review-deployment.mjs';
const config=()=>JSON.parse(readFileSync(new URL('../wrangler.review.staging.jsonc',import.meta.url),'utf8'));
test('read-only review template stays disabled, private and without provider credentials',()=>assert.deepEqual(validateReview(config()),[]));
for(const patch of [{workers_dev:true},{services:[]},{observability:{enabled:true}},{d1_databases:[{binding:'AUTH_DB'}]}])
 test(`review template rejects unsafe ${Object.keys(patch)[0]}`,()=>assert.ok(validateReview({...config(),...patch}).length));
test('review rejects putting a provider credential into the read-only service',()=>{const c=config();c.vars.WA_ACCESS_TOKEN='synthetic-placeholder';assert.ok(validateReview(c).includes('provider_credential_in_reader'));});
