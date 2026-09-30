import { activeSnapshot, primarySession, sha256, MAX_MEDIA_BYTES, PublicationError } from "./snapshot-publication.mjs";

const routes = new Set([
  "fixtures", "news", "squad", "fanclubs", "partners", "shop",
  "tickets", "membership-tiers", "predict-pools",
]);

function label(value) {
  return typeof value === "string" ? value.trim() : "";
}

function https(value) {
  if (typeof value !== "string") return null;
  try {
    const url = new URL(value);
    return url.protocol === "https:" && !url.username && !url.password ? url.toString() : null;
  } catch {
    return null;
  }
}

// Public display fields must never carry unreviewed nested source records.
function displayList(value) {
  return Array.isArray(value) ? value.filter(item => typeof item === "string").map(label).filter(Boolean) : [];
}

function publicCount(value) {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0 ? value : null;
}

function asTime(value) {
  const time = Date.parse(label(value));
  return Number.isFinite(time) ? time : null;
}

function publicRow(row) {
  return row.approval_status === "approved" && row.active === true && row.visibility === "public";
}

async function rows(db, table, snapshot) {
  const result = await db.prepare(
    "SELECT payload_json FROM public_snapshot_records WHERE snapshot_id=? AND source_club_id=? AND source_table=? ORDER BY source_id",
  ).bind(snapshot.snapshot_id, snapshot.source_club_id, table).all();
  return result.results.map(({ payload_json }) => JSON.parse(payload_json));
}

async function mediaById(db, snapshot) {
  const [assets, registered] = await Promise.all([
    rows(db, "media_assets", snapshot),
    db.prepare("SELECT source_asset_id,source_bucket,source_path,sha256,usage_scopes_json,usage_rights FROM public_snapshot_media WHERE snapshot_id=?").bind(snapshot.snapshot_id).all(),
  ]);
  const byId = new Map(assets.filter(publicRow).map((asset) => [asset.id, asset]));
  const allowed = new Map();
  for (const item of registered.results) {
    const asset = byId.get(item.source_asset_id);
    if (asset && asset.storage_bucket === item.source_bucket &&
        asset.storage_path === item.source_path &&
        label(asset.checksum_sha256).toLowerCase() === item.sha256) {
      allowed.set(item.source_asset_id, { ...item, asset });
    }
  }
  return allowed;
}

function approvedImage(registered, id, scope, origin, snapshot) {
  const item = registered.get(id);
  if (!item || !label(item.usage_rights) ||
      !JSON.parse(item.usage_scopes_json).includes(scope)) return null;
  if (/generated|pending|review-before-commercial-reuse|unverified/i.test(item.usage_rights)) return null;
  return `${origin}/v1/public/rayon/media/${encodeURIComponent(id)}?snapshot=${snapshot.snapshot_id}`;
}

function json(body, status = 200, cacheSeconds = 60) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": status === 200 ? `public, max-age=${cacheSeconds}, must-revalidate` : "no-store",
      "x-content-type-options": "nosniff",
    },
  });
}

