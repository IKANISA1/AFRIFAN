/**
 * ============================================================================
 * Generate Multipliers — Edge Function
 * ============================================================================
 * Reads fixture features from the DB, estimates probabilities, applies
 * overround + liability adjustment, and writes multipliers back to
 * fixture_markets.
 *
 * Commands:
 *   POST { command: "generate", fixture_id: "..." }
 *     → Generate multipliers for a single fixture
 *
 *   POST { command: "generate-all" }
 *     → Generate multipliers for ALL scheduled fixtures
 *
 *   POST { command: "refresh", fixture_id: "..." }
 *     → Re-generate multipliers with updated user voting volume
 *
 *   POST { command: "preview", fixture_id: "..." }
 *     → Preview multipliers without writing to DB
 *
 * Auth: CRON_JOB_SECRET or admin role
 * ============================================================================
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import {
  estimateProbabilities,
  estimateBTTS,
  estimateOverUnder,
  defaultProbabilities,
  type FixtureFeatures,
} from './probability-engine.ts';
import {
  generateMarketMultipliers,
  toOutcomesJsonb,
  DEFAULT_OVERROUND,
  DEFAULT_VOLUME_THRESHOLD,
  type UserVotingVolume,
} from './liability-engine.ts';

// ─── Types ──────────────────────────────────────────────────────────────

interface GenerateRequest {
  command: 'generate' | 'generate-all' | 'refresh' | 'preview';
  fixture_id?: string;
  overround?: number;
}

interface MarketTemplate {
  slug: string;
  outcome_template: Array<{ key: string; label: string }>;
}

// ─── Handler ────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers':
          'Authorization, Content-Type, x-cron-secret',
      },
    });
  }

  if (req.method !== 'POST') {
    return json({ error: 'POST required' }, 405);
  }

  // Auth: CRON_JOB_SECRET or admin Bearer token
  const cronSecret = req.headers.get('x-cron-secret');
  const expectedSecret = Deno.env.get('CRON_JOB_SECRET');
  const authHeader = req.headers.get('Authorization');

  const isAuthedCron = cronSecret && expectedSecret && cronSecret === expectedSecret;
  const isAuthedBearer = authHeader?.startsWith('Bearer ');

  if (!isAuthedCron && !isAuthedBearer) {
    return json({ error: 'Unauthorized' }, 401);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const client = createClient(supabaseUrl, supabaseKey);

  try {
    const body = (await req.json()) as GenerateRequest;
    const overround = body.overround ?? DEFAULT_OVERROUND;

    switch (body.command) {
      case 'generate':
        return await handleGenerate(client, body.fixture_id!, overround);

      case 'generate-all':
        return await handleGenerateAll(client, overround);

      case 'refresh':
        return await handleRefresh(client, body.fixture_id!, overround);

      case 'preview':
        return await handlePreview(client, body.fixture_id!, overround);

      default:
        return json({
          error: `Unknown command: ${body.command}`,
          available: ['generate', 'generate-all', 'refresh', 'preview'],
        }, 400);
    }
  } catch (err) {
    console.error('[generate-multipliers] Error:', err);
    return json({ error: (err as Error).message }, 500);
  }
});

// ─── Command Handlers ───────────────────────────────────────────────────

async function handleGenerate(
  client: ReturnType<typeof createClient>,
  fixtureId: string,
  overround: number,
) {
  if (!fixtureId) return json({ error: 'fixture_id required' }, 400);

  const result = await generateForFixture(client, fixtureId, overround, true);
  return json(result);
}

async function handleGenerateAll(
  client: ReturnType<typeof createClient>,
  overround: number,
) {
  // Get all scheduled fixtures that have fixture_markets
  const { data: fixtures, error } = await client
    .from('football_fixtures_catalog')
    .select('id')
    .eq('status', 'scheduled');

  if (error) throw error;
  if (!fixtures || fixtures.length === 0) {
    return json({ message: 'No scheduled fixtures found', updated: 0 });
  }

  const results: Array<{ fixture_id: string; markets_updated: number }> = [];
  for (const fixture of fixtures) {
    const result = await generateForFixture(
      client,
      fixture.id,
      overround,
      true,
    );
    results.push({
      fixture_id: fixture.id,
      markets_updated: result.markets_updated ?? 0,
    });
  }

  return json({
    message: `Multipliers generated for ${results.length} fixtures`,
    fixtures: results.length,
    total_markets: results.reduce((s, r) => s + r.markets_updated, 0),
  });
}

async function handleRefresh(
  client: ReturnType<typeof createClient>,
  fixtureId: string,
  overround: number,
) {
  if (!fixtureId) return json({ error: 'fixture_id required' }, 400);

  // Refresh with user volume (liability adjustment)
  const result = await generateForFixture(
    client,
    fixtureId,
    overround,
    true,
    true,
  );
  return json(result);
}

async function handlePreview(
  client: ReturnType<typeof createClient>,
  fixtureId: string,
  overround: number,
) {
  if (!fixtureId) return json({ error: 'fixture_id required' }, 400);

  // Preview without writing
  const result = await generateForFixture(
    client,
    fixtureId,
    overround,
    false,
  );
  return json(result);
}

// ─── Core Logic ─────────────────────────────────────────────────────────

async function generateForFixture(
  client: ReturnType<typeof createClient>,
  fixtureId: string,
  overround: number,
  persist: boolean,
  includeVolume: boolean = false,
): Promise<Record<string, unknown>> {
  // 1. Load fixture features from the DB view
  const { data: featureRows, error: featureErr } = await client
    .from('fixture_features')
    .select('*')
    .eq('fixture_id', fixtureId)
    .limit(1);

  // Use defaults if no features available (e.g., new team, no history)
  const features: FixtureFeatures =
    featureRows && featureRows.length > 0
      ? (featureRows[0] as FixtureFeatures)
      : {
          fixture_id: fixtureId,
          home_team_win_rate: null,
          away_team_win_rate: null,
          home_team_draw_rate: null,
          home_goals_scored_avg: null,
          home_goals_conceded_avg: null,
          away_goals_scored_avg: null,
          away_goals_conceded_avg: null,
          h2h_home_wins: null,
          h2h_away_wins: null,
          h2h_draws: null,
          home_league_position: null,
          away_league_position: null,
        };

  // 2. Load user voting volume (if requested)
  let userVolume: UserVotingVolume | null = null;
  if (includeVolume) {
    userVolume = await loadUserVolume(client, fixtureId);
  }

  // 3. Load fixture info for team names (to replace "Home Win" → "ARS")
  const { data: fixtureInfo } = await client
    .from('football_fixtures_catalog')
    .select('home_team_short_name, away_team_short_name')
    .eq('id', fixtureId)
    .limit(1)
    .single();

  const homeShort = (fixtureInfo?.home_team_short_name as string) ?? 'Home';
  const awayShort = (fixtureInfo?.away_team_short_name as string) ?? 'Away';

  // 4. Load fixture markets with their market templates
  const { data: fixtureMarkets, error: fmErr } = await client
    .from('fixture_markets_catalog')
    .select('*')
    .eq('fixture_id', fixtureId);

  if (fmErr) throw fmErr;
  if (!fixtureMarkets || fixtureMarkets.length === 0) {
    return {
      fixture_id: fixtureId,
      message: 'No fixture markets found. Ensure markets are generated first.',
      markets_updated: 0,
    };
  }

  // 5. Estimate probabilities for each market type
  const marketOddsUpdates: Array<{
    market_slug: string;
    outcomes: Array<{ key: string; label: string; odds: number }>;
  }> = [];

  const multiplierResults: Record<string, unknown> = {};

  for (const fm of fixtureMarkets) {
    const slug = fm.market_slug as string;
    const templateOutcomes = parseOutcomes(fm.outcomes);

    // Get probabilities based on market type
    const probabilities = getProbabilitiesForMarket(slug, features);

    // Get market-specific user volume
    const marketVolume = includeVolume
      ? await loadMarketVolume(client, fm.id as string)
      : null;

    // Generate multipliers
    const multipliers = generateMarketMultipliers(
      probabilities,
      marketVolume,
      overround,
    );

    // Convert to outcomes JSONB format, substituting real team names
    const updatedOutcomes = toOutcomesJsonb(multipliers, templateOutcomes);

    // Replace generic "Home Win"/"Away Win" labels with actual team initials
    const labeledOutcomes = replaceTeamLabels(updatedOutcomes, homeShort, awayShort);

    marketOddsUpdates.push({
      market_slug: slug,
      outcomes: labeledOutcomes,
    });

    multiplierResults[slug] = {
      probabilities,
      multipliers,
      outcomes: labeledOutcomes,
    };
  }

  // 5. Persist to DB (if not preview)
  let marketsUpdated = 0;
  if (persist && marketOddsUpdates.length > 0) {
    const { data, error: updateErr } = await client.rpc(
      'update_fixture_odds_batch',
      {
        p_fixture_id: fixtureId,
        p_market_odds: marketOddsUpdates,
      },
    );

    if (updateErr) throw updateErr;
    marketsUpdated = (data as number) ?? marketOddsUpdates.length;
  }

  return {
    fixture_id: fixtureId,
    markets_updated: marketsUpdated,
    persisted: persist,
    overround,
    feature_data_available: featureRows && featureRows.length > 0,
    markets: multiplierResults,
  };
}

// ─── Helpers ────────────────────────────────────────────────────────────

function getProbabilitiesForMarket(
  marketSlug: string,
  features: FixtureFeatures,
): Record<string, number> {
  switch (marketSlug) {
    case '1x2':
    case 'half-time-result': {
      const p = estimateProbabilities(features);
      return { home: p.home, draw: p.draw, away: p.away };
    }
    case 'btts': {
      const p = estimateBTTS(features);
      return { yes: p.yes, no: p.no };
    }
    case 'over-under-1-5': {
      const p = estimateOverUnder(features, 1.5);
      return { over: p.over, under: p.under };
    }
    case 'over-under-2-5': {
      const p = estimateOverUnder(features, 2.5);
      return { over: p.over, under: p.under };
    }
    case 'over-under-3-5': {
      const p = estimateOverUnder(features, 3.5);
      return { over: p.over, under: p.under };
    }
    case 'correct-score': {
      // Correct score uses equal low probabilities — high multipliers
      return {
        '1-0': 0.08, '0-1': 0.07, '1-1': 0.10, '2-0': 0.06,
        '0-2': 0.05, '2-1': 0.08, '1-2': 0.07, '2-2': 0.05,
        '3-0': 0.03, '0-3': 0.02, '3-1': 0.04, '1-3': 0.03,
        '0-0': 0.06, '3-2': 0.02, '2-3': 0.02, 'other': 0.22,
      };
    }
    default: {
      // Unknown market — equal distribution across outcomes
      const p = defaultProbabilities();
      return { home: p.home, draw: p.draw, away: p.away };
    }
  }
}

async function loadUserVolume(
  client: ReturnType<typeof createClient>,
  fixtureId: string,
): Promise<UserVotingVolume | null> {
  const { data } = await client
    .from('prediction_volume')
    .select('*')
    .eq('fixture_id', fixtureId)
    .eq('market_slug', '1x2');

  if (!data || data.length === 0) return null;

  const volume: UserVotingVolume = {};
  for (const row of data) {
    volume[row.selected_outcome as string] = Number(row.vote_pct ?? 0);
  }
  return volume;
}

async function loadMarketVolume(
  client: ReturnType<typeof createClient>,
  fixtureMarketId: string,
): Promise<UserVotingVolume | null> {
  const { data } = await client
    .from('prediction_volume')
    .select('*')
    .eq('fixture_market_id', fixtureMarketId);

  if (!data || data.length === 0) return null;

  const volume: UserVotingVolume = {};
  for (const row of data) {
    volume[row.selected_outcome as string] = Number(row.vote_pct ?? 0);
  }
  return volume;
}

function parseOutcomes(
  raw: unknown,
): Array<{ key: string; label: string }> {
  if (Array.isArray(raw)) {
    return raw.map((item) => ({
      key: (item as Record<string, unknown>).key?.toString() ?? '',
      label: (item as Record<string, unknown>).label?.toString() ?? '',
    }));
  }
  // Default 1X2 outcomes
  return [
    { key: 'home', label: 'Home Win' },
    { key: 'draw', label: 'Draw' },
    { key: 'away', label: 'Away Win' },
  ];
}

/**
 * Replaces generic "Home Win" / "Away Win" / "Home Team" / "Away Team" labels
 * with actual team short names (e.g., "ARS", "RMA").
 *
 * Also handles compound labels like "Home or Draw" → "ARS or Draw",
 * "Home or Away" → "ARS or RMA".
 */
function replaceTeamLabels(
  outcomes: Array<{ key: string; label: string; odds: number }>,
  homeShort: string,
  awayShort: string,
): Array<{ key: string; label: string; odds: number }> {
  const home = homeShort.toUpperCase();
  const away = awayShort.toUpperCase();

  return outcomes.map((o) => {
    let label = o.label;

    // Direct replacements (order matters — longer first)
    label = label.replace(/Home Win/gi, home);
    label = label.replace(/Away Win/gi, away);
    label = label.replace(/Home Team/gi, home);
    label = label.replace(/Away Team/gi, away);
    label = label.replace(/\bHome\b/g, home);
    label = label.replace(/\bAway\b/g, away);

    return { ...o, label };
  });
}

function json(data: unknown, status: number = 200): Response {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  });
}
