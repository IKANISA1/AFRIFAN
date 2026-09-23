/**
 * download-logos — Downloads team/league logos from API-Football CDN
 * and uploads them to Supabase Storage for reliable hosting.
 *
 * Stores in bucket: `football-assets`
 * Paths:
 *   - teams/{external_team_id}.png
 *   - leagues/{external_league_id}.png
 *   - flags/{country_code}.png
 */

import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

const BUCKET = "football-assets";

export interface DownloadLogosResult {
  teams_downloaded: number;
  leagues_downloaded: number;
  flags_downloaded: number;
  skipped: number;
  errors: string[];
}

export async function downloadLogos(
  adminClient: SupabaseClient,
): Promise<DownloadLogosResult> {
  const result: DownloadLogosResult = {
    teams_downloaded: 0,
    leagues_downloaded: 0,
    flags_downloaded: 0,
    skipped: 0,
    errors: [],
  };

  // Ensure bucket exists
  await ensureBucket(adminClient);

  // 1. Download team logos
  const { data: teams } = await adminClient
    .schema("football")
    .from("teams")
    .select("id, external_team_id, crest_url, metadata")
    .eq("external_provider", "api-football")
    .not("external_team_id", "is", null);

  if (teams) {
    for (const team of teams) {
      const logoUrl = team.crest_url ||
        (team.metadata as Record<string, unknown>)?.api_logo;
      if (!logoUrl || typeof logoUrl !== "string") {
        result.skipped++;
        continue;
      }

      // Check if already downloaded
      const storagePath = `teams/${team.external_team_id}.png`;
      const publicUrl = getPublicUrl(adminClient, storagePath);

      // Skip if metadata already has storage URL
      const meta = (team.metadata ?? {}) as Record<string, unknown>;
      if (meta.storage_logo_url) {
        result.skipped++;
        continue;
      }

      try {
        const uploaded = await downloadAndUpload(
          adminClient,
          logoUrl,
          storagePath,
        );

        if (uploaded) {
          // Update team with storage URL
          await adminClient
            .schema("football")
            .from("teams")
            .update({
              crest_url: publicUrl,
              metadata: {
                ...meta,
                storage_logo_url: publicUrl,
                api_logo: logoUrl,
              },
            })
            .eq("id", team.id);

          result.teams_downloaded++;
        } else {
          result.skipped++;
        }
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        result.errors.push(`Team ${team.external_team_id}: ${msg}`);
      }
    }
  }

  // 2. Download league logos from sync_config metadata
  const { data: configs } = await adminClient
    .from("football_sync_config")
    .select("id, external_league_id, metadata, competition_id")
    .eq("is_active", true);

  if (configs) {
    for (const config of configs) {
      const meta = (config.metadata ?? {}) as Record<string, unknown>;
      const logoUrl = meta.api_league_logo as string | undefined;

      if (!logoUrl || meta.storage_league_logo_url) {
        result.skipped++;
        continue;
      }

      try {
        const storagePath = `leagues/${config.external_league_id}.png`;
        const publicUrl = getPublicUrl(adminClient, storagePath);

        const uploaded = await downloadAndUpload(
          adminClient,
          logoUrl,
          storagePath,
        );

        if (uploaded) {
          // Update competition metadata
          if (config.competition_id) {
            const { data: comp } = await adminClient
              .schema("football")
              .from("competitions")
              .select("metadata")
              .eq("id", config.competition_id)
              .maybeSingle();

            if (comp) {
              const compMeta = (comp.metadata ?? {}) as Record<string, unknown>;
              await adminClient
                .schema("football")
                .from("competitions")
                .update({
                  metadata: {
                    ...compMeta,
                    storage_league_logo_url: publicUrl,
                    api_league_logo: logoUrl,
                  },
                })
                .eq("id", config.competition_id);
            }
          }

          // Update sync config metadata
          await adminClient
            .from("football_sync_config")
            .update({
              metadata: {
                ...meta,
                storage_league_logo_url: publicUrl,
              },
            })
            .eq("id", config.id);

          result.leagues_downloaded++;
        }
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        result.errors.push(`League ${config.external_league_id}: ${msg}`);
      }
    }
  }

  // 3. Download country flags
  const { data: comps } = await adminClient
    .schema("football")
    .from("competitions")
    .select("id, country_code, metadata")
    .not("country_code", "is", null);

  if (comps) {
    const processedCodes = new Set<string>();
    for (const comp of comps) {
      const code = comp.country_code;
      if (!code || processedCodes.has(code)) {
        result.skipped++;
        continue;
      }
      processedCodes.add(code);

      const meta = (comp.metadata ?? {}) as Record<string, unknown>;
      const flagUrl = meta.api_country_flag as string | undefined;

      if (!flagUrl || meta.storage_flag_url) {
        result.skipped++;
        continue;
      }

      try {
        const storagePath = `flags/${code.toLowerCase()}.svg`;
        const publicUrl = getPublicUrl(adminClient, storagePath);

        const uploaded = await downloadAndUpload(
          adminClient,
          flagUrl,
          storagePath,
          "image/svg+xml",
        );

        if (uploaded) {
          await adminClient
            .schema("football")
            .from("competitions")
            .update({
              metadata: {
                ...meta,
                storage_flag_url: publicUrl,
              },
            })
            .eq("id", comp.id);

          result.flags_downloaded++;
        }
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        result.errors.push(`Flag ${code}: ${msg}`);
      }
    }
  }

  return result;
}

/* ---------- Helpers ---------- */

async function ensureBucket(client: SupabaseClient): Promise<void> {
  // Check if bucket exists
  const { data } = await client.storage.getBucket(BUCKET);
  if (data) return;

  // Create bucket
  await client.storage.createBucket(BUCKET, {
    public: true,
    fileSizeLimit: 1024 * 1024, // 1MB limit for logos
    allowedMimeTypes: [
      "image/png",
      "image/svg+xml",
      "image/jpeg",
      "image/webp",
    ],
  });
}

async function downloadAndUpload(
  client: SupabaseClient,
  sourceUrl: string,
  storagePath: string,
  contentType = "image/png",
): Promise<boolean> {
  // Download from source
  const response = await fetch(sourceUrl);
  if (!response.ok) {
    throw new Error(
      `Download failed: ${response.status} ${response.statusText}`,
    );
  }

  const blob = await response.blob();
  if (blob.size === 0) {
    return false;
  }

  // Upload to Supabase Storage
  const { error } = await client.storage
    .from(BUCKET)
    .upload(storagePath, blob, {
      contentType,
      upsert: true,
    });

  if (error) {
    throw new Error(`Upload failed: ${error.message}`);
  }

  return true;
}

function getPublicUrl(client: SupabaseClient, path: string): string {
  const { data } = client.storage.from(BUCKET).getPublicUrl(path);
  return data?.publicUrl ?? "";
}
