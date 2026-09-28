#!/usr/bin/env node
/** Replay an exported public snapshot in an isolated disposable SQLite copy.
 * Uses a local file-backed R2 test double; never contacts or changes Cloudflare.
 * Approval identity here is explicitly synthetic and never written to source.
 */
import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, extname } from 'node:path';
import { spawnSync } from 'node:child_process';
import worker from '../../cloudflare/rayon-public/src/index.mjs';
import { sha256, publishSnapshot } from '../../cloudflare/rayon-public/src/snapshot-publication.mjs';
import { D1Adapter } from '../../cloudflare/rayon-public/tests/support/d1-sqlite-adapter.mjs';

const args = process.argv.slice(2);
function arg(name) { const at=args.indexOf(name); if(at<0||!args[at+1])throw new Error(`Required: ${name}`);return resolve(args[at+1]); }
let directory,db;
try {
  const source=arg('--database'), mediaDir=arg('--media-dir');
  const before=await sha256(readFileSync(source));directory=mkdtempSync(join(tmpdir(),'africlub-public-replay-'));
  const target=join(directory,'copy.sqlite');
  const copy=spawnSync('python3',['-c',
    'import sqlite3,sys,pathlib; a=sqlite3.connect(pathlib.Path(sys.argv[1]).resolve().as_uri()+"?mode=ro",uri=True); b=sqlite3.connect(sys.argv[2]); a.backup(b); b.close(); a.close()',source,target],{encoding:'utf8'});
  assert.equal(copy.status,0,`Local SQLite backup failed: ${copy.stderr}`);
  db=new D1Adapter(target,{migrate:false});
  const snapshots=db.sqlite.prepare('SELECT snapshot_id FROM public_snapshots ORDER BY captured_at_utc DESC').all();
  assert.equal(snapshots.length,1,'Replay requires one unambiguous imported snapshot');const id=snapshots[0].snapshot_id;
  const objects=JSON.parse(readFileSync(join(mediaDir,'manifest.json'),'utf8')).objects;
  const byKey=new Map(objects.map(item=>[`assets/${item.sha256}.bin`,item]));
  const bucket={async get(key){const item=byKey.get(key);if(!item)return null;
    const path=resolve(mediaDir,item.file);assert.ok(path.startsWith(resolve(mediaDir)+'/'),'Media path escapes export');
    const data=readFileSync(path);return{size:data.length,async arrayBuffer(){return data.buffer.slice(data.byteOffset,data.byteOffset+data.length);},
      writeHttpMetadata(h){h.set('content-type',({'.svg':'image/svg+xml','.jpg':'image/jpeg','.jpeg':'image/jpeg','.png':'image/png','.webp':'image/webp','.avif':'image/avif'})[extname(item.source_path).toLowerCase()] ?? 'application/octet-stream');}};
  }};
  await publishSnapshot(db,bucket,{snapshotId:id,approvedBy:'synthetic:local-replay',approvalRef:'synthetic:test-only',expectedPreviousId:null});
  const invoke=(route,method='GET')=>worker.fetch(new Request(`https://local-replay.invalid/v1/public/rayon/${route}`,{method}),
    {RAYON_PUBLIC_DB:db,RAYON_PUBLIC_MEDIA:bucket});
  const counts={};
  for(const route of ['fixtures','news','squad','fanclubs','partners','shop','tickets','membership-tiers','predict-pools']) {
    const response=await invoke(route);assert.equal(response.status,200,route);const body=await response.json();
    assert.equal(body.snapshotId,id);assert.equal(body.schemaVersion,1);assert.ok(Array.isArray(body.rows));counts[route]=body.rows.length;
    for(const row of body.rows) {
      for(const forbidden of ['payload_json','buyer_phone','leader_contact_public'])assert.equal(Object.hasOwn(row,forbidden),false);
      for(const flag of ['predictionEntryEnabled','checkoutEnabled','paidTicketIssuanceEnabled','purchaseEnabled','entryEnabled'])
        if(Object.hasOwn(row,flag))assert.equal(row[flag],false);
    }
  }
  let published=0,withheld=0;
  for(const item of objects){const response=await invoke(`media/${item.source_id}?snapshot=${id}`);
    if(/generated|pending|review-before-commercial-reuse|unverified/i.test(item.usage_rights)) {assert.equal(response.status,404);withheld++;}
    else {assert.equal(response.status,200);assert.equal(await sha256(await response.arrayBuffer()),item.sha256);published++;}}
  assert.equal((await invoke('news','POST')).status,405);assert.equal((await invoke('unknown')).status,404);
  assert.equal(await sha256(readFileSync(source)),before,'Source database was changed');
  console.log(JSON.stringify({passed:true,snapshotId:id,scope:'isolated SQLite and file-backed R2 test double; actual saved public export',
    sourceRows:db.sqlite.prepare('SELECT COUNT(*) AS n FROM public_snapshot_records').get().n,
    mediaOriginals:objects.length,mediaServedWithExactHashes:published,rightsWithheld:withheld,routes:counts,
    sourceDatabaseUnchanged:true,remoteCalls:false,productionApproval:false},null,2));
} catch(error){console.error(error.message);process.exitCode=1;}
finally {if(db)db.sqlite.close();if(directory)rmSync(directory,{recursive:true,force:true});}
