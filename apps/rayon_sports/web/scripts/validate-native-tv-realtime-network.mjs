import { execFileSync } from "node:child_process";

import { createClient } from "@supabase/supabase-js";

const apiUrl = process.env.TV_REALTIME_API_URL;
const anonKey = process.env.TV_REALTIME_ANON_KEY;
const dbContainer = process.env.TV_REALTIME_DB_CONTAINER;

if (!apiUrl || !anonKey || !dbContainer) {
  throw new Error(
    "TV_REALTIME_API_URL, TV_REALTIME_ANON_KEY, and TV_REALTIME_DB_CONTAINER are required.",
  );
}

const clubId = 9900201;
const sessionId = "99000000-0000-4000-8000-000000000231";
const displayId = "99000000-0000-4000-8000-000000000251";
const token = "a".repeat(64);
const topic = `${clubId}:game_session:${sessionId}`;

function query(sql) {
  return execFileSync(
    "docker",
    [
      "exec",
      "-i",
      dbContainer,
      "psql",
      "-U",
      "postgres",
      "-d",
      "postgres",
      "-v",
      "ON_ERROR_STOP=1",
      "-c",
      sql,
    ],
    { encoding: "utf8" },
  );
}

function client() {
  return createClient(apiUrl, anonKey, {
    auth: {
      autoRefreshToken: true,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });
}

function realtimeClient(accessToken) {
  return createClient(apiUrl, anonKey, {
    accessToken: async () => accessToken,
    auth: {
      persistSession: false,
      detectSessionInUrl: false,
    },
  });
}

function waitForSubscription(channel, label) {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(
      () => reject(new Error(`${label} subscription timed out`)),
      10_000,
    );
    channel.subscribe((status, error) => {
      if (status === "SUBSCRIBED") {
        clearTimeout(timeout);
        resolve();
      } else if (
        status === "CHANNEL_ERROR" ||
        status === "TIMED_OUT" ||
        status === "CLOSED"
      ) {
        clearTimeout(timeout);
        reject(error ?? new Error(`${label} subscription failed: ${status}`));
      }
    });
  });
}

function waitForSequence(events, sequence) {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(
      () => reject(new Error(`event ${sequence} timed out`)),
      5_000,
    );
    const poll = setInterval(() => {
      const found = events.find(
        (event) => Number(event.event_sequence) === sequence,
      );
      if (found) {
        clearInterval(poll);
        clearTimeout(timeout);
        resolve(found);
      }
    }, 10);
  });
}

query(`
  delete from public.african_football_clubs where id = ${clubId};
  insert into public.african_football_clubs (
    id, club_name, country_name, club_slug
  ) overriding system value values (
    ${clubId},
    'Native TV Realtime Network Club',
    'Rwanda',
    'native-tv-realtime-network-club'
  );
  insert into africlub_game.tv_devices (
    id, club_id, device_label, pairing_code, status, owner_user_id,
    scope_type, app_version, capabilities, credential_token_hash
  ) values (
    '${displayId}',
    ${clubId},
    'Network Contract TV',
    'NETWORK-CONTRACT-TV',
    'paired',
    null,
    'home',
    '2.0.0-network-contract',
    '{"platform":"android_tv","projection_version":2}'::jsonb,
    encode(digest('${token}', 'sha256'), 'hex')
  );
  insert into africlub_game.game_sessions (
    id, club_id, title, status, lifecycle_phase, join_code,
    session_version, question_version, event_sequence, eligibility_scope
  ) values (
    '${sessionId}',
    ${clubId},
    'Native TV Realtime Network Session',
    'scheduled',
    'scheduled',
    'NETWORK-CONTRACT-PRIVATE',
    1,
    0,
    0,
    'invitation_only'
  );
  insert into africlub_game.display_assignments (
    club_id, session_id, display_id
  ) values (${clubId}, '${sessionId}', '${displayId}');
`);

const authorized = client();
const unauthorized = client();
const authorizedEvents = [];
const unauthorizedEvents = [];
let authorizedRealtime;
let unauthorizedRealtime;
let authorizedChannel;
let unauthorizedChannel;