export async function publicSnapshotContent(db, route, now, origin, snapshot) {
  const time = now.getTime();
  if (route === "fixtures" || route === "predict-pools") {
    const [fixtures, teams, competitions] = await Promise.all([
      rows(db, "prediction_fixtures", snapshot), rows(db, "prediction_teams", snapshot),
      rows(db, "prediction_competitions", snapshot),
    ]);
    const team = new Map(teams.map((row) => [row.id, row]));
    const competition = new Map(competitions.filter((row) => row.active === true).map((row) => [row.id, row]));
    const active = fixtures.filter((row) => {
      const home = team.get(row.home_team_id);
      const away = team.get(row.away_team_id);
      return publicRow(row) && row.schedule_status === "confirmed" &&
        (asTime(row.starts_at) ?? 0) > time &&
        (home?.is_rayon_sports === true || away?.is_rayon_sports === true) &&
        label(row.source_publication_id) && https(row.source_url) &&
        label(home?.name) && label(away?.name) && label(competition.get(row.competition_id)?.name);
    });
    if (route === "fixtures") return active
      .sort((a, b) => asTime(a.starts_at) - asTime(b.starts_at))
      .map((row) => ({
        id: `gikundiro-${row.id}`, sourceId: row.id,
        homeTeam: label(team.get(row.home_team_id).name),
        awayTeam: label(team.get(row.away_team_id).name),
        competition: label(competition.get(row.competition_id).name),
        kickoffAt: row.starts_at, venue: label(row.venue),
        roundLabel: label(row.round_label), sourceUrl: https(row.source_url),
        predictionEntryEnabled: false,
      }));
    const fixtureIds = new Set(active.map((row) => row.id));
    return (await rows(db, "prediction_pools", snapshot))
      .filter((row) => row.status === "open" && fixtureIds.has(row.fixture_id) && (asTime(row.locks_at) ?? 0) > time)
      .map((row) => ({ id: row.id, fixtureId: `gikundiro-${row.fixture_id}`, locksAt: row.locks_at, entryEnabled: false }));
  }
  if (route === "news") {
    const cutoff = new Date(now);
    cutoff.setUTCMonth(cutoff.getUTCMonth() - 3);
    return (await rows(db, "news_posts", snapshot))
      .filter((row) => publicRow(row) && row.status === "published" && row.post_type === "news_feed" &&
        (asTime(row.published_at) ?? Infinity) >= cutoff.getTime() &&
        (asTime(row.published_at) ?? Infinity) <= time &&
        label(row.title) && label(row.excerpt) && https(row.source_url))
      .sort((a, b) => asTime(b.published_at) - asTime(a.published_at))
      .map((row) => {
        const supplied = label(row.source_label);
        const author = supplied && !/\b(?:coverage|discovery|aggregat(?:e|or)|across\s+.+media)\b/i.test(supplied)
          ? supplied : new URL(row.source_url).hostname.replace(/^www\./, "");
        return {
          id: `gikundiro-${row.id}`, title: label(row.title), excerpt: label(row.excerpt),
          category: label(row.category) || "Club news", publishedAt: row.published_at,
          author, sourceUrl: https(row.source_url),
        };
      });
  }
  if (route === "squad") {
    const media = await mediaById(db, snapshot);
    return (await rows(db, "players", snapshot))
      .filter((row) => publicRow(row) && label(row.display_name))
      .sort((a, b) => (a.sort_order ?? 100) - (b.sort_order ?? 100))
      .map((row) => ({
        id: `gikundiro-${row.id}`, name: label(row.display_name),
        shirtNumber: Number(row.squad_number) || 0,
        position: label(row.specific_position) || label(row.position),
        nationality: label(row.nationality), bio: label(row.short_bio),
        squadGroup: label(row.team) || "mens_first_team",
        imageUrl: approvedImage(media, row.photo_asset_id, "squad", origin, snapshot),
      }));
  }
  if (route === "fanclubs") return (await rows(db, "fanclubs", snapshot))
    .filter((row) => publicRow(row) && label(row.name))
    .sort((a, b) => (a.sort_order ?? 100) - (b.sort_order ?? 100))
    .map((row) => ({
      id: `gikundiro-${row.id}`, slug: label(row.slug), name: label(row.name),
      officialName: label(row.official_name), chapterType: label(row.chapter_type),
      country: label(row.country), province: label(row.province),
      district: label(row.district), city: label(row.city),
      acceptingMembers: row.accepting_members === true,
      memberCount: row.show_member_count === true ? publicCount(row.member_count_public) : null,
      activities: typeof row.activities === "string" ? label(row.activities) : displayList(row.activities), impactSummary: label(row.impact_summary),
    }));
  if (route === "partners") {
    const media = await mediaById(db, snapshot);
    return (await rows(db, "partners", snapshot))
      .filter((row) => publicRow(row) && label(row.name))
      .sort((a, b) => (a.sort_order ?? 100) - (b.sort_order ?? 100))
      .map((row) => ({
        id: `gikundiro-${row.id}`, name: label(row.name),
        category: label(row.category) || label(row.tier),
        description: label(row.relationship_summary),
        logoUrl: approvedImage(media, row.logo_asset_id, "partners", origin, snapshot),
        websiteUrl: https(row.website_url),
      }));
  }
  if (route === "shop") {
    const media = await mediaById(db, snapshot);
    const categories = new Map((await rows(db, "marketplace_categories", snapshot))
      .filter((row) => row.active === true).map((row) => [row.id, row]));
    const season = now.getUTCMonth() >= 6 ? now.getUTCFullYear() : now.getUTCFullYear() - 1;
    const status = `current_media_verified_${season}_${String((season + 1) % 100).padStart(2, "0")}`;
    return (await rows(db, "marketplace_products", snapshot))
      .filter((row) => publicRow(row) && row.verification_status === status &&
        Number(row.price_rwf) > 0 && label(row.name) &&
        approvedImage(media, row.image_asset_id, "shop", origin, snapshot))
      .sort((a, b) => (a.sort_order ?? 100) - (b.sort_order ?? 100))
      .map((row) => ({
        id: `gikundiro-${row.id}`, name: label(row.name),
        description: label(row.description), priceRwf: Number(row.price_rwf),
        category: label(categories.get(row.category_id)?.label) || label(categories.get(row.category_id)?.name) || "Merchandise",
        sizes: Array.isArray(row.variant_options?.sizes) ? row.variant_options.sizes.filter((size) => typeof size === "string") : [],
        imageUrl: approvedImage(media, row.image_asset_id, "shop", origin, snapshot),
        commerceMode: "enquiry", checkoutEnabled: false,
      }));
  }
  if (route === "tickets") {
    const categories = await rows(db, "ticket_sale_categories", snapshot);
    const bySale = new Map();
    for (const row of categories) {
      if (row.sale_enabled === true) {
        const list = bySale.get(row.ticket_sale_id) ?? [];
        list.push({ name: label(row.category_name), priceRwf: Number(row.price_rwf) || 0,
          capacity: Number(row.capacity) || 0, available: Number(row.available) || 0 });
        bySale.set(row.ticket_sale_id, list);
      }
    }
    return (await rows(db, "ticket_sales", snapshot))
      .filter((row) => publicRow(row) && row.sale_status === "reservation_open" &&
        row.sale_mode === "reservation_only" && (asTime(row.kickoff_at) ?? 0) > time)
      .sort((a, b) => asTime(a.kickoff_at) - asTime(b.kickoff_at))
      .map((row) => ({
        id: `gikundiro-${row.id}`, homeTeam: label(row.home_team),
        awayTeam: label(row.away_team), competition: label(row.competition),
        kickoffAt: row.kickoff_at, venue: label(row.venue),
        categories: bySale.get(row.id) ?? [],
        reservationOnly: true, paidTicketIssuanceEnabled: false,
      }));
  }
  if (route === "membership-tiers") return (await rows(db, "membership_tiers", snapshot))
    .filter((row) => publicRow(row) && label(row.name))
    .sort((a, b) => (a.sort_order ?? 100) - (b.sort_order ?? 100))
    .map((row) => ({
      id: `gikundiro-${row.id}`, name: label(row.name),
      priceRwf: Number(row.price_rwf) || Number(row.monthly_price_rwf) || 0,
      billingPeriod: label(row.billing_period), packageType: label(row.package_type),
      benefits: displayList(row.benefits), purchaseEnabled: false,
    }));
  return [];
}

