/** Immutable public-source publication. No authentication or financial authority.
 * Call publishSnapshot only from the private publication Worker/service binding.
 */
export const PUBLIC_SOURCE_TABLES = Object.freeze([
  'clubs', 'fanclubs', 'marketplace_categories', 'marketplace_products',
  'media_assets', 'membership_tiers', 'news_posts', 'partners', 'players',
  'prediction_competitions', 'prediction_fixtures', 'prediction_pools',
  'prediction_teams', 'ticket_sale_categories', 'ticket_sales',
]);
export const SNAPSHOT_TTL_MS = 24 * 60 * 60 * 1000;
export const MAX_MEDIA_BYTES = 32 * 1024 * 1024;
const HEX = /^[a-f0-9]{64}$/;
const encoder = new TextEncoder();

export class PublicationError extends Error {
  constructor(code) { super(code); this.name = 'PublicationError'; this.code = code; }
}
const requireThat = (condition, code) => { if (!condition) throw new PublicationError(code); };
export async function sha256(data) {
  const bytes = typeof data === 'string' ? encoder.encode(data) : data;
  return [...new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))]
    .map(byte => byte.toString(16).padStart(2, '0')).join('');
}
export function primarySession(db) {
  return typeof db.withSession === 'function' ? db.withSession('first-primary') : db;
}
function remainingMs(snapshot, now) {
  const captured = Date.parse(snapshot.captured_at_utc);
  const time = now.getTime();
  requireThat(Number.isFinite(captured) && Number.isFinite(time) && captured <= time + 300_000 &&
    time - captured < SNAPSHOT_TTL_MS, 'source_stale');
  return Math.min(SNAPSHOT_TTL_MS, captured + SNAPSHOT_TTL_MS - time);
}
export async function activeSnapshot(db, now = new Date()) {
  const snapshot = await db.prepare(
    "SELECT s.* FROM public_snapshot_head h JOIN public_snapshots s ON s.snapshot_id=h.snapshot_id " +
    "WHERE h.singleton=1 AND s.status='active' AND s.approved_by IS NOT NULL AND s.approval_ref IS NOT NULL",
  ).first();
  requireThat(snapshot && HEX.test(snapshot.snapshot_id), 'source_unpublished');
  const remaining = remainingMs(snapshot, now);
  return { ...snapshot, cacheSeconds: Math.max(0, Math.min(60, Math.floor(remaining / 1000))) };
}
async function getRows(db, sql, id) {
  const result = await db.prepare(sql).bind(id).all();
  requireThat(Array.isArray(result.results), 'snapshot_read_failed');
  return result.results;
}

/** Seal first, then verify immutable row hashes, exact tables and R2 originals.
 * Failed verification never changes the active head. Sealed failed imports are
 * retained for investigation; publish a new snapshot rather than editing one.
 */
export async function verifySnapshot(db, bucket, snapshotId, now = new Date()) {
  requireThat(HEX.test(snapshotId ?? ''), 'invalid_snapshot_id');
  await db.prepare("UPDATE public_snapshots SET status='sealed' WHERE snapshot_id=? AND status='importing'")
    .bind(snapshotId).run();
  const snapshot = await db.prepare('SELECT * FROM public_snapshots WHERE snapshot_id=?').bind(snapshotId).first();
  requireThat(snapshot && ['sealed', 'verified', 'active'].includes(snapshot.status), 'snapshot_not_publishable');
  remainingMs(snapshot, now);
  requireThat(await sha256(snapshot.manifest_json) === snapshotId, 'snapshot_manifest_hash_mismatch');
  let manifest;
  try { manifest = JSON.parse(snapshot.manifest_json); } catch { throw new PublicationError('invalid_snapshot_manifest'); }
  requireThat(manifest.schemaVersion === 1 && manifest.sourceClubId === snapshot.source_club_id &&
    manifest.capturedAt === snapshot.captured_at_utc && Array.isArray(manifest.records) &&
    Array.isArray(manifest.media) && manifest.tables && typeof manifest.tables === 'object', 'invalid_snapshot_manifest');
  requireThat(JSON.stringify(Object.keys(manifest.tables).sort()) === JSON.stringify(PUBLIC_SOURCE_TABLES), 'snapshot_table_set_mismatch');
  const records = await getRows(db,
    'SELECT * FROM public_snapshot_records WHERE snapshot_id=? ORDER BY source_table,source_id', snapshotId);
  const media = await getRows(db,
    'SELECT * FROM public_snapshot_media WHERE snapshot_id=? ORDER BY source_asset_id', snapshotId);
  requireThat(records.length === manifest.records.length && media.length === manifest.media.length, 'snapshot_count_mismatch');
  const counts = Object.fromEntries(PUBLIC_SOURCE_TABLES.map(name => [name, 0]));
  const assetRows = new Map();
  for (let i = 0; i < records.length; i++) {
    const row = records[i];
    requireThat(Object.hasOwn(counts, row.source_table) && row.source_club_id === snapshot.source_club_id,
      'snapshot_tenant_mismatch');
    requireThat(JSON.stringify(manifest.records[i]) === JSON.stringify([row.source_table, row.source_id, row.row_sha256]),
      'snapshot_record_manifest_mismatch');
    requireThat(HEX.test(row.row_sha256) && await sha256(row.payload_json) === row.row_sha256, 'snapshot_record_hash_mismatch');
    let payload;
    try { payload = JSON.parse(row.payload_json); } catch { throw new PublicationError('snapshot_record_invalid'); }
    requireThat(payload && String(payload.id) === row.source_id &&
      (payload.club_id == null || String(payload.club_id) === snapshot.source_club_id), 'snapshot_tenant_mismatch');
    if (row.source_table === 'clubs') requireThat(row.source_id === snapshot.source_club_id, 'snapshot_tenant_mismatch');
    if (row.source_table === 'media_assets') assetRows.set(row.source_id, payload);
    counts[row.source_table]++;
  }
  requireThat(counts.clubs === 1 && PUBLIC_SOURCE_TABLES.every(name =>
    Number.isSafeInteger(manifest.tables[name]) && manifest.tables[name] >= 0 && counts[name] === manifest.tables[name]),
    'snapshot_table_count_mismatch');
  for (let i = 0; i < media.length; i++) {
    const row = media[i];
    let scopes;
    try { scopes = JSON.parse(row.usage_scopes_json); } catch { throw new PublicationError('invalid_media_scopes'); }
    requireThat(Array.isArray(scopes) && scopes.every(scope => typeof scope === 'string') &&
      typeof row.usage_rights === 'string' && row.usage_rights.trim().length > 0, 'invalid_media_rights');
    requireThat(Number.isSafeInteger(row.bytes) && row.bytes >= 0 && row.bytes <= MAX_MEDIA_BYTES &&
      HEX.test(row.sha256) && row.r2_key === `assets/${row.sha256}.bin`, 'invalid_media_integrity');
    const actual = [row.source_asset_id, row.source_bucket, row.source_path, row.bytes, row.sha256, scopes, row.usage_rights, row.r2_key];
    requireThat(JSON.stringify(manifest.media[i]) === JSON.stringify(actual), 'snapshot_media_manifest_mismatch');
    const asset = assetRows.get(row.source_asset_id);
    requireThat(asset && asset.storage_bucket === row.source_bucket && asset.storage_path === row.source_path &&
      String(asset.checksum_sha256).toLowerCase() === row.sha256 &&
      String(asset.usage_rights ?? '').trim() === row.usage_rights && Array.isArray(asset.usage_scopes) &&
      scopes.every(scope => asset.usage_scopes.includes(scope)), 'snapshot_media_source_mismatch');
    requireThat(bucket && typeof bucket.get === 'function', 'media_bucket_unavailable');
    const object = await bucket.get(row.r2_key);
    requireThat(object && object.size === row.bytes, 'snapshot_media_size_mismatch');
    requireThat(await sha256(await object.arrayBuffer()) === row.sha256, 'snapshot_media_hash_mismatch');
  }
  await db.prepare("UPDATE public_snapshots SET status='verified',verified_at_utc=? WHERE snapshot_id=? AND status='sealed'")
    .bind(now.toISOString(), snapshotId).run();
  return snapshot;
}

