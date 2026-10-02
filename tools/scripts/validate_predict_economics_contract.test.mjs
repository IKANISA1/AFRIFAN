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
const freeImplementation=()=>({schemaVersion:1,status:'free_implementation',mechanic:'free_selected_match',economicsVersion:'free_v1',
 entryDebitFet:0,entryDebitMoney:0,newRewardFet:0,newRewardMoney:0,implementationState:'in_progress',externalDecisionStatus:'unresolved',
 deploymentVerified:false,releaseAuthorized:false,transactionalMigrationEnabled:true,approvals:[],historicalEconomicsVersion:'legacy_paid_v1',
 historicalLedgerDisposition:'preserve; no reset or silent rewrite',versionedDecisionRef:'technical:free_v1'});
test('local free implementation is consistent without implying release',()=>{assert.deepEqual(validateEconomics(freeImplementation()),[]);assert.ok(validateEconomics(freeImplementation(),{release:true}).length);});
test('local verification does not supply external economics approval',()=>assert.ok(validateEconomics({...freeImplementation(),implementationState:'verified_locally'},{release:true}).length));
test('local free implementation rejects new financial credits and debits',()=>{for(const key of ['entryDebitFet','entryDebitMoney','newRewardFet','newRewardMoney']) assert.ok(validateEconomics({...freeImplementation(),[key]:1}).length,key);});
test('local free implementation rejects invented deployment or approval claims',()=>{for(const patch of [{deploymentVerified:true},{releaseAuthorized:true},{approvals:[{}]},{externalDecisionStatus:'approved'}]) assert.ok(validateEconomics({...freeImplementation(),...patch}).length);});
test('local free implementation cannot silently convert historical paid data',()=>assert.ok(validateEconomics({...freeImplementation(),historicalEconomicsVersion:'free_v1'}).length));