async function recheckResponseSnapshot(db, snapshot) {
  const latest = await activeSnapshot(db, new Date());
  if (latest.snapshot_id !== snapshot.snapshot_id) throw new PublicationError('source_changed');
  return latest;
}

async function media(request, env, assetId, db, snapshot) {
  if (!env.RAYON_PUBLIC_MEDIA) return json({ error: "service_unavailable" }, 503);
  const requestedSnapshot = new URL(request.url).searchParams.get("snapshot");
  if (requestedSnapshot && requestedSnapshot !== snapshot.snapshot_id) return json({ error: "not_found" }, 404);
  const record = await db.prepare(
    "SELECT m.bytes,m.sha256,m.r2_key,m.source_bucket,m.source_path,m.usage_scopes_json,m.usage_rights,r.payload_json " +
    "FROM public_snapshot_media m JOIN public_snapshot_records r ON r.snapshot_id=m.snapshot_id " +
    "AND r.source_table='media_assets' AND r.source_id=m.source_asset_id " +
    "WHERE m.snapshot_id=? AND r.source_club_id=? AND m.source_asset_id=?",
  ).bind(snapshot.snapshot_id, snapshot.source_club_id, assetId).first();
  if (!record) return json({ error: "not_found" }, 404);
  const asset = JSON.parse(record.payload_json);
  const scopes = JSON.parse(record.usage_scopes_json);
  if (!publicRow(asset) || !record.usage_rights || !Array.isArray(scopes) || scopes.length === 0 ||
      asset.storage_bucket !== record.source_bucket || asset.storage_path !== record.source_path ||
      label(asset.checksum_sha256).toLowerCase() !== record.sha256 ||
      /generated|pending|review-before-commercial-reuse|unverified/i.test(record.usage_rights)) {
    return json({ error: "not_found" }, 404);
  }
  if (record.bytes > MAX_MEDIA_BYTES || record.r2_key !== `assets/${record.sha256}.bin`)
    return json({ error: "service_unavailable" }, 503);
  const object = await env.RAYON_PUBLIC_MEDIA.get(record.r2_key);
  if (!object || object.size !== record.bytes) return json({ error: "service_unavailable" }, 503);
  const bytes = await object.arrayBuffer();
  if (await sha256(bytes) !== record.sha256) return json({ error: "service_unavailable" }, 503);
  // A slow object read must not extend freshness past the approved snapshot TTL.
  // This is a second observed state, not a transaction locking publication forever.
  const latest = await recheckResponseSnapshot(db, snapshot);
  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("cache-control", `public, max-age=${latest.cacheSeconds}, must-revalidate`);
  headers.set("x-content-type-options", "nosniff");
  headers.set("content-security-policy", "default-src 'none'; sandbox");
  headers.set("etag", `"${record.sha256}"`);
  return new Response(bytes, { headers });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const mediaMatch = /^\/v1\/public\/rayon\/media\/([0-9a-f-]{36})$/.exec(url.pathname);
    const match = /^\/v1\/public\/rayon\/([a-z-]+)$/.exec(url.pathname);
    if (!mediaMatch && (!match || !routes.has(match[1]))) return json({ error: "not_found" }, 404);
    if (request.method !== "GET") {
      const response = json({ error: "method_not_allowed" }, 405);
      response.headers.set("allow", "GET");
      return response;
    }
    if (!env.RAYON_PUBLIC_DB) return json({ error: "service_unavailable" }, 503);
    try {
      const db = primarySession(env.RAYON_PUBLIC_DB);
      const now = new Date();
      const snapshot = await activeSnapshot(db, now);
      if (mediaMatch) return await media(request, env, mediaMatch[1], db, snapshot);
      const records = await publicSnapshotContent(db, match[1], now, url.origin, snapshot);
      const latest = await recheckResponseSnapshot(db, snapshot);
      return json({ schemaVersion: 1, route: match[1], snapshotId: snapshot.snapshot_id,
        sourceCapturedAt: snapshot.captured_at_utc, rows: records }, 200, latest.cacheSeconds);
    } catch (error) {
      const code = error instanceof PublicationError &&
        ["source_stale", "source_unpublished", "source_changed"].includes(error.code) ? error.code : "service_unavailable";
      return json({ error: code }, 503);
    }
  },
};