try {
  const realtimeTokens = [];
  for (const instance of [authorized, unauthorized]) {
    const { data, error } = await instance.auth.signInAnonymously({
      options: {
        data: {
          club_id: String(clubId),
          auth_purpose: "native_tv_realtime_network_contract",
        },
      },
    });
    if (error) throw error;
    if (!data.user || !data.session?.access_token) {
      throw new Error("anonymous sign-in returned no authenticated session");
    }
    realtimeTokens.push(data.session.access_token);
  }
  authorizedRealtime = realtimeClient(realtimeTokens[0]);
  unauthorizedRealtime = realtimeClient(realtimeTokens[1]);

  const { data: identity, error: identityError } = await authorized.rpc(
    "bind_tv_realtime_identity_v2",
    { p_device_token: token },
  );
  if (identityError) throw identityError;
  if (
    identity?.status !== "ready" ||
    identity?.club_id !== String(clubId) ||
    identity?.display_id !== displayId ||
    identity?.authorization !== "assigned_session_events_only"
  ) {
    throw new Error(`unexpected identity response: ${JSON.stringify(identity)}`);
  }

  const changeFilter = {
    event: "INSERT",
    schema: "africlub_game",
    table: "game_events",
    filter: `topic=eq.${topic}`,
  };
  authorizedChannel = authorizedRealtime
    .channel(`native-tv:${topic}`)
    .on("postgres_changes", changeFilter, (payload) => {
      authorizedEvents.push(payload.new);
    });
  unauthorizedChannel = unauthorizedRealtime
    .channel(`unbound-native-tv:${topic}`)
    .on("postgres_changes", changeFilter, (payload) => {
      unauthorizedEvents.push(payload.new);
    });

  await Promise.all([
    waitForSubscription(authorizedChannel, "authorized TV"),
    waitForSubscription(unauthorizedChannel, "unbound TV"),
  ]);

  const latencies = [];
  for (let sequence = 1; sequence <= 5; sequence += 1) {
    const waiting = waitForSequence(authorizedEvents, sequence);
    const startedAt = Date.now();
    query(`
      insert into africlub_game.game_events (
        club_id, session_id, topic, event_type, session_version,
        question_version, event_sequence, payload
      ) values (
        ${clubId},
        '${sessionId}',
        '${topic}',
        'projection_invalidated',
        ${sequence + 1},
        ${sequence},
        ${sequence},
        '{"requires_projection_refresh":true}'::jsonb
      );
    `);
    const event = await waiting;
    latencies.push(Date.now() - startedAt);
    if (
      event.topic !== topic ||
      event.session_id !== sessionId ||
      event.payload?.requires_projection_refresh !== true ||
      "correct_option_key" in event.payload ||
      "display_name" in event.payload
    ) {
      throw new Error(`unsafe or wrongly scoped event: ${JSON.stringify(event)}`);
    }
  }

  await new Promise((resolve) => setTimeout(resolve, 500));
  if (unauthorizedEvents.length !== 0) {
    throw new Error("an unbound authenticated TV received a game event");
  }
  const receivedSequences = authorizedEvents.map((event) =>
    Number(event.event_sequence),
  );
  if (receivedSequences.join(",") !== "1,2,3,4,5") {
    throw new Error(`events arrived out of order: ${receivedSequences.join(",")}`);
  }

  query(`
    update africlub_game.tv_devices
    set status = 'disabled',
        credential_revoked_at = timezone('utc', now())
    where id = '${displayId}';
    insert into africlub_game.game_events (
      club_id, session_id, topic, event_type, session_version,
      question_version, event_sequence, payload
    ) values (
      ${clubId},
      '${sessionId}',
      '${topic}',
      'projection_invalidated',
      7,
      6,
      6,
      '{"requires_projection_refresh":true}'::jsonb
    );
  `);
  await new Promise((resolve) => setTimeout(resolve, 1_000));
  if (authorizedEvents.length !== 5 || unauthorizedEvents.length !== 0) {
    throw new Error("revoked or unbound TV received an invalidation event");
  }

  const identityState = query(`
    select coalesce(device_auth_user_id::text, 'cleared') as identity
    from africlub_game.tv_devices
    where id = '${displayId}';
  `);
  if (!identityState.includes("cleared")) {
    throw new Error("revocation did not clear the TV Realtime identity");
  }

  const sortedLatencies = [...latencies].sort((left, right) => left - right);
  const p95 = sortedLatencies[Math.ceil(sortedLatencies.length * 0.95) - 1];
  process.stdout.write(
    JSON.stringify(
      {
        status: "passed",
        authorized_event_count: authorizedEvents.length,
        unauthorized_event_count: unauthorizedEvents.length,
        unbound_channel_connected_but_rls_filtered: true,
        ordered_sequences: receivedSequences,
        local_delivery_ms: latencies,
        local_delivery_p95_ms: p95,
        revoked_event_delivered: false,
        event_topic: topic,
        realtime_token_mode: "auth_issued_access_token",
      },
      null,
      2,
    ) + "\n",
  );
} finally {
  if (authorizedChannel && authorizedRealtime) {
    await authorizedRealtime.removeChannel(authorizedChannel);
  }
  if (unauthorizedChannel && unauthorizedRealtime) {
    await unauthorizedRealtime.removeChannel(unauthorizedChannel);
  }
  await Promise.allSettled([
    authorized.auth.signOut(),
    unauthorized.auth.signOut(),
  ]);
  query(`delete from public.african_football_clubs where id = ${clubId};`);
}
