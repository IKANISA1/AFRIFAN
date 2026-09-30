import test from 'node:test';
import assert from 'node:assert/strict';
import { validateEconomics } from './validate_predict_economics_contract.mjs';
const unresolved=()=>({schemaVersion:1,status:'unresolved',transactionalMigrationEnabled:false,releaseAuthorized:false,approvals:[]});
const approved=()=>({schemaVersion:1,status:'approved',mechanic:'free_reward_only',entryDebitFet:0,entryDebitMoney:0,
 versionedDecisionRef:'synthetic:test',releaseAuthorized:true,approvals:['product','legal','payments','store-release'].map(role=>({role,reviewer:'synthetic:test',evidenceRef:'synthetic:test'}))});
test('unresolved consistency does not imply release',()=>{assert.deepEqual(validateEconomics(unresolved()),[]);assert.ok(validateEconomics(unresolved(),{release:true}).length);});
test('unresolved cannot silently enable transactions',()=>assert.ok(validateEconomics({...unresolved(),transactionalMigrationEnabled:true}).length));
test('unresolved cannot claim approvals',()=>assert.ok(validateEconomics({...unresolved(),approvals:[{}]}).length));
test('free entry cannot debit FET',()=>assert.ok(validateEconomics({...approved(),entryDebitFet:100}).length));
test('cash entry rejected',()=>assert.ok(validateEconomics({...approved(),entryDebitMoney:1}).length));
test('incomplete review rejected',()=>assert.ok(validateEconomics({...approved(),approvals:[]},{release:true}).length));
test('duplicate review rejected',()=>{const r=approved();r.approvals.push(r.approvals[0]);assert.ok(validateEconomics(r).length);});
test('synthetic complete record passes structure only',()=>assert.deepEqual(validateEconomics(approved(),{release:true}),[]));
test('unapproved release rejected',()=>assert.ok(validateEconomics({...approved(),releaseAuthorized:false},{release:true}).length));
