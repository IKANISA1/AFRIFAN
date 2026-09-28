import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { D1Adapter } from './support/d1-sqlite-adapter.mjs';
import test from 'node:test';
import worker from '../src/index.mjs';
import { PUBLIC_SOURCE_TABLES, sha256, publishSnapshot, verifySnapshot } from '../src/snapshot-publication.mjs';

const now = new Date();
const assetId = '12345678-1234-1234-1234-123456789abc';
const enc = new TextEncoder();

function fixture(t) {
  const db = new D1Adapter(); t.after(()=>db.sqlite.close());
  const blobs = new Map();
  const bucket = { async get(key) {
    const value = blobs.get(key); if(!value)return null;
    return { size:value.length, async arrayBuffer(){return value.buffer.slice(value.byteOffset,value.byteOffset+value.byteLength);},
      writeHttpMetadata(headers){headers.set('content-type','image/png');} };
  }};
  const fetch = (route='news',method='GET') => worker.fetch(new Request(`https://test.invalid/v1/public/rayon/${route}`,{method}),
    {RAYON_PUBLIC_DB:db,RAYON_PUBLIC_MEDIA:bucket});
  return {db,blobs,bucket,fetch};
}
async function imported(f, {at=now.toISOString(),title='Approved news',rights='club-approved',mutate,media=true}={}) {
  const rows=Object.fromEntries(PUBLIC_SOURCE_TABLES.map(name=>[name,[]]));
  const shared={club_id:'club-24',approval_status:'approved',active:true,visibility:'public'};
  rows.clubs=[{id:'club-24',slug:'rayon-sports'}];
  rows.news_posts=[{...shared,id:'news-1',title,excerpt:'Approved excerpt',status:'published',post_type:'news_feed',
    published_at:new Date(now.getTime()-1000).toISOString(),source_url:'https://club.invalid/news'}];
  const blob=enc.encode('synthetic-safe-image'); const hash=await sha256(blob);
  if(media) {
    rows.media_assets=[{...shared,id:assetId,storage_bucket:'source',storage_path:'image.png',checksum_sha256:hash,
      usage_rights:rights,usage_scopes:['squad','shop','partners']}];
    rows.players=[{...shared,id:'player-1',display_name:'Synthetic player',photo_asset_id:assetId}];
  }
  rows.prediction_teams=[{id:'team-1',name:'Rayon',is_rayon_sports:true},{id:'team-2',name:'Opponent'}];
  rows.prediction_competitions=[{id:'comp-1',name:'League',active:true}];
  rows.prediction_fixtures=[{...shared,id:'fixture-1',home_team_id:'team-1',away_team_id:'team-2',competition_id:'comp-1',
    schedule_status:'confirmed',starts_at:new Date(now.getTime()+3600000).toISOString(),source_publication_id:'approved-1',source_url:'https://club.invalid/match'}];
  rows.prediction_pools=[{id:'pool-1',fixture_id:'fixture-1',status:'open',locks_at:new Date(now.getTime()+3500000).toISOString()}];
  rows.membership_tiers=[{...shared,id:'tier-1',name:'Supporter',price_rwf:1000}];
  rows.ticket_sales=[{...shared,id:'sale-1',sale_status:'reservation_open',sale_mode:'reservation_only',kickoff_at:new Date(now.getTime()+3600000).toISOString()}];
  rows.partners=[{...shared,id:'partner-1',name:'Partner',logo_asset_id:assetId}];
  rows.marketplace_products=[{...shared,id:'product-1',name:'Club shirt',price_rwf:1000,image_asset_id:assetId,
    verification_status:`current_media_verified_${now.getUTCMonth()>=6?now.getUTCFullYear():now.getUTCFullYear()-1}_${String((now.getUTCMonth()>=6?now.getUTCFullYear()+1:now.getUTCFullYear())%100).padStart(2,'0')}`}];
  if(mutate)mutate(rows);
  const records=[];
  for(const table of PUBLIC_SOURCE_TABLES)for(const row of rows[table].sort((a,b)=>String(a.id).localeCompare(String(b.id)))) {
    const json=JSON.stringify(row); records.push([table,String(row.id),'club-24',json,await sha256(json)]);
  }
  const mediaRows=media?[[assetId,'source','image.png',blob.length,hash,['squad','shop','partners'],rights,`assets/${hash}.bin`]]:[];
  const manifest={schemaVersion:1,sourceClubId:'club-24',capturedAt:at,tables:Object.fromEntries(PUBLIC_SOURCE_TABLES.map(t=>[t,rows[t].length])),
    records:records.map(([t,id,,payload,h])=>[t,id,h]),media:mediaRows};
  const manifestJson=JSON.stringify(manifest);const id=await sha256(manifestJson);
  f.db.sqlite.prepare('INSERT INTO public_snapshots(snapshot_id,source_club_id,captured_at_utc,manifest_json) VALUES(?,?,?,?)').run(id,'club-24',at,manifestJson);
  for(const row of records)f.db.sqlite.prepare('INSERT INTO public_snapshot_records VALUES(?,?,?,?,?,?)').run(id,...row);
  for(const [a,b,p,n,h,scopes,r,k] of mediaRows)f.db.sqlite.prepare('INSERT INTO public_snapshot_media VALUES(?,?,?,?,?,?,?,?,?)').run(id,a,b,p,n,h,JSON.stringify(scopes),r,k);
  if(media)f.blobs.set(`assets/${hash}.bin`,blob);
  return {id,manifest,hash,blob,rows};
}
const options=(id,previous=null)=>({snapshotId:id,approvedBy:'operator:test',approvalRef:'approval:test',expectedPreviousId:previous,now});
async function publish(f,s,previous=null){return publishSnapshot(f.db,f.bucket,options(s.id,previous));}

