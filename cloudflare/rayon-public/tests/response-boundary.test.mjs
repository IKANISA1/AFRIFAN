import {test} from 'node:test';
import assert from 'node:assert/strict';
import reader from '../src/index.mjs';
import {fixture,imported,ASSET} from '../../operator-api/tests/support/fixture.mjs';
async function published(t){const f=fixture(t);const s=await imported(f);await f.publish(await f.review(s));return {f,s};}
const get=(f,s)=>reader.fetch(new Request('https://public.example.invalid/v1/public/rayon/'+s),f.env);

test('response after head changed during object read does not serve retired bytes',async t=>{
 const {f,s}=await published(t),next=await imported(f,{title:'Next source'});
 f.mediaHook(async()=>{await f.publish(await f.review(next,s.id),'different_request_1234')});
 const r=await get(f,'media/'+ASSET);assert.equal(r.status,503);assert.equal((await r.json()).error,'source_changed');
});
test('same-sized changed object cannot escape digest verification',async t=>{
 const {f,s}=await published(t);f.blobs.set('assets/'+s.hash+'.bin',new Uint8Array(s.bytes.length));
 const r=await get(f,'media/'+ASSET);assert.equal(r.status,503);assert.equal((await r.json()).error,'service_unavailable');
});
test('new partial import never becomes the reader authority',async t=>{
 const {f,s}=await published(t);await imported(f,{title:'Unreviewed'});const body=await (await get(f,'news')).json();
 assert.equal(body.snapshotId,s.id);assert.equal(body.rows[0].title,'Synthetic news');
});
test('media is withheld if final approval head disappears',async t=>{
 const {f}=await published(t);f.mediaHook(()=>f.db.sqlite.exec('DELETE FROM public_snapshot_head'));
 const r=await get(f,'media/'+ASSET);assert.equal(r.status,503);assert.equal((await r.json()).error,'source_unpublished');
});
test('non-GET remains denied without evaluating backend rows',async()=>{
 const r=await reader.fetch(new Request('https://public.example.invalid/v1/public/rayon/news',{method:'POST'}),{});
 assert.equal(r.status,405);assert.equal(r.headers.get('allow'),'GET');
});
