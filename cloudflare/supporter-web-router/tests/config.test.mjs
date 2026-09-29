import {test,before,after} from 'node:test';import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,rmSync} from 'node:fs';import {tmpdir} from 'node:os';import {join} from 'node:path';import {fileURLToPath,pathToFileURL} from 'node:url';import {spawnSync} from 'node:child_process';
import {validateRouterTemplate} from '../scripts/validate-config.mjs';
const template=JSON.parse(readFileSync(new URL('../wrangler.staging.jsonc',import.meta.url),'utf8'));let parse,dir;
before(async()=>{dir=mkdtempSync(join(tmpdir(),'portal-config-'));const path=fileURLToPath(new URL('../../../apps/rayon_sports/web/src/lib/browser-portal-config.ts',import.meta.url));
 const r=spawnSync('tsc',['--strict','--target','ES2022','--module','commonjs','--outDir',dir,path],{encoding:'utf8'});assert.equal(r.status,0,r.stdout+r.stderr);({parseBrowserPortalConfig:parse}=await import(pathToFileURL(join(dir,'browser-portal-config.js'))));});
after(()=>rmSync(dir,{recursive:true,force:true}));
const env=()=>({AFRICLUB_BROWSER_PORTAL_MODE:'cookie-v1',AFRICLUB_BROWSER_PORTAL_ORIGIN:'https://browser.example.invalid',AFRICLUB_BROWSER_PORTAL_CLUB_ID:'24'});
test('absent or explicit legacy mode preserves the existing surface',()=>{assert.equal(parse({},24,null),null);assert.equal(parse({AFRICLUB_BROWSER_PORTAL_MODE:'legacy'},24,null),null);});
test('cookie mode requires exact host and club',()=>{assert.deepEqual(parse(env(),24,'browser.example.invalid'),{origin:'https://browser.example.invalid',clubId:24});});
for(const [name,key,value] of [ ['unknown mode','AFRICLUB_BROWSER_PORTAL_MODE','cookie'],['http','AFRICLUB_BROWSER_PORTAL_ORIGIN','http://browser.example.invalid'],['path','AFRICLUB_BROWSER_PORTAL_ORIGIN','https://browser.example.invalid/path'],['wrong club','AFRICLUB_BROWSER_PORTAL_CLUB_ID','25'],['missing origin','AFRICLUB_BROWSER_PORTAL_ORIGIN',''],['leading zero club','AFRICLUB_BROWSER_PORTAL_CLUB_ID','024'],['credential URL','AFRICLUB_BROWSER_PORTAL_ORIGIN','https://user:pass@browser.example.invalid'] ]){
 test('enabled mode refuses '+name+' without a legacy fallback',()=>{const e=env();e[key]=value;assert.throws(()=>parse(e,24,'browser.example.invalid'));});}
test('a spoofed host cannot render enabled portal',()=>{assert.throws(()=>parse(env(),24,'other.invalid'));});
test('shipped router config remains disabled and capability limited',()=>{assert.equal(validateRouterTemplate(template).deploymentAuthorized,false);});
for(const key of ['d1_databases','queues','kv_namespaces','r2_buckets','triggers'])test('router template refuses '+key,()=>{assert.throws(()=>validateRouterTemplate({...template,[key]:[]}));});
test('router template rejects enablement or public preview',()=>{assert.throws(()=>validateRouterTemplate({...template,workers_dev:true}));assert.throws(()=>validateRouterTemplate({...template,vars:{...template.vars,WEB_ROUTER_ENABLED:'true'}}));});

for(const [label,mutate] of [
 ['extra env authority',c=>c.vars.PAYMENT_PROVIDER_ENABLED='true'],
 ['private RPC entrypoint',c=>c.services[0].entrypoint='PaymentAllocator'],
 ['blank service',c=>c.services[0].service=''],
 ['analytics binding',c=>c.analytics_engine_datasets=[{binding:'LOG_PRIVATE'}]],
 ['unsafe service value',c=>c.services[0].service='https://foreign.example.invalid'],
 ['live account',c=>c.account_id='1'.repeat(32)]
])test('router template rejects unreviewed capability '+label,()=>{
 const c=structuredClone(template);mutate(c);assert.throws(()=>validateRouterTemplate(c));
});
