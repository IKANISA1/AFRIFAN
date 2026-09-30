import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,rmSync} from 'node:fs';
import {join} from 'node:path';import {tmpdir} from 'node:os';import {pathToFileURL} from 'node:url';
import {UI_ASSETS} from '../src/ui-assets.mjs';import {writeFileSync} from 'node:fs';
import {PublicationController,recoveryRecord} from '../ui/controller.mjs';
import {fixture,imported} from './support/fixture.mjs';import gateway from '../src/index.mjs';
const dir=mkdtempSync(join(tmpdir(),'africlub-client-test-'));writeFileSync(join(dir,'client.mjs'),UI_ASSETS['client.js']);
const {OperatorPublicationClient}=await import(pathToFileURL(join(dir,'client.mjs')));process.on('exit',()=>rmSync(dir,{recursive:true,force:true}));
class Storage{map=new Map();reject=false;getItem(k){return this.map.get(k)??null;}setItem(k,v){if(this.reject)throw Error('storage denied');this.map.set(k,v);}removeItem(k){this.map.delete(k);}}
class Locks{held=new Set();async request(k,options,fn){if(this.held.has(k))return fn(null);this.held.add(k);try{return await fn({name:k});}finally{this.held.delete(k);}}}
function harness(t,{storage=new Storage(),locks=new Locks()}={}){
 const f=fixture(t),log=[];let lose=false,readFail=false;const fetcher=async(url,init)=>{log.push({url,init});if(readFail&&url.endsWith('/head'))throw Error('offline');
   const headers=new Headers(init.headers);if(init.method==='POST')headers.set('origin',f.httpEnv.OPERATOR_API_ORIGIN);
   const res=await gateway.fetch(new Request(url,{...init,headers}),f.httpEnv,f.ctx);
   if(lose&&url.endsWith('/publications')&&init.method==='POST'){lose=false;throw Error('lost after commit');}return res;};
 const client=new OperatorPublicationClient(f.httpEnv.OPERATOR_API_ORIGIN,fetcher);
 const make=()=>new PublicationController(client,24,{storage,locks,now:()=>f.clock.now,wallNow:()=>f.clock.now});
 return {...f,client,storage,locks,log,make,controller:make(),lose(){lose=true;},failHead(){readFail=true;}};
}
async function ready(h){const s=await imported(h);const c=h.controller;await c.init();await c.inspect(s.id);await c.review('editorial:synthetic');assert.equal(c.state.phase,'reviewed',c.state.error);return {c,s,p:c.state.pending};}
function confirmation(c){return {acknowledged:true,confirmation:c.confirmationText};}
test('initialization and inspection never write a review or publication',async t=>{const h=harness(t),s=await imported(h);await h.controller.init();await h.controller.inspect(s.id);assert.equal(h.controller.state.phase,'inspect');assert.equal(h.log.filter(x=>x.init.method==='POST').length,0);});
test('review persists only exact recovery identifiers, never evidence, tokens or content',async t=>{const h=harness(t),{c,p}=await ready(h);const raw=h.storage.getItem(c.localKey);assert.ok(!raw.includes('editorial'));assert.ok(!raw.includes('Synthetic'));assert.equal(p.phase,'reviewed');assert.equal(h.sql('SELECT COUNT(*) n FROM public_operator_publications')[0].n,0);});
test('missing acknowledgement and wrong phrase cannot confirm',async t=>{const h=harness(t),{c}=await ready(h);await c.confirm();assert.equal(c.state.error,'explicit_confirmation_required');await c.confirm({acknowledged:true,confirmation:'PUBLISH something'});assert.equal(c.state.error,'explicit_confirmation_required');assert.equal(h.log.filter(x=>x.init.method==='POST'&&x.url.endsWith('/publications')).length,0);});
test('confirmation persists unknown marker before the request and records the receipt',async t=>{const h=harness(t),{c,p}=await ready(h);const original=h.client.confirm.bind(h.client);h.client.confirm=async(...args)=>{assert.equal(JSON.parse(h.storage.getItem(c.localKey)).phase,'unknown');return original(...args);};await c.confirm(confirmation(c));assert.equal(c.state.phase,'published',c.state.error);assert.equal(c.state.receipt.snapshotId,p.snapshotId);assert.equal(h.sql('SELECT COUNT(*) n FROM public_operator_publications')[0].n,1);});
test('rapid duplicate confirmation is one write and one receipt',async t=>{const h=harness(t),{c}=await ready(h),a=confirmation(c);await Promise.all([c.confirm(a),c.confirm(a)]);assert.equal(h.sql('SELECT COUNT(*) n FROM public_operator_publications')[0].n,1);assert.equal(h.log.filter(x=>x.init.method==='POST'&&x.url.endsWith('/publications')).length,1);});
test('response loss stays unknown and reload recovers by GET only',async t=>{const h=harness(t),{c,p}=await ready(h);h.lose();await c.confirm(confirmation(c));assert.equal(c.state.phase,'unknown');assert.equal(c.state.pending.key,p.key);const writes=h.log.filter(x=>x.init.method==='POST').length;const second=h.make();await second.init();assert.equal(second.state.phase,'published',second.state.error);assert.equal(h.log.filter(x=>x.init.method==='POST').length,writes);assert.equal(second.state.pending.key,p.key);});
test('failed confirmation does not allow reset or fresh key',async t=>{const h=harness(t),{c,p}=await ready(h);h.client.confirm=async()=>{throw Error('network failure before unknown response');};await c.confirm(confirmation(c));assert.equal(c.state.phase,'unknown');await c.reset();assert.equal(c.state.error,'unknown_outcome_unresolved');assert.equal(c.state.pending.key,p.key);});
test('explicit retry of an uncertain operation uses the same review and key',async t=>{const h=harness(t),{c,p}=await ready(h);const original=h.client.confirm.bind(h.client);h.client.confirm=async()=>{throw Error('offline');};await c.confirm(confirmation(c));h.client.confirm=original;await c.confirm(confirmation(c));assert.equal(c.state.phase,'published',c.state.error);assert.equal(c.state.pending.key,p.key);assert.equal(c.state.receipt.reviewId,p.reviewId);});
test('storage failure before confirmation causes zero publication calls',async t=>{const h=harness(t),{c}=await ready(h);h.storage.reject=true;await c.confirm(confirmation(c));assert.equal(c.state.error,'local_recovery_unavailable');assert.equal(h.log.filter(x=>x.init.method==='POST'&&x.url.endsWith('/publications')).length,0);});
test('storage failure after commit retains confirmed receipt and supports read recovery',async t=>{const h=harness(t),{c}=await ready(h);const original=h.client.confirm.bind(h.client);h.client.confirm=async(...a)=>{const res=await original(...a);h.storage.reject=true;return res;};await c.confirm(confirmation(c));assert.equal(c.state.phase,'published');assert.ok(c.state.receipt);h.storage.reject=false;const other=h.make();await other.init();assert.equal(other.state.phase,'published',other.state.error);});
test('an expired unsent review cannot confirm',async t=>{const h=harness(t),{c}=await ready(h);h.clock.now+=6*60000;await c.confirm(confirmation(c));assert.equal(c.state.error,'review_expired');assert.equal(h.log.filter(x=>x.init.method==='POST'&&x.url.endsWith('/publications')).length,0);});
test('revocation during the interaction blocks confirmation',async t=>{const h=harness(t),{c}=await ready(h);h.db.sqlite.exec('UPDATE public_operator_grants SET enabled=0');await c.confirm(confirmation(c));assert.equal(c.state.error,'operator_not_authorized');assert.equal(h.sql('SELECT COUNT(*) n FROM public_operator_publications')[0].n,0);});
test('changed published head cannot silently retarget a review',async t=>{const h=harness(t),{c}=await ready(h),other=await imported(h,{title:'Other import'}),r=await h.review(other);await h.publish(r);await c.confirm(confirmation(c));assert.equal(c.state.error,'publication_conflict');assert.equal(h.sql('SELECT COUNT(*) n FROM public_operator_publications')[0].n,1);});
test('other tab lock denies mutation without replacing local record',async t=>{const h=harness(t),{c,p}=await ready(h);h.locks.held.add(c.localKey);await c.confirm(confirmation(c));assert.equal(c.state.error,'another_tab_busy');assert.equal(c.state.pending.key,p.key);});
test('a second tab loads the existing review without creating another',async t=>{const h=harness(t),{p}=await ready(h),other=h.make();await other.init();assert.equal(other.state.pending.reviewId,p.reviewId);assert.equal(h.sql('SELECT COUNT(*) n FROM public_operator_reviews')[0].n,1);});
test('leaving an unsent review removes only local recovery, preserving audit',async t=>{const h=harness(t),{c}=await ready(h);await c.reset();assert.equal(c.state.phase,'select',c.state.error);assert.equal(h.storage.getItem(c.localKey),null);assert.equal(h.sql('SELECT COUNT(*) n FROM public_operator_reviews')[0].n,1);});
test('current head read failure never erases a confirmed receipt',async t=>{const h=harness(t),{c}=await ready(h);const original=h.client.confirm.bind(h.client);h.client.confirm=async(...a)=>{const x=await original(...a);h.failHead();return x;};await c.confirm(confirmation(c));assert.equal(c.state.phase,'published');assert.equal(c.state.currentHeadUnavailable,true);assert.ok(c.state.receipt);});
test('wrong snapshot in confirmation response is not accepted as success',async t=>{const h=harness(t),{c}=await ready(h);h.client.confirm=async()=>({reviewId:c.state.pending.reviewId,snapshotId:'f'.repeat(64),previousSnapshotId:null,clubId:24});await c.confirm(confirmation(c));assert.equal(c.state.error,'recovery_mismatch');assert.equal(c.state.phase,'unknown');});
test('storage is isolated by verified operator and club scope',async t=>{const h=harness(t),{c,p}=await ready(h);assert.throws(()=>recoveryRecord(JSON.stringify(p),'f'.repeat(64),24),/local_recovery_corrupt/);assert.throws(()=>recoveryRecord(JSON.stringify(p),c.state.session.scopeKey,26),/local_recovery_corrupt/);});
for(const raw of ['null','[]','{','{}','{"version":1,"phase":"published"}'])test(`corrupted storage is not accepted: ${raw}`,()=>{assert.throws(()=>recoveryRecord(raw,'a'.repeat(64),24),/local_recovery_corrupt/);});
test('no cross-tab locking support means no new review',async t=>{const h=harness(t,{locks:{}}),s=await imported(h),c=h.controller;await c.init();await c.inspect(s.id);await c.review('editorial:synthetic');assert.equal(c.state.canMutate,false);assert.equal(h.sql('SELECT COUNT(*) n FROM public_operator_reviews')[0].n,0);});

