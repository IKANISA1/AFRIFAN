import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

test('real loader threads retain independent terminal write-rejection receipts', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'africlub-thread-fence-'));
  const installed = path.join(root, 'node_modules');
  const proofs = path.join(root, 'proofs');
  fs.mkdirSync(installed); fs.mkdirSync(proofs);
  const input = path.join(installed, 'input.txt');
  fs.writeFileSync(input, 'unchanged');
  const adapter = path.resolve('e2e/fixtures/local-evidence-thread-proof.cjs');
  const fence = path.resolve('e2e/fixtures/local-evidence-inputs-readonly.cjs');
  const script = `const {Worker}=require('node:worker_threads');
    const code=${JSON.stringify(`const assert=require('node:assert/strict'); const fs=require('node:fs'); assert.throws(()=>fs.writeFileSync(${JSON.stringify(input)},'changed'),{code:'AFRICLUB_INSTALLED_WRITE_REJECTED'});`)};
    Promise.all([1,2].map(()=>new Promise((resolve,reject)=>{const worker=new Worker(code,{eval:true});worker.on('error',reject);worker.on('exit',code=>code===0?resolve():reject(new Error('thread failed')));}))).catch(error=>{console.error(error);process.exitCode=1;});`;
  const child = spawnSync(process.execPath, ['-e', script], {
    encoding: 'utf8', env: { ...process.env,
      NODE_OPTIONS: `--require=${adapter} --require=${fence}`,
      AFRICLUB_HTTP_INSTALLED_READONLY: installed,
      AFRICLUB_HTTP_INSTALLED_GUARD_OUTPUT: proofs,
      AFRICLUB_HTTP_ADDITIONAL_READONLY: '[]',
      AFRICLUB_HTTP_READONLY_EXCEPTIONS: '[]',
    },
  });
  assert.equal(child.status, 0, child.stderr);
  const files = fs.readdirSync(proofs, { recursive: true });
  const reports = files.filter(name => name.endsWith('.json'))
    .map(name => JSON.parse(fs.readFileSync(path.join(proofs, name))));
  assert.equal(reports.length, 3);
  assert.equal(files.filter(name => name.endsWith('.started')).length, 3);
  assert.equal(reports.reduce((count, row) => count + row.installedTreeWriteAttempts, 0), 2);
  assert.ok(reports.every(row => row.terminalReceipt === true));
  assert.equal(fs.readFileSync(input, 'utf8'), 'unchanged');
  fs.rmSync(root, { recursive: true });
});
