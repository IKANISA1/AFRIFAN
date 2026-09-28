#!/usr/bin/env node
import { mkdtempSync,rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
export function compileClient(){const directory=mkdtempSync(join(tmpdir(),'africlub-identity-client-'));try{execFileSync('tsc',[fileURLToPath(new URL('../client.ts',import.meta.url)),'--target','ES2022','--module','ES2022','--moduleResolution','bundler','--lib','ES2022,DOM','--strict','--skipLibCheck','--outDir',directory],{stdio:'pipe'});return {directory,path:join(directory,'client.js')};}catch(error){rmSync(directory,{recursive:true,force:true});throw error;}}
if(process.argv[1]===fileURLToPath(import.meta.url)){try{const r=compileClient();rmSync(r.directory,{recursive:true,force:true});console.log('Identity client strict TypeScript compilation passed.');}catch{console.error('Identity client strict compilation failed.');process.exitCode=1;}}
