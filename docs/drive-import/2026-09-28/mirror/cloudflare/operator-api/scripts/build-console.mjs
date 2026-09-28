#!/usr/bin/env node
import {spawnSync} from 'node:child_process';import {mkdirSync,rmSync} from 'node:fs';import {fileURLToPath} from 'node:url';
// Deployment-time derived asset. No package download, runtime secrets or embedded user identity.
const out=fileURLToPath(new URL('../generated/',import.meta.url));mkdirSync(out,{recursive:true});
rmSync(fileURLToPath(new URL('../generated/client.js',import.meta.url)),{force:true});
const run=spawnSync(process.env.TSC_BIN||'tsc',['--strict','--target','ES2022','--module','ES2022','--lib','ES2022,DOM','--outDir',out,fileURLToPath(new URL('../client.ts',import.meta.url))],{encoding:'utf8'});
if(run.error)throw run.error;process.stdout.write(run.stdout);process.stderr.write(run.stderr);process.exitCode=run.status===0?0:1;
