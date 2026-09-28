#!/usr/bin/env node
/** Actual saved public export -> disposable local import -> authenticated-path
 * review/confirm using SYNTHETIC runtime Access and file-backed storage.
 * No network, credential, production approval, or source modification.
 */
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,rmSync} from 'node:fs';
import {resolve,join,extname} from 'node:path';
import {tmpdir} from 'node:os';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import {fixture} from '../tests/support/fixture.mjs';
import publicWorker from '../../rayon-public/src/index.mjs';
import {sha256} from '../../rayon-public/src/snapshot-publication.mjs';

const after=[];let temp;
try {
 assert.equal(process.argv.length,3,'Usage: node replay-saved-export.mjs /path/to/private-public-export');
 const source=resolve(process.argv[2]),sourceFile=join(source,'rayon-public-source-rows.json'),mediaDir=join(source,'app-media');
 const before=await sha256(readFileSync(sourceFile));temp=mkdtempSync(join(tmpdir(),'africlub-operator-replay-'));
 const root=fileURLToPath(new URL('../../../',import.meta.url));
 const build=spawnSync('python3',[join(root,'tools/scripts/seed_rayon_public_d1_local.py'),'--source-dir',source,'--output-dir',temp],{encoding:'utf8'});
 assert.equal(build.status,0,`Import preparation failed: ${build.stderr}`);
 const f=fixture({after:fn=>after.push(fn)});f.db.sqlite.exec(readFileSync(join(temp,'seed.sql'),'utf8'));
 const snapshot=f.sql('SELECT snapshot_id,source_club_id FROM public_snapshots');assert.equal(snapshot.length,1);
 f.db.sqlite.prepare('UPDATE public_operator_tenants SET source_club_id=? WHERE club_id=24').run(snapshot[0].source_club_id);
 const objects=JSON.parse(readFileSync(join(mediaDir,'manifest.json'),'utf8')).objects;
 for(const o of objects){const path=resolve(mediaDir,o.file);assert.ok(path.startsWith(mediaDir+'/'));
  const bytes=readFileSync(path);assert.equal(bytes.length,o.bytes);assert.equal(await sha256(bytes),o.sha256);f.blobs.set(`assets/${o.sha256}.bin`,bytes);}
 const head=await f.call('head');assert.equal(head.status,200);assert.equal((await head.json()).data.snapshotId,null);
 const reviewResponse=await f.call('reviews',{body:{snapshotId:snapshot[0].snapshot_id,expectedPreviousId:null,reviewRef:'synthetic:operator-saved-source-replay'}});
 assert.equal(reviewResponse.status,201,await reviewResponse.clone().text());const review=(await reviewResponse.json()).data;
 assert.equal(f.sql('SELECT * FROM public_snapshot_head').length,0);
 const request={body:{reviewId:review.reviewId},headers:{'idempotency-key':'synthetic_saved_replay_001'}};
 const published=await f.call('publications',request);assert.equal(published.status,200,await published.clone().text());const receipt=(await published.json()).data;
 const retry=await f.call('publications',request);assert.equal(retry.status,200);const replay=(await retry.json()).data;
 assert.equal(replay.operationId,receipt.operationId);assert.equal(replay.replayed,true);
 assert.equal(f.sql('SELECT * FROM public_operator_publications').length,1);assert.equal(f.sql("SELECT * FROM public_operator_audit WHERE event_type='snapshot_published'").length,1);
 const routes={};
 const invoke=route=>publicWorker.fetch(new Request(`https://replay.example.invalid/v1/public/rayon/${route}`),f.env);
 for(const name of ['fixtures','news','squad','fanclubs','partners','shop','tickets','membership-tiers','predict-pools']){
  const r=await invoke(name);assert.equal(r.status,200,name);const b=await r.json();assert.equal(b.snapshotId,snapshot[0].snapshot_id);routes[name]=b.rows.length;
  for(const row of b.rows)for(const flag of ['predictionEntryEnabled','checkoutEnabled','paidTicketIssuanceEnabled','purchaseEnabled','entryEnabled'])if(Object.hasOwn(row,flag))assert.equal(row[flag],false);
 }
 let served=0,withheld=0;
 for(const o of objects){const r=await invoke(`media/${o.source_id}?snapshot=${snapshot[0].snapshot_id}`);
  if(/generated|pending|review-before-commercial-reuse|unverified/i.test(o.usage_rights)){assert.equal(r.status,404);withheld++;}
  else {assert.equal(r.status,200);assert.equal(await sha256(await r.arrayBuffer()),o.sha256);served++;}}
 assert.equal(await sha256(readFileSync(sourceFile)),before);
 console.log(JSON.stringify({passed:true,scope:'saved source replay on genuine local SQLite, synthetic Access/RPC and file-backed R2',
  snapshotId:snapshot[0].snapshot_id,sourceRows:review.rowCount,mediaRecords:review.mediaCount,mediaServed:served,rightsWithheld:withheld,routes,
  reviewDidNotPublish:true,explicitConfirmationRequired:true,idempotentRetry:true,publicationReceipts:1,publicationAuditEvents:1,
  sourceBytesUnchanged:true,remoteCalls:false,liveAuthenticationVerified:false,releaseAuthorized:false},null,2));
}catch(error){console.error(error.message);process.exitCode=1;}
finally{for(const fn of after)fn();if(temp)rmSync(temp,{recursive:true,force:true});}
