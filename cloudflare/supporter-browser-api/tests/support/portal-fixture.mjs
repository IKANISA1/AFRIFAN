import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';import {tmpdir} from 'node:os';
import {join} from 'node:path';import {fileURLToPath,pathToFileURL} from 'node:url';import {spawn} from 'node:child_process';
import {withPayments,ORIGIN} from './fixture.mjs';import {createBrowserGateway} from '../../src/index.mjs';
async function compileStrictTypeScript(args,setupTimeoutMs){
 const detached=process.platform!=='win32';
 const child=spawn(process.execPath,args,{detached,stdio:['ignore','pipe','pipe']});
 let diagnostics='',truncated=false,timedOut=false,launchError;
 const stop=()=>{if(!child.pid)return;try{if(detached)process.kill(-child.pid,'SIGKILL');else child.kill('SIGKILL');}
  catch(error){if(error.code!=='ESRCH')child.kill('SIGKILL');}};
 const onInterrupt=()=>{stop();process.exit(130);},onTerminate=()=>{stop();process.exit(143);};
 process.once('exit',stop);process.once('SIGINT',onInterrupt);process.once('SIGTERM',onTerminate);
 const timer=setTimeout(()=>{timedOut=true;stop();},setupTimeoutMs);
 const append=chunk=>{const value=chunk.toString('utf8'),remaining=1048576-diagnostics.length;
  diagnostics+=value.slice(0,Math.max(0,remaining));if(value.length>remaining)truncated=true;};
 child.stdout.on('data',append);child.stderr.on('data',append);
 try{
  const {status,signal}=await new Promise(resolve=>{
   child.once('error',error=>{launchError=error;});
   child.once('close',(status,signal)=>resolve({status,signal}));
  });
  if(timedOut)throw new Error(`compiler_timeout: portal fixture strict TypeScript setup exceeded ${setupTimeoutMs}ms`);
  if(launchError)throw new Error(`compiler_launch_error: ${launchError.code??'unknown'}`,{cause:launchError});
  assert.equal(status,0,`compiler_error: portal fixture strict TypeScript setup failed (signal=${signal??'none'})\n${diagnostics}${truncated?'\n[compiler diagnostics truncated]':''}`);
 }finally{
  clearTimeout(timer);stop();process.removeListener('exit',stop);
  process.removeListener('SIGINT',onInterrupt);process.removeListener('SIGTERM',onTerminate);
 }
}
const dir=mkdtempSync(join(tmpdir(),'africlub-portal-'));
process.on('exit',()=>rmSync(dir,{recursive:true,force:true}));
const files=['client.ts','portal-controller.ts','browser-platform.ts'].map(f=>fileURLToPath(new URL('../../'+f,import.meta.url)));
const compiler=fileURLToPath(new URL('../../../../apps/rayon_sports/web/node_modules/typescript/bin/tsc',import.meta.url));
// This setup budget covers compilation under competing test files, separately from request deadlines.
try{await compileStrictTypeScript([compiler,'--strict','--target','ES2022','--module','commonjs','--moduleResolution','node','--lib','ES2022,DOM','--outDir',dir,...files],120000);}
catch(error){rmSync(dir,{recursive:true,force:true});throw error;}
export const {BrowserMemberClient,BrowserClientError}=await import(pathToFileURL(join(dir,'client.js')));
export const {MembershipPortalController}=await import(pathToFileURL(join(dir,'portal-controller.js')));
export const {checkPrivateCacheBoundary}=await import(pathToFileURL(join(dir,'browser-platform.js')));
export async function portalFixture(t){
 const f=await withPayments(t),jar=new Map(),memory=new Map(),calls=[];
 let lock=Promise.resolve();const storage={getItem:k=>memory.get(k)??null,setItem:(k,v)=>memory.set(k,v),removeItem:k=>memory.delete(k),
  async withLock(k,fn){const prior=lock;let release;lock=new Promise(r=>release=r);await prior;try{return await fn();}finally{release();}}};
 const transport=async(url,init)=>{
  calls.push({url,init});const h=new Headers(init.headers);h.set('cf-connecting-ip','203.0.113.21');h.set('sec-fetch-site','same-origin');
  if(init.method==='POST')h.set('origin',ORIGIN);
  if(jar.size)h.set('cookie',[...jar].map(([k,v])=>`${k}=${v}`).join('; '));
  const r=new Request(url,{...init,headers:h});Object.defineProperty(r,'cf',{value:{colo:'TEST'}});
  const response=await createBrowserGateway({clock:()=>f.clock.now}).fetch(r,f.env);
  for(const c of response.headers.getSetCookie()){
   const first=c.split(';')[0],i=first.indexOf('='),name=first.slice(0,i),value=first.slice(i+1);
   if(c.includes('Max-Age=0'))jar.delete(name);else jar.set(name,value);
  }
  return response;
 };
 const make=(patch={})=>new BrowserMemberClient(ORIGIN,24,{rememberLastCheckout:true,fetch:transport,clock:()=>f.clock.now,recoveryStore:storage,...patch});
 const client=make();
 const login=async(c=client)=>{await c.start();const challenge=await c.challenge('+250700000001',f.key());
  const row=f.sql('SELECT * FROM auth_challenges WHERE challenge_id=?',challenge.challengeId)[0];
  const payload=await f.service.vault.open(row.delivery_cipher,`challenge:${challenge.challengeId}`);
  return c.verify(challenge.challengeId,payload.code,f.key());};
 let active=true;const notifications=[];
 const controller=()=>new MembershipPortalController(client,{canCheckout:true,key:f.key,active:()=>active,
  checkCacheBoundary:async()=>true,notifySessionChange:()=>notifications.push('change')});
 return {...f,jar,memory,calls,storage,transport,make,client,login,controller,notifications,setActive:v=>{active=v;}};
}
