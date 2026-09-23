import {
  buildEventTicketClass,
  buildEventTicketObject,
  derivePassTotpSecretHex,
  parsePreparedWalletTicket,
  updateGoogleWalletTicketState,
  walletResourceIds,
} from "./ticket_wallet.ts";

function assertEquals(actual: unknown, expected: unknown) {
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);
  if (actualJson !== expectedJson) {
    throw new Error(`Expected ${expectedJson}, received ${actualJson}`);
  }
}

async function assertRejects(
  operation: () => Promise<unknown>,
  message: string,
) {
  try {
    await operation();
  } catch (error) {
    if (error instanceof Error && error.message.includes(message)) return;
    throw new Error(`Expected rejection containing ${message}.`);
  }
  throw new Error(`Expected rejection containing ${message}.`);
}

const credentialId = "11111111-1111-4111-8111-111111111111";

Deno.test("Wallet secrets are stable and bound to credential identity and version", async () => {
  const master = "a-secure-test-master-secret-that-is-long-enough";
  const first = await derivePassTotpSecretHex(master, credentialId, 1);
  assertEquals(first, await derivePassTotpSecretHex(master, credentialId, 1));
  if (first === await derivePassTotpSecretHex(master, credentialId, 2)) {
    throw new Error("Credential versions must have separate secrets.");
  }
  await assertRejects(() => derivePassTotpSecretHex("short", credentialId, 1), "32 characters");
});

Deno.test("Wallet object uses rotating barcode without a static fallback", () => {
  const ticket = parsePreparedWalletTicket({
    status: "success",
    code: "ready",
    ticket_id: "22222222-2222-4222-8222-222222222222",
    ticket_number: "222222222222",
    credential_id: credentialId,
    credential_version: 1,
    ticket_event_id: "33333333-3333-4333-8333-333333333333",
    organization_id: "44444444-4444-4444-8444-444444444444",
    organization_name: "Rayon Sports",
    issuer_id: "123456789012345678",
    entry_opens_at: "2026-08-13T14:00:00Z",
    entry_closes_at: "2026-08-13T20:00:00Z",
    seat_type: "general",
    match_id: "55555555-5555-4555-8555-555555555555",
    home_team: "Rayon Sports",
    away_team: "Visitors",
    competition: "League",
    venue: "Stadium",
    venue_address: "Kigali",
    venue_country_code: "RW",
    venue_timezone: "Africa/Kigali",
    match_date: "2026-08-13",
    kickoff_time: "18:00:00",
  });
  const ids = walletResourceIds(ticket);
  const eventClass = buildEventTicketClass(ticket, ids.classId);
  const object = buildEventTicketObject(
    ticket,
    ids.classId,
    ids.objectId,
    "3132333435363738393031323334353637383930",
  );
  assertEquals(object["barcode"], undefined);
  assertEquals(
    (object["passConstraints"] as Record<string, unknown>)[
      "screenshotEligibility"
    ],
    "INELIGIBLE",
  );
  assertEquals(
    (object["rotatingBarcode"] as Record<string, unknown>)["valuePattern"],
    `AFC1.${credentialId}.1.{totp_timestamp_seconds}.{totp_value_0}`,
  );
  assertEquals(
    eventClass["multipleDevicesAndHoldersAllowedStatus"],
    "ONE_USER_ALL_DEVICES",
  );
});

Deno.test("Wallet state synchronization sends a bounded object state patch", async () => {
  const keyPair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const privateKeyBytes = new Uint8Array(
    await crypto.subtle.exportKey("pkcs8", keyPair.privateKey),
  );
  let binary = "";
  for (const byte of privateKeyBytes) binary += String.fromCharCode(byte);
  const privateKey = `-----BEGIN PRIVATE KEY-----\n${
    btoa(binary)
  }\n-----END PRIVATE KEY-----`;
  const requests: Array<{ url: string; method: string; body: string }> = [];

  await updateGoogleWalletTicketState({
    objectId: "123456789012345678.africlub_ticket_abc",
    state: "COMPLETED",
    serviceAccount: {
      clientEmail: "wallet@example.iam.gserviceaccount.com",
      privateKey,
    },
    now: new Date("2026-08-13T18:00:00Z"),
    fetcher: async (input, init) => {
      const url = String(input);
      requests.push({
        url,
        method: init?.method ?? "GET",
        body: typeof init?.body === "string" ? init.body : "",
      });
      if (url === "https://oauth2.googleapis.com/token") {
        return Response.json({
          access_token: "test-access-token",
          expires_in: 3600,
        });
      }
      return new Response(null, { status: 200 });
    },
  });

  assertEquals(requests.length, 2);
  assertEquals(
    requests[1].url,
    "https://walletobjects.googleapis.com/walletobjects/v1/eventTicketObject/123456789012345678.africlub_ticket_abc",
  );
  assertEquals(requests[1].method, "PATCH");
  assertEquals(requests[1].body, '{"state":"COMPLETED"}');
});
