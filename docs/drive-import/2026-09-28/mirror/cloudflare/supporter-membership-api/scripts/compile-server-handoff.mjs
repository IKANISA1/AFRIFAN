import {mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';import {join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';import {execFileSync} from 'node:child_process';
export function compileServerHandoff(){const directory=mkdtempSync(join(tmpdir(),'africlub-server-handoff-'));
 try{execFileSync('tsc',[fileURLToPath(new URL('../server-handoff.ts',import.meta.url)),
  '--strict','--target','ES2022','--module','ES2022','--moduleResolution','bundler','--lib','ES2022,DOM','--outDir',directory],{stdio:'pipe'});
 writeFileSync(join(directory,'package.json'),JSON.stringify({type:'module'}));
 return {url:pathToFileURL(join(directory,'server-handoff.js')).href,clientUrl:pathToFileURL(join(directory,'client.js')).href,cleanup(){rmSync(directory,{recursive:true,force:true});}};}catch(e){rmSync(directory,{recursive:true,force:true});throw e;}}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){const c=compileServerHandoff();c.cleanup();console.log('Server-backed handoff reference compiled strictly.');}
