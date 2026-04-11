import { Client } from "npm:pg";

const connectionString =
  Deno.env.get("DATABASE_URL") ??
  "postgresql://postgres:postgres@127.0.0.1:54322/postgres";

function assertEqual(label: string, actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`${label} failed. Expected ${expected}, received ${actual}.`);
  }
}

async function insertUser(client: Client, userId: string, email: string, _displayName: string) {
  await client.query(`
    insert into auth.users (
      id,
      instance_id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at
    ) values (
      $1,
      '00000000-0000-0000-0000-000000000000',
      'authenticated',
      'authenticated',
      $2,
      crypt('password', gen_salt('bf')),
      now(),
      '{}'::jsonb,
      '{}'::jsonb,
      now(),
      now()
    )
    on conflict (id) do nothing
  `, [userId, email]);
}

async function seedPlayers(client: Client) {
  const players = [
    { external_id: 101, name: "Goalkeeper Hero", short_name: "GK Hero", position: "GK", team_id: 1, team_name: "Alpha FC", team_short: "ALP" },
    { external_id: 102, name: "Defender Wall", short_name: "D Wall", position: "DEF", team_id: 2, team_name: "Bravo FC", team_short: "BRV" },
    { external_id: 103, name: "Midfield Engine", short_name: "M Engine", position: "MID", team_id: 3, team_name: "Charlie FC", team_short: "CHA" },
    { external_id: 104, name: "Forward Finisher", short_name: "F Finish", position: "FWD", team_id: 4, team_name: "Delta FC", team_short: "DEL" },
    { external_id: 105, name: "Bench Creator", short_name: "B Create", position: "MID", team_id: 5, team_name: "Echo FC", team_short: "ECH" },
    { external_id: 106, name: "Defender Shift", short_name: "D Shift", position: "DEF", team_id: 6, team_name: "Foxtrot FC", team_short: "FOX" },
    { external_id: 107, name: "Defender Lock", short_name: "D Lock", position: "DEF", team_id: 7, team_name: "Golf FC", team_short: "GLF" },
    { external_id: 108, name: "Midfield Link", short_name: "M Link", position: "MID", team_id: 8, team_name: "Hotel FC", team_short: "HOT" },
    { external_id: 109, name: "Midfield Blank", short_name: "M Blank", position: "MID", team_id: 9, team_name: "India FC", team_short: "IND" },
    { external_id: 110, name: "Forward Red", short_name: "F Red", position: "FWD", team_id: 10, team_name: "Juliet FC", team_short: "JUL" },
    { external_id: 111, name: "Bench Shield", short_name: "B Shield", position: "DEF", team_id: 11, team_name: "Kilo FC", team_short: "KIL" },
    { external_id: 112, name: "Midfield Steady", short_name: "M Steady", position: "MID", team_id: 12, team_name: "Lima FC", team_short: "LIM" },
    { external_id: 113, name: "Bench Strike", short_name: "B Strike", position: "FWD", team_id: 13, team_name: "Mike FC", team_short: "MIK" },
    { external_id: 114, name: "Reserve Keeper", short_name: "R Keeper", position: "GK", team_id: 14, team_name: "November FC", team_short: "NOV" },
    { external_id: 115, name: "Defender Bonus", short_name: "D Bonus", position: "DEF", team_id: 15, team_name: "Oscar FC", team_short: "OSC" },
  ];

  for (const player of players) {
    await client.query(`
      insert into fantasy.players (
        external_id,
        name,
        short_name,
        position,
        team_id,
        team_name,
        team_short
      ) values ($1, $2, $3, $4, $5, $6, $7)
    `, [
      player.external_id,
      player.name,
      player.short_name,
      player.position,
      player.team_id,
      player.team_name,
      player.team_short,
    ]);
  }
}

