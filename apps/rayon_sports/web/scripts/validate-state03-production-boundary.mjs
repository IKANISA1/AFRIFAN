import { readFile } from "node:fs/promises";
import { createInterface } from "node:readline/promises";
import { stdin as input, stdout as output } from "node:process";

import { createClient } from "@supabase/supabase-js";

const productionConfigUrl = new URL(
  "../../assets/flavors/production.json",
  import.meta.url,
);
const productionConfig = JSON.parse(
  await readFile(productionConfigUrl, "utf8"),
);
const supabaseUrl = productionConfig.SUPABASE_URL;
const anonKey = productionConfig.SUPABASE_ANON_KEY;
const validationTag = process.env.STATE03_VALIDATION_TAG;

if (!supabaseUrl || !anonKey || !validationTag) {
  throw new Error(
    "Production Supabase configuration and STATE03_VALIDATION_TAG are required.",
  );
}
if (!/^codex-state03-[a-z0-9-]+$/.test(validationTag)) {
  throw new Error("STATE03_VALIDATION_TAG must be a synthetic codex-state03 tag.");
}

function authClient() {
  return createClient(supabaseUrl, anonKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });
}

function accessTokenClient(accessToken) {
  return createClient(supabaseUrl, anonKey, {
    accessToken: async () => accessToken,
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });
}

function sanitizedError(error) {
  if (!error) return null;
  return {
    code: error.code ?? null,
    status: error.status ?? null,
    message: error.message ?? String(error),
  };
}

function emit(event, payload) {
  output.write(`${event} ${JSON.stringify(payload)}\n`);
}

async function requireSingleOrder(client, orderId, expectedStatus) {
  const { data, error } = await client
    .from("shop_orders")
    .select("id,status,updated_at,mock_batch")
    .eq("id", orderId);
  if (error) throw error;
  if (data.length !== 1 || data[0].status !== expectedStatus) {
    throw new Error(
      `Authenticated recovery expected one ${expectedStatus} order, received ${JSON.stringify(data)}`,
    );
  }
  return data[0];
}

const ownerAuth = authClient();
const outsiderAuth = authClient();
const signedInClients = [];
const identities = [];

