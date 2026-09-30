import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {validateDisabledPublication,checkDisabledPublicationTemplates} from '../scripts/check-deployment.mjs';
const names=['wrangler.publisher.staging.jsonc','wrangler.authorized-publisher.staging.jsonc'];
for(const name of names) {
 const original=JSON.parse(readFileSync(new URL('../'+name,import.meta.url),'utf8'));
 test(name+' verifies exact disabled resources',()=>assert.equal(validateDisabledPublication(original,name).runtimeReady,false));
 for(const [label,mutate] of [
  ['publication enablement',c=>c.vars.PUBLICATION_ENABLED='true'],
  ['public URL',c=>c.workers_dev=true],['preview URL',c=>c.preview_urls=true],
  ['extra route',c=>c.routes=[{pattern:'example.invalid/*',zone_name:'example.invalid'}]],
  ['additional authority',c=>c.services=[{binding:'UNEXPECTED',service:'other-service'}]],
  ['different database',c=>c.d1_databases[0].database_id='00000000-0000-4000-8000-000000000001'],
  ['different media bucket',c=>c.r2_buckets[0].bucket_name='unexpected-bucket'],
  ['unexpected plaintext credential',c=>c.vars.UNEXPECTED_TOKEN='synthetic'],
  ['different entrypoint',c=>c.main='src/index.mjs'],
 ])test(name+' rejects '+label,()=>{
  const c=structuredClone(original);mutate(c);assert.throws(()=>validateDisabledPublication(c,name),/configuration_mismatch/);
 });
}
test('all publication templates remain disabled and cannot claim readiness',()=>{
 const results=checkDisabledPublicationTemplates();assert.equal(results.length,2);
 assert.ok(results.every(v=>!v.publicationEnabled&&!v.publicUrlEnabled&&!v.operatorConfigured&&!v.runtimeReady));
});
