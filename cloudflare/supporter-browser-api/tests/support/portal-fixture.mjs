import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';import {tmpdir} from 'node:os';
import {join} from 'node:path';import {fileURLToPath,pathToFileURL} from 'node:url';import {spawnSync} from 'node:child_process';
import {withPayments,ORIGIN} from './fixture.mjs';import {createBrowserGateway} from '../../src/index.mjs';
const dir=mkdtempSync(join(tmpdir(),'africlub-portal-'));
const files=['client.ts','portal-controller.ts','browser-platform.ts'].map(f=>fileURLToPath(new URL('../../'+f,import.meta.url)));
const r=spawnSync('tsc',['--strict','--target','ES2022','--module','commonjs','--moduleResolution','node','--lib','ES2022,DOM','--outDir',dir,...files],{encoding:'utf8',timeout:30000});
assert.equal(r.status,0,r.stdout+r.stderr);
export const {BrowserMemberClient,BrowserClientError}=await import(pathToFileURL(join(dir,'client.js')));
export const {MembershipPortalController}=await import(pathToFileURL(join(dir,'portal-controller.js')));
export const {checkPrivateCacheBoundary}=await import(pathToFileURL(join(dir,'browser-platform.js')));
process.on('exit',()=>rmSync(dir,{recursive:true,force:true}));
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
