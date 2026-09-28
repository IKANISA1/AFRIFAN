import {mkdtempSync,readFileSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';import {join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';import {execFileSync} from 'node:child_process';
export function compileClient(){const directory=mkdtempSync(join(tmpdir(),'africlub-membership-client-'));
 try{execFileSync('tsc',[fileURLToPath(new URL('../client.ts',import.meta.url)),'--strict','--target','ES2022','--module','ES2022','--moduleResolution','bundler','--lib','ES2022,DOM','--outDir',directory],{stdio:'pipe'});
 const path=join(directory,'client.mjs');writeFileSync(path,readFileSync(join(directory,'client.js')));
 return {url:pathToFileURL(path).href,cleanup(){rmSync(directory,{recursive:true,force:true});}};
 }catch(e){rmSync(directory,{recursive:true,force:true});throw e;}}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){const c=compileClient();c.cleanup();console.log('Native reference client compiled strictly.');}
