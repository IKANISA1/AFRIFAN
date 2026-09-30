import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';
import {checkDeployment} from '../../operator-api/scripts/check-deployment.mjs';
const read=rel=>JSON.parse(readFileSync(new URL(rel,import.meta.url),'utf8'));
const g=()=>read('../../operator-api/wrangler.staging.jsonc'),p=()=>read('../../rayon-public/wrangler.authorized-publisher.staging.jsonc');
test('extended gateway configuration is disabled by default',()=>assert.deepEqual(checkDeployment(g(),p()).failures,[]));
for(const mutation of ['missing','extra','entrypoint','service','switch','enabled'])test('configuration gate rejects case binding '+mutation,()=>{
 const c=g();if(mutation==='missing')c.services=c.services.slice(0,1);if(mutation==='extra')c.services.push({binding:'UNREVIEWED'});
 if(mutation==='entrypoint')c.services[1].entrypoint='Unreviewed';if(mutation==='service')c.services[1].service='financial-writer';
 if(mutation==='switch')delete c.vars.OPERATOR_CASES_ENABLED;if(mutation==='enabled')c.vars.OPERATOR_CASES_ENABLED='true';
 assert.ok(checkDeployment(c,p()).failures.length>0);
});
