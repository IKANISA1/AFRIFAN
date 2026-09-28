import {mkdtempSync,readFileSync,writeFileSync,rmSync} from 'node:fs';import {tmpdir} from 'node:os';import {join} from 'node:path';import {fileURLToPath,pathToFileURL} from 'node:url';import {execFileSync} from 'node:child_process';
export function compileCheckoutClient(){const directory=mkdtempSync(join(tmpdir(),'africlub-checkout-ts-'));try{
 execFileSync('tsc',[fileURLToPath(new URL('../checkout-client.ts',import.meta.url)),'--strict','--target','ES2022','--module','ES2022','--moduleResolution','bundler','--lib','ES2022,DOM','--outDir',directory],{stdio:'pipe'});
 const file=join(directory,'checkout-client.mjs');writeFileSync(file,readFileSync(join(directory,'checkout-client.js')));
 return {url:pathToFileURL(file).href,cleanup(){rmSync(directory,{recursive:true,force:true});}};
 }catch(error){rmSync(directory,{recursive:true,force:true});throw error;}}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){const c=compileCheckoutClient();c.cleanup();console.log('Checkout reference client compiled strictly.');}
