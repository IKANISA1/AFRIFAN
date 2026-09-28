import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {checkDeployment} from '../scripts/check-deployment.mjs';
import {prepareEnrollment} from '../scripts/prepare-enrollment.mjs';
import {Database,ACCOUNT,AUD,SUBJECT,PRINCIPAL} from './support/fixture.mjs';
const config=()=>[JSON.parse(readFileSync(new URL('../wrangler.staging.jsonc',import.meta.url))),
 JSON.parse(readFileSync(new URL('../../rayon-public/wrangler.authorized-publisher.staging.jsonc',import.meta.url)))];
test('shipped templates are disabled and do not claim live approval',()=>{const r=checkDeployment(...config());assert.deepEqual(r.failures,[]);assert.equal(r.releaseAuthorized,false);});
for(const [name,edit] of [
 ['public private-publisher ingress',(g,p)=>{p.workers_dev=true}],
 ['wrong RPC entrypoint',g=>{g.services[0].entrypoint='PublicSourcePublisher'}],
 ['assets router',g=>{g.assets={directory:'public'}}],
 ['simulated Access identity',g=>{g.access={dev:{aud:AUD}}}],
 ['unreviewed environment override',g=>{g.env={production:{vars:{OPERATOR_API_ENABLED:'true'}}}}],
 ['enabled shipped template',g=>{g.vars.OPERATOR_API_ENABLED='true'}],
 ['different database',(g,p)=>{p.d1_databases[0].database_id='wrong'}],
 ['publisher public domain',(g,p)=>{p.routes=[{pattern:'example.invalid'}]}],
])test(`deployment checks reject ${name}`,()=>{const c=config();edit(...c);assert.ok(checkDeployment(...c).failures.length)});
test('ready configuration checks names, exact audiences, and origin but not live Access',()=>{
 const [g,p]=config();g.vars={...g.vars,OPERATOR_API_ENABLED:'true',ACCESS_AUD:AUD,ACCESS_ACCOUNT_ID:ACCOUNT,OPERATOR_API_ORIGIN:'https://operator.example.invalid'};
 p.vars={...p.vars,PUBLICATION_ENABLED:'true',ACCESS_AUD:AUD,ACCESS_ACCOUNT_ID:ACCOUNT};g.routes=[{pattern:'operator.example.invalid',custom_domain:true}];
 assert.deepEqual(checkDeployment(g,p,{ready:true}).failures,[]);
 p.vars.ACCESS_AUD='c'.repeat(64);assert.ok(checkDeployment(g,p,{ready:true}).failures.length);
});
const input=()=>({principalId:PRINCIPAL,accessAccountId:ACCOUNT,accessSubject:SUBJECT,clubId:24,clubSlug:'rayon_sports_rw',sourceClubId:'source-24',expiresAt:new Date(Date.now()+3600000).toISOString(),enrollmentRef:'enrollment:synthetic'});
test('enrollment generator produces only disabled rows in real SQLite',t=>{const db=new Database();t.after(()=>db.sqlite.close());db.sqlite.exec(prepareEnrollment(input()));
 for(const table of ['tenants','principals','grants'])assert.equal(db.sqlite.prepare(`SELECT enabled FROM public_operator_${table}`).get().enabled,0);
 const g=db.sqlite.prepare('SELECT * FROM public_operator_grants').get();assert.equal(g.can_review,0);assert.equal(g.can_publish,0);
 assert.throws(()=>db.sqlite.exec(prepareEnrollment(input())),/UNIQUE/);
});
for(const [name,patch] of [['caller grants',{can_publish:1}],['SQL-shaped tenant',{sourceClubId:"x'); DROP TABLE anything;--"}],['expired',{expiresAt:'2000-01-01T00:00:00Z'}],['unbounded expiry',{expiresAt:'2099-01-01T00:00:00Z'}],['other club',{clubId:26}],['email identity',{accessSubject:'operator@example.invalid'}]])
 test(`disabled enrollment rejects ${name}`,()=>assert.throws(()=>prepareEnrollment({...input(),...patch})));