/** expectedPreviousId is mandatory: null for the first publication, otherwise
 * the exact current head. The head, state changes and approval commit together.
 */
export async function publishSnapshot(database, bucket, options) {
  const { snapshotId, approvedBy, approvalRef, expectedPreviousId, now = new Date() } = options ?? {};
  requireThat(typeof approvedBy === 'string' && /^[A-Za-z0-9_.:@/-]{3,128}$/.test(approvedBy) &&
    typeof approvalRef === 'string' && /^[A-Za-z0-9_.:@/-]{3,200}$/.test(approvalRef), 'publication_approval_required');
  requireThat(expectedPreviousId === null || HEX.test(expectedPreviousId ?? ''), 'expected_previous_snapshot_required');
  const db = primarySession(database);
  const head = await db.prepare('SELECT snapshot_id FROM public_snapshot_head WHERE singleton=1').first();
  if (head?.snapshot_id === snapshotId) {
    await activeSnapshot(db, now); // Even a duplicate call must not report stale content as current.
    return { snapshotId, alreadyActive: true };
  }
  requireThat((head?.snapshot_id ?? null) === expectedPreviousId, 'publication_conflict');
  const snapshot = await verifySnapshot(db, bucket, snapshotId, now);
  if (head) {
    const previous = await db.prepare('SELECT captured_at_utc FROM public_snapshots WHERE snapshot_id=?').bind(head.snapshot_id).first();
    requireThat(previous && Date.parse(snapshot.captured_at_utc) >= Date.parse(previous.captured_at_utc), 'snapshot_regression');
  }
  const nonce = crypto.randomUUID();
  try {
    await db.batch([
      db.prepare('INSERT INTO public_snapshot_publish_guards(nonce,passed) SELECT ?,CASE WHEN ' +
        '(SELECT snapshot_id FROM public_snapshot_head WHERE singleton=1) IS ? AND ' +
        "EXISTS(SELECT 1 FROM public_snapshots WHERE snapshot_id=? AND status='verified') THEN 1 ELSE 0 END")
        .bind(nonce, expectedPreviousId, snapshotId),
      db.prepare("UPDATE public_snapshots SET status='retired' WHERE status='active' AND snapshot_id=?").bind(expectedPreviousId),
      db.prepare("UPDATE public_snapshots SET status='active',approved_by=?,approval_ref=?,activated_at_utc=? WHERE snapshot_id=? AND status='verified'")
        .bind(approvedBy, approvalRef, now.toISOString(), snapshotId),
      db.prepare('INSERT INTO public_snapshot_head(singleton,snapshot_id) VALUES(1,?) ON CONFLICT(singleton) DO UPDATE SET snapshot_id=excluded.snapshot_id')
        .bind(snapshotId),
      db.prepare('DELETE FROM public_snapshot_publish_guards WHERE nonce=?').bind(nonce),
    ]);
  } catch { throw new PublicationError('publication_commit_failed'); }
  return { snapshotId, alreadyActive: false };
}