async function main() {
  const client = new Client({ connectionString });
  await client.connect();

  try {
    await client.query("begin");

    const competitionResult = await client.query<{ id: string }>(`
      insert into fantasy.competitions (
        slug,
        name,
        short_name,
        competition_type,
        season,
        status,
        start_date,
        end_date,
        scoring_rules,
        squad_config,
        chip_config,
        transfer_config
      ) values (
        'test-fantasy',
        'Test Fantasy',
        'TEST',
        'season_long',
        '2025/26',
        'active',
        now(),
        now() + interval '30 day',
        '{
          "points_sub_60": 1,
          "points_60_plus": 2,
          "goals": { "GK_DEF": 10, "MID": 6, "FWD": 4 },
          "assists_all": 3,
          "clean_sheet": { "GK_DEF": 6, "MID": 1, "FWD": 0 },
          "goals_conceded_per_2": -1,
          "saves_per_3": 1,
          "penalty_save": 5,
          "penalty_miss": -2,
          "yellow_card": -1,
          "red_card": -3,
          "own_goal": -2,
          "defensive_contributions": { "DEF_threshold": 10, "MID_FWD_threshold": 12, "points": 2 },
          "captain_multiplier": 2,
          "triple_captain_multiplier": 3
        }'::jsonb,
        '{
          "budget": 1000,
          "squad_size": 15,
          "starters": 11,
          "max_per_club": 3,
          "min_def": 3,
          "max_def": 5,
          "min_mid": 2,
          "max_mid": 5,
          "min_fwd": 1,
          "max_fwd": 3
        }'::jsonb,
        '{}'::jsonb,
        '{"cost_per_extra": -4}'::jsonb
      )
      returning id
    `);
    const competitionId = competitionResult.rows[0].id;

    const gameweekResult = await client.query<{ id: string }>(`
      insert into fantasy.gameweeks (
        competition_id,
        number,
        name,
        deadline_at,
        start_at,
        end_at,
        status
      ) values (
        $1,
        1,
        'Gameweek 1',
        now() + interval '1 hour',
        now(),
        now() + interval '7 day',
        'live'
      )
      returning id
    `, [competitionId]);
    const gameweekId = gameweekResult.rows[0].id;

    await insertUser(
      client,
      "00000000-0000-0000-0000-000000000001",
      "fantasy-one@example.com",
      "Fantasy One",
    );
    await insertUser(
      client,
      "00000000-0000-0000-0000-000000000002",
      "fantasy-two@example.com",
      "Fantasy Two",
    );

    await seedPlayers(client);

    await client.query(`
      select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true),
             set_config('request.jwt.claim.role', 'authenticated', true)
    `);

    const entryOneResult = await client.query<{ id: string }>(`
      insert into fantasy.fantasy_entries (
        user_id,
        competition_id,
        team_name,
        bank_balance
      ) values (
        '00000000-0000-0000-0000-000000000001',
        $1,
        'Captain Testers',
        1000
      )
      returning id
    `, [competitionId]);
    const entryOneId = entryOneResult.rows[0].id;

    await client.query(`
      insert into fantasy.entry_gameweek_scores (
        entry_id,
        gameweek_id,
        transfers_made,
        transfer_cost,
        chip_played
      ) values ($1, $2, 2, -4, 'bench_boost')
    `, [entryOneId, gameweekId]);

    await client.query(
      "select public.fantasy_save_squad_selections($1, $2, $3::jsonb)",
      [
        entryOneId,
        gameweekId,
        JSON.stringify([
          { player_id: 101, position: "GK", is_starter: true, purchase_price: 50, is_captain: false, is_vice_captain: false, multiplier: 1 },
          { player_id: 102, position: "DEF", is_starter: true, purchase_price: 55, is_captain: false, is_vice_captain: true, multiplier: 1 },
          { player_id: 103, position: "MID", is_starter: true, purchase_price: 85, is_captain: true, is_vice_captain: false, multiplier: 2 },
          { player_id: 104, position: "FWD", is_starter: true, purchase_price: 90, is_captain: false, is_vice_captain: false, multiplier: 1 },
          { player_id: 106, position: "DEF", is_starter: true, purchase_price: 40, is_captain: false, is_vice_captain: false, multiplier: 1 },
          { player_id: 107, position: "DEF", is_starter: true, purchase_price: 40, is_captain: false, is_vice_captain: false, multiplier: 1 },
          { player_id: 108, position: "MID", is_starter: true, purchase_price: 40, is_captain: false, is_vice_captain: false, multiplier: 1 },
          { player_id: 109, position: "MID", is_starter: true, purchase_price: 40, is_captain: false, is_vice_captain: false, multiplier: 1 },
          { player_id: 110, position: "FWD", is_starter: true, purchase_price: 40, is_captain: false, is_vice_captain: false, multiplier: 1 },
          { player_id: 112, position: "MID", is_starter: true, purchase_price: 40, is_captain: false, is_vice_captain: false, multiplier: 1 },
          { player_id: 115, position: "DEF", is_starter: true, purchase_price: 40, is_captain: false, is_vice_captain: false, multiplier: 1 },
          { player_id: 114, position: "GK", is_starter: false, bench_order: 1, purchase_price: 40, is_captain: false, is_vice_captain: false, multiplier: 1 },
          { player_id: 111, position: "DEF", is_starter: false, bench_order: 2, purchase_price: 40, is_captain: false, is_vice_captain: false, multiplier: 1 },
          { player_id: 105, position: "MID", is_starter: false, bench_order: 3, purchase_price: 45, is_captain: false, is_vice_captain: false, multiplier: 1 },
          { player_id: 113, position: "FWD", is_starter: false, bench_order: 4, purchase_price: 40, is_captain: false, is_vice_captain: false, multiplier: 1 },
        ]),
      ],
    );

    await client.query(`
      select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true),
             set_config('request.jwt.claim.role', 'authenticated', true)
    `);

    const entryTwoResult = await client.query<{ id: string }>(`
      insert into fantasy.fantasy_entries (
        user_id,
        competition_id,
        team_name,
        bank_balance
      ) values (
        '00000000-0000-0000-0000-000000000002',
        $1,
        'Chasers',
        1000
      )
      returning id
    `, [competitionId]);
    const entryTwoId = entryTwoResult.rows[0].id;

    await client.query(`
      insert into fantasy.entry_gameweek_scores (
        entry_id,
        gameweek_id,
        transfers_made,
        transfer_cost
      ) values ($1, $2, 0, 0)
    `, [entryTwoId, gameweekId]);

    await client.query(`
      select set_config('request.jwt.claim.role', 'service_role', true)
    `);

    const statRows = [
      { player_id: 101, minutes_played: 90, goals: 1, assists: 0, clean_sheet: true, goals_conceded: 0, yellow_cards: 0, red_cards: 0, penalties_saved: 0, penalties_missed: 0, own_goals: 0, saves: 0, bonus_points: 0, defensive_contributions: 0 },
      { player_id: 102, minutes_played: 90, goals: 0, assists: 0, clean_sheet: true, goals_conceded: 0, yellow_cards: 0, red_cards: 0, penalties_saved: 0, penalties_missed: 0, own_goals: 0, saves: 0, bonus_points: 0, defensive_contributions: 0 },
      { player_id: 103, minutes_played: 90, goals: 1, assists: 1, clean_sheet: false, goals_conceded: 0, yellow_cards: 0, red_cards: 0, penalties_saved: 0, penalties_missed: 0, own_goals: 0, saves: 0, bonus_points: 3, defensive_contributions: 12 },
      { player_id: 104, minutes_played: 90, goals: 0, assists: 1, clean_sheet: false, goals_conceded: 0, yellow_cards: 0, red_cards: 0, penalties_saved: 0, penalties_missed: 0, own_goals: 0, saves: 0, bonus_points: 0, defensive_contributions: 0, stage_advanced: true },
      { player_id: 105, minutes_played: 90, goals: 1, assists: 0, clean_sheet: false, goals_conceded: 0, yellow_cards: 0, red_cards: 0, penalties_saved: 0, penalties_missed: 0, own_goals: 0, saves: 0, bonus_points: 0, defensive_contributions: 0 },
      { player_id: 106, minutes_played: 90, goals: 0, assists: 0, clean_sheet: false, goals_conceded: 2, yellow_cards: 0, red_cards: 0, penalties_saved: 0, penalties_missed: 0, own_goals: 0, saves: 0, bonus_points: 0, defensive_contributions: 0 },
      { player_id: 107, minutes_played: 90, goals: 0, assists: 0, clean_sheet: true, goals_conceded: 0, yellow_cards: 1, red_cards: 0, penalties_saved: 0, penalties_missed: 0, own_goals: 0, saves: 0, bonus_points: 0, defensive_contributions: 0 },
      { player_id: 108, minutes_played: 59, goals: 0, assists: 1, clean_sheet: false, goals_conceded: 0, yellow_cards: 0, red_cards: 0, penalties_saved: 0, penalties_missed: 0, own_goals: 0, saves: 0, bonus_points: 0, defensive_contributions: 0 },
      { player_id: 109, minutes_played: 0, goals: 0, assists: 0, clean_sheet: false, goals_conceded: 0, yellow_cards: 0, red_cards: 0, penalties_saved: 0, penalties_missed: 0, own_goals: 0, saves: 0, bonus_points: 0, defensive_contributions: 0 },
      { player_id: 110, minutes_played: 90, goals: 0, assists: 0, clean_sheet: false, goals_conceded: 0, yellow_cards: 0, red_cards: 1, penalties_saved: 0, penalties_missed: 0, own_goals: 0, saves: 0, bonus_points: 0, defensive_contributions: 0 },
      { player_id: 111, minutes_played: 90, goals: 0, assists: 0, clean_sheet: true, goals_conceded: 0, yellow_cards: 0, red_cards: 0, penalties_saved: 0, penalties_missed: 0, own_goals: 0, saves: 0, bonus_points: 0, defensive_contributions: 0 },
      { player_id: 112, minutes_played: 90, goals: 0, assists: 0, clean_sheet: false, goals_conceded: 0, yellow_cards: 0, red_cards: 0, penalties_saved: 0, penalties_missed: 0, own_goals: 0, saves: 0, bonus_points: 0, defensive_contributions: 0 },
      { player_id: 113, minutes_played: 90, goals: 1, assists: 0, clean_sheet: false, goals_conceded: 0, yellow_cards: 0, red_cards: 0, penalties_saved: 0, penalties_missed: 1, own_goals: 0, saves: 0, bonus_points: 0, defensive_contributions: 0 },
      { player_id: 114, minutes_played: 90, goals: 0, assists: 0, clean_sheet: false, goals_conceded: 0, yellow_cards: 0, red_cards: 0, penalties_saved: 0, penalties_missed: 0, own_goals: 0, saves: 6, bonus_points: 0, defensive_contributions: 0 },
      { player_id: 115, minutes_played: 90, goals: 0, assists: 0, clean_sheet: true, goals_conceded: 0, yellow_cards: 0, red_cards: 0, penalties_saved: 0, penalties_missed: 0, own_goals: 0, saves: 0, bonus_points: 1, defensive_contributions: 0 },
    ];

    const insertedStats = new Map<number, string>();
    for (const stat of statRows) {
      const result = await client.query<{ id: string }>(`
        insert into fantasy.player_gameweek_stats (
          player_id,
          gameweek_id,
          minutes_played,
          goals,
          assists,
          clean_sheet,
          goals_conceded,
          yellow_cards,
          red_cards,
          penalties_saved,
          penalties_missed,
          own_goals,
          saves,
          bonus_points,
          defensive_contributions,
          stage_advanced
        ) values (
          $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16
        )
        returning id
      `, [
        stat.player_id,
        gameweekId,
        stat.minutes_played,
        stat.goals,
        stat.assists,
        stat.clean_sheet,
        stat.goals_conceded,
        stat.yellow_cards,
        stat.red_cards,
        stat.penalties_saved,
        stat.penalties_missed,
        stat.own_goals,
        stat.saves,
        stat.bonus_points,
        stat.defensive_contributions,
        stat.stage_advanced ?? false,
      ]);
      insertedStats.set(stat.player_id, result.rows[0].id);
    }

    const gkPoints = await client.query<{ points: number }>(`
      select fantasy.compute_player_points($1::uuid, 'GK'::fantasy.player_position, $2::jsonb) as points
    `, [
      insertedStats.get(101),
      `{
        "points_sub_60": 1,
        "points_60_plus": 2,
        "goals": { "GK_DEF": 10, "MID": 6, "FWD": 4 },
        "assists_all": 3,
        "clean_sheet": { "GK_DEF": 6, "MID": 1, "FWD": 0 },
        "goals_conceded_per_2": -1,
        "saves_per_3": 1,
        "penalty_save": 5,
        "penalty_miss": -2,
        "yellow_card": -1,
        "red_card": -3,
        "own_goal": -2,
        "defensive_contributions": { "DEF_threshold": 10, "MID_FWD_threshold": 12, "points": 2 }
      }`,
    ]);
    assertEqual("GK goal scoring", gkPoints.rows[0].points, 18);

    const midPoints = await client.query<{ points: number }>(`
      select fantasy.compute_player_points($1::uuid, 'MID'::fantasy.player_position, $2::jsonb) as points
    `, [
      insertedStats.get(103),
      `{
        "points_sub_60": 1,
        "points_60_plus": 2,
        "goals": { "GK_DEF": 10, "MID": 6, "FWD": 4 },
        "assists_all": 3,
        "clean_sheet": { "GK_DEF": 6, "MID": 1, "FWD": 0 },
        "goals_conceded_per_2": -1,
        "saves_per_3": 1,
        "penalty_save": 5,
        "penalty_miss": -2,
        "yellow_card": -1,
        "red_card": -3,
        "own_goal": -2,
        "defensive_contributions": { "DEF_threshold": 10, "MID_FWD_threshold": 12, "points": 2 }
      }`,
    ]);
    assertEqual("MID goal+assist+bonus+DC scoring", midPoints.rows[0].points, 16);

    const wcForwardPoints = await client.query<{ points: number }>(`
      select fantasy.compute_player_points($1::uuid, 'FWD'::fantasy.player_position, $2::jsonb) as points
    `, [
      insertedStats.get(104),
      `{
        "points_sub_60": 1,
        "points_60_plus": 2,
        "goals": { "GK_DEF": 10, "MID": 6, "FWD": 4 },
        "assists_all": 3,
        "clean_sheet": { "GK_DEF": 6, "MID": 1, "FWD": 0 },
        "goals_conceded_per_2": -1,
        "saves_per_3": 1,
        "penalty_save": 5,
        "penalty_miss": -2,
        "yellow_card": -1,
        "red_card": -3,
        "own_goal": -2,
        "stage_advance_bonus": 5,
        "defensive_contributions": { "DEF_threshold": 10, "MID_FWD_threshold": 12, "points": 2 }
      }`,
    ]);
    assertEqual("World Cup stage advance bonus scoring", wcForwardPoints.rows[0].points, 10);

    const scoreOne = await client.query<{ points: number }>(
      "select public.fantasy_aggregate_entry_score($1, $2) as points",
      [entryOneId, gameweekId],
    );
    assertEqual("Bench boost aggregate with captain and transfer cost", scoreOne.rows[0].points, 105);

    await client.query(`
      update fantasy.entry_gameweek_scores
      set points = 70,
          calculated_at = now()
      where entry_id = $1
        and gameweek_id = $2
    `, [entryTwoId, gameweekId]);

    await client.query("select public.fantasy_rank_gameweek_entries($1)", [gameweekId]);

    const ranks = await client.query<{ entry_id: string; rank: number }>(`
      select entry_id, rank
      from fantasy.entry_gameweek_scores
      where gameweek_id = $1
      order by rank asc, entry_id asc
    `, [gameweekId]);

    assertEqual("Top rank assigned to highest scorer", ranks.rows[0].entry_id, entryOneId);
    assertEqual("Top rank numeric value", ranks.rows[0].rank, 1);

    console.log("Fantasy scoring tests passed.");
  } finally {
    await client.query("rollback");
    await client.end();
  }
}

if (import.meta.main) {
  main().catch((error) => {
    console.error(error);
    Deno.exit(1);
  });
}
