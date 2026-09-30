import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';
import {validateRecovery} from '../scripts/check-recovery-deployment.mjs';
const config=()=>JSON.parse(readFileSync(new URL('../wrangler.recovery.staging.jsonc',import.meta.url),'utf8'));
test('recovery template is disabled and carries no provider or sink/dispatcher binding',()=>assert.deepEqual(validateRecovery(config()),[]));
for(const patch of [{workers_dev:true},{preview_urls:true},{routes:['*/*']},{triggers:{crons:['* * * * *']}},{services:[]},
 {observability:{enabled:true}},{logpush:true},{d1_databases:[{binding:'AUTH_DB'}]}])
 test(`recovery template rejects unsafe ${Object.keys(patch)[0]}`,()=>assert.ok(validateRecovery({...config(),...patch}).length));
test('ready inspection refuses placeholder reviewer identities and the disabled template',()=>assert.ok(validateRecovery(config(),{ready:true}).length));
test('recovery rejects unlisted bindings and configuration variables',()=>{
 for(const patch of [{unsafe:{bindings:[]}},{tail_consumers:[]}])assert.ok(validateRecovery({...config(),...patch}).includes('unknown_configuration_field'));
 const c=config();c.vars.PAYMENT_PROVIDER_TOKEN='synthetic';assert.ok(validateRecovery(c).includes('unknown_configuration_var'));
});
test('ready inspection requires two different reviewers and a resolved source database identity',()=>{
 const c=config();Object.assign(c.vars,{PAYMENT_ALLOCATION_ENABLED:'true',ALLOCATION_DELIVERY_ENABLED:'true',ALLOCATION_RECOVERY_ENABLED:'true',
  DELIVERY_CONSUMER_ID:'90000000-0000-4000-8000-000000000001',RECOVERY_MAKER_PRINCIPAL_ID:'10000000-0000-4000-8000-000000000001',RECOVERY_CHECKER_PRINCIPAL_ID:'10000000-0000-4000-8000-000000000002'});
 c.d1_databases[0].database_id='80000000-0000-4000-8000-000000000001';assert.deepEqual(validateRecovery(c,{ready:true}),[]);
 c.vars.RECOVERY_CHECKER_PRINCIPAL_ID=c.vars.RECOVERY_MAKER_PRINCIPAL_ID;assert.ok(validateRecovery(c,{ready:true}).includes('reviewer_separation'));
});