// Reauthentication can change the operator without a browser reload.
test('reinitialization clears previous private display before identity resolves',async t=>{
 const h=harness(t),{c,p}=await ready(h);const key=c.localKey;let resume;
 h.client.session=()=>new Promise(resolve=>{resume=resolve;});
 const loading=c.init();await Promise.resolve();
 for(const name of ['candidate','review','preview','receipt','pending','session','head'])assert.equal(c.state[name],null,name);
 assert.equal(c.state.canMutate,false);assert.ok(h.storage.getItem(key));
 resume({clubId:24,clubSlug:'rayon_sports_rw',scopeKey:'f'.repeat(64),canReview:false,canPublish:false,serverNow:new Date(h.clock.now).toISOString(),grantExpiresAt:new Date(h.clock.now+10000).toISOString()});
 await loading;assert.equal(c.state.pending,null);assert.equal(c.state.phase,'select');assert.equal(JSON.parse(h.storage.getItem(key)).reviewId,p.reviewId);
});

test('a failed new inspection does not leave the prior candidate on screen',async t=>{
 const h=harness(t),s=await imported(h),c=h.controller;await c.init();await c.inspect(s.id);assert.ok(c.state.candidate);
 await c.inspect('f'.repeat(64));assert.equal(c.state.error,'snapshot_not_found');assert.equal(c.state.candidate,null);assert.equal(c.state.phase,'select');
});
test('an active snapshot cannot create another review through exact-ID inspection',async t=>{
 const h=harness(t),s=await imported(h),r=await h.review(s);await h.publish(r);const c=h.controller;
 await c.init();await c.inspect(s.id);await c.review('editorial:synthetic');assert.equal(c.state.error,'snapshot_not_reviewable');assert.equal(h.sql('SELECT COUNT(*) n FROM public_operator_reviews')[0].n,1);
});
test('post-commit grant loss returns 403 without declaring the publication uncommitted',async t=>{
 const h=harness(t),s=await imported(h),r=await h.review(s);const batch=h.db.batch.bind(h.db);
 h.db.batch=async statements=>{await batch(statements);h.db.sqlite.exec('UPDATE public_operator_grants SET enabled=0');throw Error('synthetic response lost after commit and revocation');};
 await assert.rejects(h.client.confirm(24,r.reviewId,'request_key_post_commit_1234'),e=>e.status===403&&e.mayHaveCommitted);
 assert.equal(h.sql('SELECT COUNT(*) n FROM public_operator_publications')[0].n,1);
});
test('identity change during action clears private display and preserves original scoped recovery',async t=>{
 const h=harness(t),{c,p}=await ready(h),key=c.localKey;
 h.client.session=async()=>({...c.state.session,scopeKey:'f'.repeat(64)});
 await c.checkResult();assert.equal(c.state.error,'operator_identity_changed');assert.equal(c.state.canMutate,false);
 for(const name of ['candidate','review','preview','receipt','pending','session','head'])assert.equal(c.state[name],null,name);
 assert.equal(c.state.candidates.length,0);assert.equal(JSON.parse(h.storage.getItem(key)).key,p.key);
});
test('revoked access during result check clears private display without deleting uncertain recovery',async t=>{
 const h=harness(t),{c,p}=await ready(h),key=c.localKey;h.db.sqlite.exec('UPDATE public_operator_grants SET enabled=0');
 await c.checkResult();assert.equal(c.state.error,'operator_not_authorized');assert.equal(c.state.canMutate,false);
 for(const name of ['candidate','review','preview','receipt','pending','session','head'])assert.equal(c.state[name],null,name);
 assert.equal(c.state.candidates.length,0);assert.equal(JSON.parse(h.storage.getItem(key)).key,p.key);
});
