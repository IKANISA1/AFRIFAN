import assert from 'node:assert/strict';
import test from 'node:test';
import worker from './index.mjs';

const now = new Date().toISOString();
function statement(sql, state) {
  const query = { async first() {
    if (sql.includes('source_snapshots')) return state.snapshot;
    if (sql.includes('source_media')) return state.media ?? null;
    return null;
  }, async all() { return {results: []}; } };
  return { ...query, bind(...args) { return query; } };
}
function env(state) {
  return { RAYON_PUBLIC_DB: { prepare(sql) { return statement(sql,state); } },
    RAYON_PUBLIC_MEDIA: { async get() { return null; } } };
}

test('content fails closed without an active snapshot', async () => {
  const res = await worker.fetch(new Request('https://example.test/v1/public/rayon/news'), env({snapshot:null}));
  assert.equal(res.status, 503);
  assert.equal((await res.json()).error, 'source_stale');
});

test('content reports the activated snapshot, not a global newest row', async () => {
  const res = await worker.fetch(new Request('https://example.test/v1/public/rayon/news'), env({snapshot:{snapshot_id:'snap-1',captured_at_utc:now}}));
  assert.equal(res.status, 200);
  const body=await res.json();
  assert.equal(body.schemaVersion,2); assert.equal(body.snapshotId,'snap-1');
});

test('media is blocked when the active snapshot is stale', async () => {
  const old = new Date(Date.now()-25*60*60*1000).toISOString();
  const res = await worker.fetch(new Request('https://example.test/v1/public/rayon/media/11111111-1111-1111-1111-111111111111'), env({snapshot:{snapshot_id:'snap-old',captured_at_utc:old}}));
  assert.equal(res.status,503); assert.equal((await res.json()).error,'source_stale');
});
