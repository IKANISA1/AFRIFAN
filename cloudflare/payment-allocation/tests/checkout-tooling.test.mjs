import test from 'node:test';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
import {readFileSync,mkdtempSync,rmSync,writeFileSync,statSync} from 'node:fs';import {tmpdir} from 'node:os';import {join} from 'node:path';import {execFileSync} from 'node:child_process';
import {planCheckoutCatalog} from '../scripts/prepare-checkout-catalog.mjs';import {checkCheckoutDeployment} from '../scripts/check-checkout-deployment.mjs';
import {checkoutFixture,ids,packageId,routeId,checkoutPrincipal,readPrincipal} from './checkout-fixture.mjs';
function source(){return {schemaVersion:1,sourceProject:'synthetic-source',clubs:[{clubId:24,ussdTemplate:'*182*{recipient}*{amount}#'}],packages:[{id:packageId,clubId:24,partnerId:ids.partner,tier:'gold',annualPrice:10000,price:1000,sortOrder:0,isActive:true}],routes:[{id:routeId,clubId:24,partnerId:ids.partner,provider:'mtn',country:'RW',recipient:'123456',isActive:true}]};}
function input(v){const b=Buffer.from(JSON.stringify(v));return [b,createHash('sha256').update(b).digest('hex')];}
const template=()=>JSON.parse(readFileSync(new URL('../wrangler.checkout.staging.jsonc',import.meta.url)));
const allocation=()=>JSON.parse(readFileSync(new URL('../wrangler.staging.jsonc',import.meta.url)));
function ready(){const c=template(),a=allocation();a.account_id=c.account_id='ab'.repeat(16);a.d1_databases[0].database_id=c.d1_databases[0].database_id=crypto.randomUUID();a.vars.PAYMENT_ALLOCATION_ENABLED=c.vars.PAYMENT_ALLOCATION_ENABLED=c.vars.MEMBERSHIP_CHECKOUT_ENABLED='true';a.vars.INGEST_PRINCIPAL_ID=ids.ingest;a.vars.ALLOCATE_PRINCIPAL_ID=ids.allocate;a.vars.READ_PRINCIPAL_ID=ids.read;a.vars.OUTBOX_PRINCIPAL_ID=ids.outbox;c.vars.CHECKOUT_PRINCIPAL_ID=checkoutPrincipal;c.vars.CHECKOUT_READ_PRINCIPAL_ID=readPrincipal;return {c,a};}
test('catalog plan is insert-only, disabled and normalizes provider',async()=>{const p=await planCheckoutCatalog(...input(source()));assert.equal(p.statements.length,3);assert.equal(p.executed,false);assert.equal(p.permissionsGranted,false);assert.ok(p.statements.every(x=>/^INSERT INTO pa_checkout_/.test(x.sql)));assert.equal(p.statements[2].params[3],'mtn_rwanda');assert.ok(p.statements.every(x=>x.sql.includes(',0,?')));});
for(const [name,mutate] of [
 ['duplicate club',s=>s.clubs.push(s.clubs[0])],['duplicate package',s=>s.packages.push(s.packages[0])],['duplicate route',s=>s.routes.push(s.routes[0])],
 ['unknown user field',s=>s.userId=ids.user],['unknown role',s=>s.routes[0].role='admin'],['unknown club',s=>s.packages[0].clubId=999],
 ['invalid package id',s=>s.packages[0].id='bad'],['fraction price',s=>s.packages[0].price=0.4],['negative price',s=>s.packages[0].annualPrice=-1],
 ['overflow price',s=>s.packages[0].price=2147483648],['noncanonical tier',s=>s.packages[0].tier='Gold'],['unknown placeholder',s=>s.clubs[0].ussdTemplate='*{amount}*{phone}#'],
 ['fixed route',s=>s.clubs[0].ussdTemplate='*123#'],['too many clubs',s=>{s.clubs=Array.from({length:6},(_,i)=>({clubId:i+1,ussdTemplate:'*{code}*{amount}#'}));}],
 ['invalid country',s=>s.routes[0].country='Rw'],['recipient injection',s=>s.routes[0].recipient='123*999'],['version drift',s=>s.schemaVersion=2]])
 test(`catalog rejects ${name}`,async()=>{const s=source();mutate(s);await assert.rejects(planCheckoutCatalog(...input(s)));});
test('catalog rejects wrong checksum',async()=>{const [b]=input(source());await assert.rejects(planCheckoutCatalog(b,'00'.repeat(32)),{code:'source_hash_mismatch'});});
test('catalog CLI creates private file and refuses overwrite',()=>{const dir=mkdtempSync(join(tmpdir(),'checkout-plan-'));try{const [b,h]=input(source()),src=join(dir,'source.json'),out=join(dir,'plan.json');writeFileSync(src,b);const script=new URL('../scripts/prepare-checkout-catalog.mjs',import.meta.url);execFileSync('node',[script.pathname,src,out,h]);assert.equal(statSync(out).mode&0o777,0o600);const before=readFileSync(out);assert.throws(()=>execFileSync('node',[script.pathname,src,out,h],{stdio:'pipe'}));assert.deepEqual(readFileSync(out),before);}finally{rmSync(dir,{recursive:true,force:true});}});
test('disabled templates remain disabled and unverified',()=>{const r=checkCheckoutDeployment(template(),allocation());assert.equal(r.enabled,false);assert.equal(r.productionReleaseAuthorized,false);});
test('ready config is same-db staging only and not authorization',()=>{const {c,a}=ready();assert.equal(checkCheckoutDeployment(c,a,{ready:true}).humanAuthenticationVerified,false);});
for(const [name,mutate] of [
 ['public route',c=>c.routes=['public.example/*']],['assets',c=>c.assets={}],['schedule',c=>c.triggers={}],['outgoing service',c=>c.services=[]],
 ['production',c=>c.vars.ALLOCATION_ENVIRONMENT='production'],['different database',c=>c.d1_databases[0].database_id=crypto.randomUUID()],
 ['different account',c=>c.account_id='ff'.repeat(16)],['logging',c=>c.observability.enabled=true],['development ingress',c=>c.workers_dev=true],
 ['wrong entrypoint',c=>c.main='src/worker.mjs'],['allocator principal reused',c=>c.vars.CHECKOUT_PRINCIPAL_ID=ids.allocate],['same principals',c=>c.vars.CHECKOUT_READ_PRINCIPAL_ID=c.vars.CHECKOUT_PRINCIPAL_ID],
 ['new secret variable',c=>c.vars.SECRET='not-allowed'],['override environment',c=>c.env={}],['read switch enabled alone',c=>c.vars.PAYMENT_ALLOCATION_ENABLED='false']])
 test(`ready checker rejects ${name}`,()=>{const {c,a}=ready();mutate(c);assert.throws(()=>checkCheckoutDeployment(c,a,{ready:true}));});
