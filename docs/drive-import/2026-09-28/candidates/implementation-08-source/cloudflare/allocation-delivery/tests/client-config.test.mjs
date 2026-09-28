import test from 'node:test';import assert from 'node:assert/strict';
import {mkdtempSync,rmSync,readFileSync} from 'node:fs';import {tmpdir} from 'node:os';import {join} from 'node:path';import {spawnSync} from 'node:child_process';import {pathToFileURL} from 'node:url';
import {fixture,claimed} from './fixture.mjs';import {drain} from '../src/dispatcher.mjs';import {validate} from '../scripts/check-deployment.mjs';
const dir=mkdtempSync(join(tmpdir(),'africlub-review-client-'));
const compiled=spawnSync('tsc',[new URL('../review-client.ts',import.meta.url).pathname,'--strict','--target','ES2022','--module','NodeNext','--moduleResolution','NodeNext','--outDir',dir],{encoding:'utf8'});
assert.equal(compiled.status,0,compiled.stdout+compiled.stderr);
const {DeliveryReviewClient}=await import(pathToFileURL(join(dir,'review-client.js')));
process.on('exit',()=>rmSync(dir,{recursive:true,force:true}));
async function use(t,fn){const f=await fixture();t.after(()=>f.close());return fn(f);}
for(const kind of ['source','inbox','dispatch'])test(`disabled ${kind} template has no public route or schedule`,()=>{
 const cfg=JSON.parse(readFileSync(new URL(`../wrangler.${kind}.staging.jsonc`,import.meta.url),'utf8'));assert.deepEqual(validate(cfg,kind),[]);
 for(const change of [{workers_dev:true},{preview_urls:true},{routes:['*/*']},{triggers:{crons:['* * * * *']}},{r2_buckets:[]}])assert.ok(validate({...cfg,...change},kind).length);
});
test('dispatcher refuses database and review capabilities in template',()=>{
 const cfg=JSON.parse(readFileSync(new URL('../wrangler.dispatch.staging.jsonc',import.meta.url),'utf8'));
 assert.ok(validate({...cfg,d1_databases:[{binding:'DB'}]},'dispatch').length);
 assert.ok(validate({...cfg,services:[{binding:'SOURCE',entrypoint:'AllocationDeliveryReview'},{binding:'INBOX',entrypoint:'AllocationEventInbox'}]},'dispatch').length);
});
test('compiled review client reads actual service and health without creating commands',t=>use(t,async f=>{
 const c=new DeliveryReviewClient(f.review);assert.equal(f.count('pa_delivery_commands'),0);
 assert.deepEqual((await c.inspect(24,'dead')).items,[]);const h=await c.health(24);assert.equal(h.counts.dead,0);assert.equal(h.capped,false);
 assert.equal(f.count('pa_delivery_commands'),0);
 await drain(f.runner);assert.equal((await c.inspect(24,'delivered')).items.length,1);
 assert.equal((await c.health(24)).counts.delivered,1);
}));
test('compiled redrive explicitly retries original identity after lost acknowledgement',t=>use(t,async f=>{
 const {claim}=await claimed(f);await f.source.finish({clubId:24,eventId:claim.eventId,leaseId:claim.leaseId,expectedRevision:claim.revision,requestId:crypto.randomUUID(),outcome:'dead',reason:'invalid_event',receiptId:null});
 let calls=0;const c=new DeliveryReviewClient({health:x=>f.review.health(x),inspect:x=>f.review.inspect(x),redrive:async x=>{calls++;const r=await f.review.redrive(x);if(calls===1)throw Error('reply lost');return r;}});
 const input={clubId:24,eventId:claim.eventId,expectedRevision:claim.revision+1,requestId:crypto.randomUUID(),reason:'configuration_corrected'};
 await assert.rejects(()=>c.redrive(input),e=>e.code==='write_outcome_unknown');assert.equal(calls,1);
 const r=await c.redrive(input);assert.equal(r.operationId,input.requestId);assert.equal(calls,2);
 assert.equal(f.db.sql.prepare("SELECT count(*) n FROM pa_delivery_commands WHERE action='redrive'").get().n,1);
}));
for(const [name,patch] of [['wrong club',{clubId:25}],['unsupported version',{schemaVersion:2}],['invented snapshot',{snapshot:true}],['extra fields',{private:'do not leak'}]])
 test(`compiled page rejects ${name}`,t=>use(t,async f=>{
 const client=new DeliveryReviewClient({inspect:async x=>({...await f.review.inspect(x),...patch})});
 await assert.rejects(()=>client.inspect(24,'dead'),e=>e.code==='invalid_response');
}));
test('compiled health rejects uncapped oversized counts',t=>use(t,async f=>{
 const client=new DeliveryReviewClient({health:async x=>{const h=await f.review.health(x);h.counts.pending=1001;return h;}});
 await assert.rejects(()=>client.health(24),e=>e.code==='invalid_response');
}));
test('receiver private Worker wrappers expose no HTTP business methods',()=>{
 for(const name of ['source','inbox','dispatch']){
  const text=readFileSync(new URL(`../src/${name}-worker.mjs`,import.meta.url),'utf8');
  assert.ok(text.includes('status:404'));assert.ok(text.includes('fetch'));assert.ok(!text.includes('request.json'));
 }
});
test('source consumer and attempt ceilings cannot silently change after adoption',t=>use(t,async f=>{
 await f.source.take({clubId:24});
 assert.throws(()=>f.db.sql.prepare('UPDATE pa_delivery_control SET consumer_id=? WHERE club_id=24').run(crypto.randomUUID()));
 assert.throws(()=>f.db.sql.exec('UPDATE pa_delivery_control SET max_attempts=2 WHERE club_id=24'));
 f.db.sql.exec('UPDATE pa_delivery_control SET enabled=0 WHERE club_id=24');
 await assert.rejects(()=>f.source.take({clubId:24}));
}));
test('failed job projection rolls back its immutable command as well',t=>use(t,async f=>{
 f.db.sql.exec("CREATE TRIGGER synthetic_job_failure AFTER INSERT ON pa_delivery_jobs BEGIN SELECT RAISE(ABORT,'synthetic failure'); END;");
 await assert.rejects(()=>f.source.take({clubId:24}));assert.equal(f.count('pa_delivery_commands'),0);assert.equal(f.count('pa_delivery_jobs'),0);
}));
test('failed source acknowledgement does not undo sink effect or duplicate it on recovery',t=>use(t,async f=>{
 f.db.sql.exec("CREATE TRIGGER synthetic_ack_failure AFTER UPDATE ON pa_delivery_jobs WHEN NEW.state='delivered' BEGIN SELECT RAISE(ABORT,'synthetic failure'); END;");
 assert.equal((await drain(f.runner)).unknown,1);assert.equal(f.count('pa_delivery_commands'),2);
 assert.equal(f.sinkDb.sql.prepare('SELECT count(*) n FROM adi_events').get().n,1);
 f.db.sql.exec('DROP TRIGGER synthetic_ack_failure');f.advance(10000);await drain(f.runner);f.advance(1000);
 assert.equal((await drain(f.runner)).stored,1);assert.equal(f.sinkDb.sql.prepare('SELECT count(*) n FROM adi_events').get().n,1);
}));
