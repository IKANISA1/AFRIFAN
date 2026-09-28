import test from 'node:test';
import assert from 'node:assert/strict';
import {fixture} from './support/fixture.mjs';
for(const path of ['/operator/clubs/24','/operator/clubs/24/public-source']) {
 test('canonical gateway serves protected alias '+path,async t=>{const f=fixture(t);const r=await f.call('',{url:'https://operator.example.invalid'+path,envOverride:{OPERATOR_UI_ENABLED:'true'}});assert.equal(r.status,200);assert.match(r.headers.get('content-type'),/text\/html/);assert.match(await r.text(),/Publication/)});
 test('canonical alias remains disabled '+path,async t=>{const f=fixture(t);assert.equal((await f.call('',{url:'https://operator.example.invalid'+path})).status,503)});
 test('canonical alias denies missing Access '+path,async t=>{const f=fixture(t);assert.equal((await f.call('',{url:'https://operator.example.invalid'+path,envOverride:{OPERATOR_UI_ENABLED:'true'},context:{}})).status,401)});
}
test('canonical console denies wrong club, mutation and query',async t=>{const f=fixture(t);for(const [path,method,status] of [['/operator/clubs/44','GET',404],['/operator/clubs/24?token=x','GET',404],['/operator/clubs/24','POST',405]]){assert.equal((await f.call('',{url:'https://operator.example.invalid'+path,method,envOverride:{OPERATOR_UI_ENABLED:'true'}})).status,status)}});