try {
  for (const [ordinal, client] of [ownerAuth, outsiderAuth].entries()) {
    const { data, error } = await client.auth.signInAnonymously({
      options: {
        data: {
          club_id: "4",
          validation_tag: validationTag,
          auth_purpose: "state03_production_concurrency_boundary",
        },
      },
    });
    if (error) throw error;
    if (!data.user?.id || !data.session?.access_token) {
      throw new Error("Anonymous sign-in returned no authenticated session.");
    }
    const identity = {
      ordinal: ordinal + 1,
      user_id: data.user.id,
      is_anonymous: data.user.is_anonymous === true,
      access_token: data.session.access_token,
    };
    identities.push(identity);
    signedInClients.push(client);
    emit("STATE03_IDENTITY", {
      ordinal: identity.ordinal,
      user_id: identity.user_id,
      is_anonymous: identity.is_anonymous,
      validation_tag: validationTag,
    });
  }

  const readline = createInterface({ input, output: undefined });
  const fixtureLine = await readline.question("");
  readline.close();
  const fixture = JSON.parse(fixtureLine);
  if (
    !fixture?.order_id ||
    !fixture?.expected_updated_at ||
    !fixture?.stale_order_id ||
    !fixture?.stale_expected_updated_at ||
    fixture.validation_tag !== validationTag
  ) {
    throw new Error("Fixture handoff is incomplete or belongs to another run.");
  }

  const ownerA = accessTokenClient(identities[0].access_token);
  const ownerB = accessTokenClient(identities[0].access_token);
  const ownerRecovery = accessTokenClient(identities[0].access_token);
  const outsider = accessTokenClient(identities[1].access_token);
  const unauthenticated = authClient();

  const loaded = await requireSingleOrder(ownerA, fixture.order_id, "pending");
  if (
    loaded.updated_at !== fixture.expected_updated_at ||
    loaded.mock_batch !== validationTag
  ) {
    throw new Error("Owner loaded an unexpected fixture version or tag.");
  }

  const { data: outsiderVisible, error: outsiderReadError } = await outsider
    .from("shop_orders")
    .select("id")
    .eq("id", fixture.order_id);
  if (outsiderReadError) throw outsiderReadError;
  if (outsiderVisible.length !== 0) {
    throw new Error("RLS exposed the owner order to the outsider.");
  }

  const outsiderMutation = await outsider.rpc(
    "cancel_shop_order_if_unchanged",
    {
      p_order_id: fixture.order_id,
      p_expected_updated_at: fixture.expected_updated_at,
    },
  );
  if (!outsiderMutation.error || outsiderMutation.data !== null) {
    throw new Error("The outsider unexpectedly mutated the owner order.");
  }

  const anonymousMutation = await unauthenticated.rpc(
    "cancel_shop_order_if_unchanged",
    {
      p_order_id: fixture.order_id,
      p_expected_updated_at: fixture.expected_updated_at,
    },
  );
  if (!anonymousMutation.error || anonymousMutation.data !== null) {
    throw new Error("The anonymous role unexpectedly executed the order RPC.");
  }

  const collisionStartedAt = new Date().toISOString();
  const [left, right] = await Promise.all([
    ownerA.rpc("cancel_shop_order_if_unchanged", {
      p_order_id: fixture.order_id,
      p_expected_updated_at: fixture.expected_updated_at,
    }),
    ownerB.rpc("cancel_shop_order_if_unchanged", {
      p_order_id: fixture.order_id,
      p_expected_updated_at: fixture.expected_updated_at,
    }),
  ]);
  const collisionFinishedAt = new Date().toISOString();
  const outcomes = [left, right];
  const successes = outcomes.filter(
    (result) => !result.error && result.data?.status === "cancelled",
  );
  const conflicts = outcomes.filter((result) => result.error);
  if (successes.length !== 1 || conflicts.length !== 1) {
    throw new Error(
      `Expected one collision winner and one conflict, received ${JSON.stringify(
        outcomes.map((result) => ({
          status: result.data?.status ?? null,
          error: sanitizedError(result.error),
        })),
      )}`,
    );
  }

  const recovered = await requireSingleOrder(
    ownerRecovery,
    fixture.order_id,
    "cancelled",
  );
  const { data: outsiderAfter, error: outsiderAfterError } = await outsider
    .from("shop_orders")
    .select("id")
    .eq("id", fixture.order_id);
  if (outsiderAfterError) throw outsiderAfterError;
  if (outsiderAfter.length !== 0) {
    throw new Error("RLS exposed the cancelled owner order to the outsider.");
  }

  const [staleLoadedA, staleLoadedB] = await Promise.all([
    requireSingleOrder(ownerA, fixture.stale_order_id, "pending"),
    requireSingleOrder(ownerB, fixture.stale_order_id, "pending"),
  ]);
  if (
    staleLoadedA.updated_at !== fixture.stale_expected_updated_at ||
    staleLoadedB.updated_at !== fixture.stale_expected_updated_at ||
    staleLoadedA.mock_batch !== validationTag ||
    staleLoadedB.mock_batch !== validationTag
  ) {
    throw new Error("Independent clients did not load the same stale fixture version.");
  }

  const advancedAddress = `CODEX STATE03 ${validationTag} version advance`;
  const { data: advancedRows, error: advanceError } = await ownerA
    .from("shop_orders")
    .update({ delivery_address: advancedAddress })
    .eq("id", fixture.stale_order_id)
    .eq("updated_at", fixture.stale_expected_updated_at)
    .select("id,status,updated_at,delivery_address,mock_batch");
  if (advanceError) throw advanceError;
  if (
    advancedRows.length !== 1 ||
    advancedRows[0].status !== "pending" ||
    advancedRows[0].updated_at === fixture.stale_expected_updated_at ||
    advancedRows[0].delivery_address !== advancedAddress
  ) {
    throw new Error("The first client did not advance exactly one order version.");
  }

  const staleCancellation = await ownerB.rpc(
    "cancel_shop_order_if_unchanged",
    {
      p_order_id: fixture.stale_order_id,
      p_expected_updated_at: fixture.stale_expected_updated_at,
    },
  );
  if (
    !staleCancellation.error ||
    staleCancellation.data !== null ||
    !staleCancellation.error.message.includes("changed after it was loaded")
  ) {
    throw new Error(
      `Expected the exact stale-version rejection, received ${JSON.stringify({
        data: staleCancellation.data,
        error: sanitizedError(staleCancellation.error),
      })}`,
    );
  }

  const refreshedStaleOrder = await requireSingleOrder(
    ownerB,
    fixture.stale_order_id,
    "pending",
  );
  if (refreshedStaleOrder.updated_at !== advancedRows[0].updated_at) {
    throw new Error("The stale client did not recover the current order version.");
  }
  const recoveredCancellation = await ownerB.rpc(
    "cancel_shop_order_if_unchanged",
    {
      p_order_id: fixture.stale_order_id,
      p_expected_updated_at: refreshedStaleOrder.updated_at,
    },
  );
  if (
    recoveredCancellation.error ||
    recoveredCancellation.data?.status !== "cancelled"
  ) {
    throw new Error(
      `Authenticated retry did not cancel the refreshed order: ${JSON.stringify({
        data: recoveredCancellation.data,
        error: sanitizedError(recoveredCancellation.error),
      })}`,
    );
  }
  const recoveredStaleOrder = await requireSingleOrder(
    ownerRecovery,
    fixture.stale_order_id,
    "cancelled",
  );

  emit("STATE03_RESULT", {
    status: "passed",
    validation_tag: validationTag,
    order_id: fixture.order_id,
    owner_id: identities[0].user_id,
    outsider_id: identities[1].user_id,
    two_independent_owner_clients: true,
    collision_started_at: collisionStartedAt,
    collision_finished_at: collisionFinishedAt,
    winner_count: successes.length,
    conflict_count: conflicts.length,
    collision_outcomes: outcomes.map((result) => ({
      status: result.data?.status ?? null,
      error: sanitizedError(result.error),
    })),
    anonymous_execute_denied: true,
    outsider_read_rows_before: outsiderVisible.length,
    outsider_mutation_denied: true,
    outsider_read_rows_after: outsiderAfter.length,
    authenticated_recovery_status: recovered.status,
    stale_replay_order_id: fixture.stale_order_id,
    two_clients_loaded_same_version: true,
    first_client_advanced_version: advancedRows[0].updated_at,
    stale_client_error: sanitizedError(staleCancellation.error),
    stale_client_refreshed_version: refreshedStaleOrder.updated_at,
    authenticated_retry_status: recoveredCancellation.data.status,
    authenticated_retry_reloaded_status: recoveredStaleOrder.status,
    tokens_persisted: false,
  });
} catch (error) {
  emit("STATE03_ERROR", {
    status: "failed",
    validation_tag: validationTag,
    created_user_ids: identities.map((identity) => identity.user_id),
    error: sanitizedError(error),
  });
  process.exitCode = 1;
} finally {
  await Promise.allSettled(
    signedInClients.map((client) => client.auth.signOut({ scope: "local" })),
  );
}
