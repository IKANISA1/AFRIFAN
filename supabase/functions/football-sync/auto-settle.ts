/**
 * auto-settle — Post-sync hook that triggers prediction settlement
 * when fixtures transition to 'finished'.
 *
 * After syncFixtures() runs, this identifies newly-finished fixtures
 * and auto-settles predictions using the prediction engine RPCs.
 */

import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export interface AutoSettleResult {
  fixtures_checked: number;
  fixtures_settled: number;
  total_predictions_won: number;
  total_predictions_lost: number;
  total_fet_awarded: number;
  challenges_locked: number;
  challenges_voided_at_lock: number;
  challenges_settled: number;
  challenges_voided: number;
  challenges_pending: number;
  errors: string[];
}

export async function autoSettleFinishedFixtures(
  adminClient: SupabaseClient,
): Promise<AutoSettleResult> {
  const result: AutoSettleResult = {
    fixtures_checked: 0,
    fixtures_settled: 0,
    total_predictions_won: 0,
    total_predictions_lost: 0,
    total_fet_awarded: 0,
    challenges_locked: 0,
    challenges_voided_at_lock: 0,
    challenges_settled: 0,
    challenges_voided: 0,
    challenges_pending: 0,
    errors: [],
  };

  const { data: lockResult, error: lockError } = await adminClient.rpc(
    "prediction_challenge_lock_due",
  );
  if (lockError) {
    result.errors.push(`Challenge lock error: ${lockError.message}`);
  } else if (lockResult && typeof lockResult === "object") {
    const lockData = lockResult as Record<string, unknown>;
    result.challenges_locked += Number(lockData.locked ?? 0);
    result.challenges_voided_at_lock += Number(
      lockData.voided_no_opponents ?? 0,
    );
  }

  // 1. Find finished fixtures that have unsettled predictions
  const { data: finishedFixtures, error } = await adminClient
    .schema("football")
    .from("fixtures")
    .select(`
      id,
      home_score,
      away_score,
      status,
      metadata
    `)
    .eq("status", "finished")
    .not("home_score", "is", null)
    .not("away_score", "is", null);

  if (error || !finishedFixtures) {
    if (error) result.errors.push(`Query error: ${error.message}`);
    return result;
  }

  // 2. For each finished fixture, check if it has unsettled predictions
  for (const fixture of finishedFixtures) {
    result.fixtures_checked++;

    // Check for unsettled predictions on this fixture
    const { data: unsettled } = await adminClient
      .schema("football")
      .from("predictions")
      .select("id")
      .eq("fixture_id", fixture.id)
      .eq("status", "pending")
      .limit(1);

    if (!unsettled || unsettled.length === 0) continue;

    // 3. Derive settlement outcomes from the match result
    const homeScore = Number(fixture.home_score ?? 0);
    const awayScore = Number(fixture.away_score ?? 0);

    const settlements = deriveSettlements(homeScore, awayScore);

    if (settlements.length === 0) continue;

    // 4. Call the settlement RPC
    try {
      const { data: settleResult, error: settleError } = await adminClient.rpc(
        "prediction_settle_fixture",
        {
          p_fixture_id: fixture.id,
          p_settlements: settlements,
        },
      );

      if (settleError) {
        console.error(
          `[auto-settle] Settlement error for fixture ${fixture.id}:`,
          settleError.message,
        );
        result.errors.push(
          `Fixture ${fixture.id}: ${settleError.message}`,
        );
        continue;
      }

      const settlementData =
        settleResult && typeof settleResult === "object"
          ? (settleResult as Record<string, unknown>)
          : {};

      result.fixtures_settled++;
      result.total_predictions_won += Number(settlementData.total_won ?? 0);
      result.total_predictions_lost += Number(settlementData.total_lost ?? 0);
      result.total_fet_awarded += Number(
        settlementData.total_fet_awarded ?? 0,
      );

      console.log(
        `[auto-settle] Settled fixture ${fixture.id}: ${homeScore}-${awayScore}`,
        settlementData,
      );
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      console.error(`[auto-settle] Error settling ${fixture.id}:`, msg);
      result.errors.push(`Fixture ${fixture.id}: ${msg}`);
    }
  }

  const { data: challengeSettlementResult, error: challengeSettlementError } =
    await adminClient.rpc("prediction_challenge_settle_due");
  if (challengeSettlementError) {
    result.errors.push(
      `Challenge settlement error: ${challengeSettlementError.message}`,
    );
  } else if (
    challengeSettlementResult && typeof challengeSettlementResult === "object"
  ) {
    const challengeData = challengeSettlementResult as Record<string, unknown>;
    result.challenges_settled += Number(challengeData.settled ?? 0);
    result.challenges_voided += Number(challengeData.voided ?? 0);
    result.challenges_pending += Number(challengeData.pending ?? 0);
  }

  return result;
}

