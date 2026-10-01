import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { checkedProductionBuild } from './local-build-proof-cache.mjs';

test('ordinary callers retain a full independent check on every call', () => {
  let calls=0;
  checkedProductionBuild('/unused',()=>({calls:++calls}));
  checkedProductionBuild('/unused',()=>({calls:++calls}));
  assert.equal(calls,2);
});

test('actual immutable guard permits reuse and rejects source/artifact writes', () => {
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'africlub-build-cache-'));
  const installed=path.join(root,'node_modules');const next=path.join(root,'.next');
  const proofs=fs.mkdtempSync(path.join(os.tmpdir(),'africlub-build-cache-proof-'));
  fs.mkdirSync(installed);fs.mkdirSync(next);
  fs.writeFileSync(path.join(root,'input.txt'),'source');
  fs.writeFileSync(path.join(next,'output.txt'),'artifact');
  fs.writeFileSync(path.join(next,'BUILD_ID'),'fixture-build');
  const seal=JSON.stringify({build_id:'fixture-build',source:{files:[{file:'input.txt'}]},artifacts:{files:[{file:'output.txt'}]}});
  fs.writeFileSync(path.join(next,'africlub-build-provenance.json'),seal);
  const guard=path.resolve('e2e/fixtures/local-evidence-inputs-readonly.cjs');
  const cacheModule=path.resolve('e2e/fixtures/local-build-proof-cache.mjs');
  const script=`import assert from 'node:assert/strict';import fs from 'node:fs';import {checkedProductionBuild} from ${JSON.stringify(cacheModule)};
    let calls=0;const check=()=>({build_id:'fixture-build',provenance_sha256:${JSON.stringify(createHash('sha256').update(seal).digest('hex'))},calls:++calls});
    const a=checkedProductionBuild(${JSON.stringify(root)},check),b=checkedProductionBuild(${JSON.stringify(root)},check);assert.equal(calls,1);assert.equal(a,b);
    for(const name of ['input.txt','.next/output.txt'])assert.throws(()=>fs.writeFileSync(${JSON.stringify(root)}+'/'+name,'mutated'),{code:'AFRICLUB_INSTALLED_WRITE_REJECTED'});
    checkedProductionBuild(${JSON.stringify(root)},check);assert.equal(calls,1);console.log('immutable cache and write rejection passed');`;
  const child=spawnSync(process.execPath,['--input-type=module','-e',script],{encoding:'utf8',env:{...process.env,NODE_OPTIONS:'--require='+guard,AFRICLUB_HTTP_INSTALLED_READONLY:installed,AFRICLUB_HTTP_INSTALLED_GUARD_OUTPUT:proofs,AFRICLUB_HTTP_ADDITIONAL_READONLY:JSON.stringify([root]),AFRICLUB_HTTP_READONLY_EXCEPTIONS:'[]'}});
  assert.equal(child.status,0,child.stderr);
  const reports=fs.readdirSync(proofs).filter(n=>n.endsWith('.json')).map(n=>JSON.parse(fs.readFileSync(path.join(proofs,n))));
  assert.equal(reports.length,1);assert.equal(reports[0].installedTreeWriteAttempts,2);
  assert.equal(fs.readFileSync(path.join(root,'input.txt'),'utf8'),'source');
  assert.equal(fs.readFileSync(path.join(next,'output.txt'),'utf8'),'artifact');
  fs.rmSync(root,{recursive:true});fs.rmSync(proofs,{recursive:true});
});

test('a writable source exception cannot obtain cached proof', () => {
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'africlub-build-cache-open-'));
  const installed=path.join(root,'node_modules');const next=path.join(root,'.next');
  const proofs=fs.mkdtempSync(path.join(os.tmpdir(),'africlub-build-cache-open-proof-'));
  fs.mkdirSync(installed);fs.mkdirSync(next);fs.writeFileSync(path.join(root,'input.txt'),'source');fs.writeFileSync(path.join(next,'BUILD_ID'),'fixture-build');
  fs.writeFileSync(path.join(next,'africlub-build-provenance.json'),JSON.stringify({build_id:'fixture-build',source:{files:[{file:'input.txt'}]},artifacts:{files:[]}}));
  const guard=path.resolve('e2e/fixtures/local-evidence-inputs-readonly.cjs');
  const script=`import assert from 'node:assert/strict';import {checkedProductionBuild} from ${JSON.stringify(path.resolve('e2e/fixtures/local-build-proof-cache.mjs'))};let calls=0;assert.throws(()=>checkedProductionBuild(${JSON.stringify(root)},()=>{calls++;return {}}),/does not cover/);assert.equal(calls,0);`;
  const child=spawnSync(process.execPath,['--input-type=module','-e',script],{encoding:'utf8',env:{...process.env,NODE_OPTIONS:'--require='+guard,AFRICLUB_HTTP_INSTALLED_READONLY:installed,AFRICLUB_HTTP_INSTALLED_GUARD_OUTPUT:proofs,AFRICLUB_HTTP_ADDITIONAL_READONLY:JSON.stringify([root]),AFRICLUB_HTTP_READONLY_EXCEPTIONS:JSON.stringify([path.join(root,'input.txt')])}});
  assert.equal(child.status,0,child.stderr);fs.rmSync(root,{recursive:true});fs.rmSync(proofs,{recursive:true});
});
