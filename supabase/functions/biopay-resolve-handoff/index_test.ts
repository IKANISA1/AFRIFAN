import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";

import {
  type BioPayResolveHandoffDependencies,
  createBioPayResolveHandoffHandler,
} from "./index.ts";

function buildDependencies(): BioPayResolveHandoffDependencies {
  return {
    verifyBioPayToken: async () => ({
      kind: "handoff_request",
      v: 1,
      iat: "2026-03-30T12:00:00.000Z",
      exp: "2026-03-30T12:01:00.000Z",
      nonce: "nonce-1",
      channel: "nfc",
      amount: 4000,
      reference: "matchday",
      public_id: "public-1",
      display_name: "Marie",
      route_type: "phone_number",
      recipient_value: "0781234567",
      country_code: "RW",
      currency_code: "RWF",
      currency_symbol: "FRw",
      payment_method: "ussd_dial",
      payment_template: "*182*1*1*{momo}*{amount}#",
    }),
    buildPaymentCode: ({ routeType, recipientValue, amount }) =>
      routeType == "phone_number"
        ? `*182*1*1*${recipientValue}*${amount}#`
        : `*182*8*1*${recipientValue}*${amount}#`,
  };
}

Deno.test("BioPay-resolve-handoff redirects GET requests to a dial URI", async () => {
  const handler = createBioPayResolveHandoffHandler(buildDependencies());
  const response = await handler(
    new Request(
      "https://example.com/functions/v1/BioPay-resolve-handoff?token=abc123",
      {
        method: "GET",
      },
    ),
  );

  assertEquals(response.status, 302);
  assertEquals(
    response.headers.get("Location"),
    "tel:*182*1*1*0781234567*4000%23",
  );
});

Deno.test("BioPay-resolve-handoff returns JSON resolution data on POST", async () => {
  const handler = createBioPayResolveHandoffHandler(buildDependencies());
  const response = await handler(
    new Request("https://example.com/functions/v1/BioPay-resolve-handoff", {
      method: "POST",
      headers: {
        "content-type": "application/json",
      },
      body: JSON.stringify({
        token: "abc123",
      }),
    }),
  );
  const payload = await response.json();

  assertEquals(response.status, 200);
  assertEquals(payload.success, true);
  assertEquals(payload.data.channel, "nfc");
  assertEquals(payload.data.amount, 4000);
  assertEquals(payload.data.payment_code, "*182*1*1*0781234567*4000#");
  assertEquals(payload.data.payment_method, "ussd_dial");
  assertEquals(payload.data.currency_code, "RWF");
});