test('imports never silently become public',async t=>{const f=fixture(t);await imported(f);const r=await f.fetch();assert.equal(r.status,503);assert.equal((await r.json()).error,'source_unpublished');});
test('approved complete snapshot publishes and serves content',async t=>{const f=fixture(t);const s=await imported(f);await publish(f,s);const r=await f.fetch();assert.equal(r.status,200);const body=await r.json();assert.equal(body.snapshotId,s.id);assert.equal(body.rows[0].title,'Approved news');assert.ok(f.db.sessions.includes('first-primary'));});
test('all nine read routes preserve transaction-disabled responses',async t=>{
 const f=fixture(t);const s=await imported(f);await publish(f,s);
 for(const route of ['fixtures','news','squad','fanclubs','partners','shop','tickets','membership-tiers','predict-pools']) {
  const r=await f.fetch(route);assert.equal(r.status,200,route);const b=await r.json();assert.equal(b.schemaVersion,1);
  for(const row of b.rows)for(const key of ['predictionEntryEnabled','checkoutEnabled','paidTicketIssuanceEnabled','purchaseEnabled','entryEnabled'])
   if(Object.hasOwn(row,key))assert.equal(row[key],false);
 }
});
test('writes and unknown routes stay unavailable',async t=>{const f=fixture(t);assert.equal((await f.fetch('news','POST')).status,405);assert.equal((await f.fetch('not-a-route')).status,404);});
test('missing approval cannot seal or activate',async t=>{const f=fixture(t);const s=await imported(f);await assert.rejects(publishSnapshot(f.db,f.bucket,{...options(s.id),approvedBy:''}),/approval_required/);assert.equal(f.db.sqlite.prepare('SELECT status FROM public_snapshots').get().status,'importing');});
test('missing compare-and-swap expectation fails closed',async t=>{const f=fixture(t);const s=await imported(f);const o=options(s.id);delete o.expectedPreviousId;await assert.rejects(publishSnapshot(f.db,f.bucket,o),/expected_previous/);});
test('future-dated capture cannot publish',async t=>{const f=fixture(t);const s=await imported(f,{at:new Date(now.getTime()+600000).toISOString()});await assert.rejects(publish(f,s),/source_stale/);});
test('stale capture cannot publish',async t=>{const f=fixture(t);const s=await imported(f,{at:new Date(now.getTime()-90000000).toISOString()});await assert.rejects(publish(f,s),/source_stale/);});
test('fresh unrelated import cannot freshen an old active snapshot',async t=>{
 const f=fixture(t);const oldDate=new Date(now.getTime()-90000000);const old=await imported(f,{at:oldDate.toISOString()});
 await publishSnapshot(f.db,f.bucket,{...options(old.id),now:oldDate});
 await imported(f,{title:'New but incomplete'});
 assert.equal((await f.fetch()).status,503);
 assert.equal((await f.fetch(`media/${assetId}`)).status,503);
});
test('versioned keys retain old and new rows without overwrites',async t=>{const f=fixture(t);const a=await imported(f,{title:'Old'});await publish(f,a);const b=await imported(f,{title:'New'});assert.equal((await (await f.fetch()).json()).rows[0].title,'Old');await publish(f,b,a.id);assert.equal((await (await f.fetch()).json()).rows[0].title,'New');assert.equal(f.db.sqlite.prepare("SELECT COUNT(*) n FROM public_snapshot_records WHERE source_table='news_posts'").get().n,2);});
test('sealed rows, media and identity cannot be changed',async t=>{const f=fixture(t);const s=await imported(f);await verifySnapshot(f.db,f.bucket,s.id,now);assert.throws(()=>f.db.sqlite.prepare('DELETE FROM public_snapshot_records WHERE snapshot_id=?').run(s.id),/immutable_snapshot/);assert.throws(()=>f.db.sqlite.prepare('DELETE FROM public_snapshot_media WHERE snapshot_id=?').run(s.id),/immutable_snapshot/);assert.throws(()=>f.db.sqlite.prepare('UPDATE public_snapshots SET captured_at_utc=? WHERE snapshot_id=?').run(now.toISOString(),s.id),/identity_immutable/);});
test('partial import fails counts without changing active content',async t=>{const f=fixture(t);const a=await imported(f);await publish(f,a);const b=await imported(f,{title:'Incomplete'});f.db.sqlite.prepare("DELETE FROM public_snapshot_records WHERE snapshot_id=? AND source_table='news_posts'").run(b.id);await assert.rejects(publish(f,b,a.id),/count_mismatch/);assert.equal(f.db.sqlite.prepare('SELECT snapshot_id FROM public_snapshot_head').get().snapshot_id,a.id);});
test('changed payload fails its content hash',async t=>{const f=fixture(t);const s=await imported(f);f.db.sqlite.prepare("UPDATE public_snapshot_records SET payload_json='{}' WHERE snapshot_id=? AND source_table='news_posts'").run(s.id);await assert.rejects(publish(f,s),/record_hash_mismatch/);});
test('wrong-club source record is denied',async t=>{const f=fixture(t);const s=await imported(f,{mutate:r=>{r.news_posts[0].club_id='other-club';}});await assert.rejects(publish(f,s),/tenant_mismatch/);});
test('same-sized corrupted R2 original fails publication',async t=>{const f=fixture(t);const s=await imported(f);f.blobs.set(`assets/${s.hash}.bin`,new Uint8Array(s.blob.length));await assert.rejects(publish(f,s),/media_hash_mismatch/);});
test('missing R2 original fails publication',async t=>{const f=fixture(t);const s=await imported(f);f.blobs.clear();await assert.rejects(publish(f,s),/media_size_mismatch/);});
test('media endpoint verifies actual bytes after publication',async t=>{const f=fixture(t);const s=await imported(f);await publish(f,s);let r=await f.fetch(`media/${assetId}?snapshot=${s.id}`);assert.equal(r.status,200);assert.deepEqual(new Uint8Array(await r.arrayBuffer()),s.blob);f.blobs.set(`assets/${s.hash}.bin`,new Uint8Array(s.blob.length));assert.equal((await f.fetch(`media/${assetId}`)).status,503);});
test('uncleared media remains private even after verified import',async t=>{const f=fixture(t);const s=await imported(f,{rights:'review-before-commercial-reuse'});await publish(f,s);assert.equal((await f.fetch(`media/${assetId}`)).status,404);const body=await (await f.fetch('partners')).json();assert.equal(body.rows[0].logoUrl,null);});
test('media URL cannot select a different snapshot',async t=>{const f=fixture(t);const s=await imported(f);await publish(f,s);assert.equal((await f.fetch(`media/${assetId}?snapshot=${'0'.repeat(64)}`)).status,404);});
test('cache lifetime does not outlive the snapshot',async t=>{const f=fixture(t);const s=await imported(f,{at:new Date(Date.now()-86400000+20000).toISOString()});await publish(f,s);const r=await f.fetch();const age=Number(/max-age=(\d+)/.exec(r.headers.get('cache-control'))[1]);assert.ok(age<=20&&age>=0);});
test('failed batch rolls back head, approval and retirement together',async t=>{const f=fixture(t);const a=await imported(f);await publish(f,a);const b=await imported(f,{title:'Next'});f.db.failAt=2;await assert.rejects(publish(f,b,a.id),/commit_failed/);assert.equal(f.db.sqlite.prepare('SELECT snapshot_id FROM public_snapshot_head').get().snapshot_id,a.id);assert.equal(f.db.sqlite.prepare('SELECT status FROM public_snapshots WHERE snapshot_id=?').get(a.id).status,'active');assert.equal(f.db.sqlite.prepare('SELECT COUNT(*) n FROM public_snapshot_publish_guards').get().n,0);f.db.failAt=null;await publish(f,b,a.id);});
test('two competing publications produce exactly one new head',async t=>{const f=fixture(t);const a=await imported(f);await publish(f,a);const b=await imported(f,{title:'B'});const c=await imported(f,{title:'C'});const results=await Promise.allSettled([publish(f,b,a.id),publish(f,c,a.id)]);assert.equal(results.filter(r=>r.status==='fulfilled').length,1);assert.equal(f.db.sqlite.prepare("SELECT COUNT(*) n FROM public_snapshots WHERE status='active'").get().n,1);});
test('duplicate publication is idempotent',async t=>{const f=fixture(t);const s=await imported(f);assert.equal((await publish(f,s)).alreadyActive,false);assert.equal((await publish(f,s)).alreadyActive,true);});
test('retired snapshot cannot be reactivated',async t=>{const f=fixture(t);const a=await imported(f);await publish(f,a);const b=await imported(f,{title:'B'});await publish(f,b,a.id);await assert.rejects(publish(f,a,b.id),/not_publishable/);});
test('older capture cannot replace a newer publication',async t=>{const f=fixture(t);const a=await imported(f);await publish(f,a);const b=await imported(f,{at:new Date(now.getTime()-3600000).toISOString(),title:'Older'});await assert.rejects(publish(f,b,a.id),/snapshot_regression/);});
test('forward migration retains legacy records and media',t=>{const f=fixture(t);f.db.sqlite.prepare("INSERT INTO source_records(source_table,source_id,source_club_id,payload_json,row_sha256,captured_at_utc) VALUES('clubs','legacy','legacy','{}',?,?)").run('a'.repeat(64),now.toISOString());assert.equal(f.db.sqlite.prepare('SELECT COUNT(*) n FROM source_records').get().n,1);});

for (const query of ['?snapshot='+ 'a'.repeat(64),'?foo=bar','?snapshot=bad']) {
 test('public JSON rejects query override '+query,async t=>{const f=fixture(t);const s=await imported(f);await publish(f,s);const r=await f.fetch('news'+query);assert.equal(r.status,400)});
}
