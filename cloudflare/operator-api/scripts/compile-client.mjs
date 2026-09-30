#!/usr/bin/env node
import {spawnSync} from 'node:child_process';import {mkdtempSync,rmSync} from 'node:fs';import {tmpdir} from 'node:os';import {join} from 'node:path';import {fileURLToPath} from 'node:url';
// Uses an installed TypeScript compiler, never downloads packages or updates locks.
const output=mkdtempSync(join(tmpdir(),'africlub-client-typecheck-'));
try {
 const run=spawnSync(process.env.TSC_BIN||'tsc',['--strict','--target','ES2022','--module','ES2022','--lib','ES2022,DOM',
 '--outDir',output,fileURLToPath(new URL('../client.ts',import.meta.url))],{encoding:'utf8'});
 if(run.error)throw run.error;process.stdout.write(run.stdout);process.stderr.write(run.stderr);
 if(run.status!==0)process.exitCode=1;else console.log('Operator client TypeScript strict check passed.');
}finally{rmSync(output,{recursive:true,force:true});}
