import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';
import {ACTIONS,STATES,CATEGORIES,DISPOSITIONS,REASONS} from '../src/policy.mjs';
const c=JSON.parse(readFileSync(new URL('../contracts/api.json',import.meta.url),'utf8'));
test('published case contract matches implemented policy enums',()=>{for(const [key,values] of Object.entries({actions:ACTIONS,states:STATES,categories:CATEGORIES,dispositions:DISPOSITIONS,reasons:REASONS}))assert.deepEqual(c.enums[key],values);});
test('contract retains nonfinancial, disabled scope and six gateway methods',()=>{assert.equal(c.financialEffect,'none');assert.equal(c.referencesVerified,false);assert.equal(c.release.enabledByDefault,false);assert.deepEqual(c.routes.map(r=>r.rpc),['list','get','history','command','access','operation']);assert.equal(c.writeBodyMaximumBytes,4096);});