/**
 * Derives settlement outcomes from match result.
 *
 * Maps to the prediction market slugs defined in the prediction engine:
 * - match-result: home / draw / away
 * - both-teams-to-score: yes / no
 * - over-under-2-5: over / under
 * - over-under-1-5: over / under
 * - over-under-3-5: over / under
 * - correct-score: "{home}-{away}"
 * - halftime-fulltime: various combos (would need HT data)
 */
function deriveSettlements(
  homeScore: number,
  awayScore: number,
): Array<{ market_slug: string; correct_outcome: string }> {
  const settlements: Array<{
    market_slug: string;
    correct_outcome: string;
  }> = [];

  // 1. Match Result (1X2)
  const matchResult =
    homeScore > awayScore ? "home" : homeScore < awayScore ? "away" : "draw";
  settlements.push({
    market_slug: "match-result",
    correct_outcome: matchResult,
  });

  // 2. Both Teams to Score
  const btts = homeScore > 0 && awayScore > 0 ? "yes" : "no";
  settlements.push({
    market_slug: "both-teams-to-score",
    correct_outcome: btts,
  });

  // 3. Over/Under goals markets
  const totalGoals = homeScore + awayScore;

  settlements.push({
    market_slug: "over-under-0-5",
    correct_outcome: totalGoals > 0.5 ? "over" : "under",
  });

  settlements.push({
    market_slug: "over-under-1-5",
    correct_outcome: totalGoals > 1.5 ? "over" : "under",
  });

  settlements.push({
    market_slug: "over-under-2-5",
    correct_outcome: totalGoals > 2.5 ? "over" : "under",
  });

  settlements.push({
    market_slug: "over-under-3-5",
    correct_outcome: totalGoals > 3.5 ? "over" : "under",
  });

  settlements.push({
    market_slug: "over-under-4-5",
    correct_outcome: totalGoals > 4.5 ? "over" : "under",
  });

  // 4. Correct Score
  settlements.push({
    market_slug: "correct-score",
    correct_outcome: `${homeScore}-${awayScore}`,
  });

  // 5. Double Chance
  const doubleChance =
    homeScore >= awayScore
      ? homeScore === awayScore
        ? "home-draw"
        : "home-draw"
      : "away-draw";
  settlements.push({
    market_slug: "double-chance",
    correct_outcome: doubleChance,
  });

  // Also handle 1X, X2, 12 variants
  if (homeScore > awayScore) {
    settlements.push({ market_slug: "double-chance-1x", correct_outcome: "1x" });
    settlements.push({ market_slug: "double-chance-12", correct_outcome: "12" });
  } else if (homeScore === awayScore) {
    settlements.push({ market_slug: "double-chance-1x", correct_outcome: "1x" });
    settlements.push({ market_slug: "double-chance-x2", correct_outcome: "x2" });
  } else {
    settlements.push({ market_slug: "double-chance-x2", correct_outcome: "x2" });
    settlements.push({ market_slug: "double-chance-12", correct_outcome: "12" });
  }

  // 6. Total Goals Exact
  settlements.push({
    market_slug: "total-goals-exact",
    correct_outcome: String(totalGoals),
  });

  // 7. Home/Away Total Goals
  settlements.push({
    market_slug: "home-total-goals",
    correct_outcome: String(homeScore),
  });
  settlements.push({
    market_slug: "away-total-goals",
    correct_outcome: String(awayScore),
  });

  // 8. Clean sheets
  settlements.push({
    market_slug: "home-clean-sheet",
    correct_outcome: awayScore === 0 ? "yes" : "no",
  });
  settlements.push({
    market_slug: "away-clean-sheet",
    correct_outcome: homeScore === 0 ? "yes" : "no",
  });

  // 9. Win to Nil
  settlements.push({
    market_slug: "home-win-to-nil",
    correct_outcome: homeScore > awayScore && awayScore === 0 ? "yes" : "no",
  });
  settlements.push({
    market_slug: "away-win-to-nil",
    correct_outcome: awayScore > homeScore && homeScore === 0 ? "yes" : "no",
  });

  return settlements;
}
