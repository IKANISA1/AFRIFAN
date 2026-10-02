import { HttpError } from "./http_error.ts";
import { readBoundedBytes } from "./http.ts";

export const gatewayProtocol = "africlub.receiver-settlement.v1";
export const refundGatewayProtocol = "africlub.receiver-refund-settlement.v1";
export type GatewayProtocol =
  | typeof gatewayProtocol
  | typeof refundGatewayProtocol;
export const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const encoder = new TextEncoder();
const components =
  '("@method" "@target-uri" "content-type" "content-digest" "x-africlub-gateway-protocol")';
export type GatewayProjection = {
  protocol: typeof gatewayProtocol;
  eventId: string;
  checkoutReference: string;
  providerTransactionId: string;
  receiver: string;
  provider: string;
  country: string;
  currency: string;
  amount: number;
  settledAt: string;
  payerAccountDigest: string;
  settlementStatus: "settled";
  settlementRecordId: string;
  settlementRecordDigest: string;
};
export type GatewaySignature = {
  protocol: GatewayProtocol;
  keyId: string;
  nonce: string;
  created: number;
  expires: number;
  parameters: string;
  signature: Uint8Array;
};

function decode64(value: string): Uint8Array {
  try {
    const result = Uint8Array.from(atob(value), (c) => c.charCodeAt(0));
    if (btoa(String.fromCharCode(...result)) !== value) throw new Error();
    return result;
  } catch {
    throw new HttpError(401, "Gateway authentication required.");
  }
}
export function encode64(value: Uint8Array): string {
  return btoa(String.fromCharCode(...value));
}
export async function sha256(value: Uint8Array): Promise<Uint8Array> {
  return new Uint8Array(
    await crypto.subtle.digest("SHA-256", new Uint8Array(value)),
  );
}
export function signatureParameters(
  keyId: string,
  nonce: string,
  created: number,
  expires: number,
): string {
  return `${components};created=${created};expires=${expires};nonce="${nonce}";keyid="${keyId}";alg="hmac-sha256"`;
}
export function signatureBase(
  targetUri: string,
  contentDigest: string,
  parameters: string,
  protocol: GatewayProtocol = gatewayProtocol,
): string {
  return `"@method": POST\n"@target-uri": ${targetUri}\n"content-type": application/json\n"content-digest": ${contentDigest}\n"x-africlub-gateway-protocol": ${protocol}\n"@signature-params": ${parameters}`;
}
/** Deliberately supports one fixed RFC 9421 application profile, never arbitrary signed components. */
export function readGatewaySignature(
  request: Request,
  now = Math.floor(Date.now() / 1000),
): GatewaySignature {
  const input = request.headers.get("signature-input") ?? "";
  const signature = request.headers.get("signature") ?? "";
  const protocol = request.headers.get("x-africlub-gateway-protocol");
  if (
    request.method !== "POST" || input.length > 600 || signature.length > 100 ||
    request.headers.get("content-type") !== "application/json" ||
    (protocol !== gatewayProtocol && protocol !== refundGatewayProtocol)
  ) throw new HttpError(401, "Gateway authentication required.");
  const match =
    /^sig1=(\("@method" "@target-uri" "content-type" "content-digest" "x-africlub-gateway-protocol"\);created=(\d{10});expires=(\d{10});nonce="([0-9a-f-]{36})";keyid="([0-9a-f-]{36})";alg="hmac-sha256")$/
      .exec(input);
  const signed = /^sig1=:([A-Za-z0-9+/]{43}=):$/.exec(signature);
  if (!match || !signed || !uuid.test(match[4]) || !uuid.test(match[5])) {
    throw new HttpError(401, "Gateway authentication required.");
  }
  const created = Number(match[2]), expires = Number(match[3]);
  if (
    created > now + 30 || created < now - 300 || expires <= now ||
    expires < created || expires - created > 300
  ) throw new HttpError(401, "Gateway signature expired.");
  return {
    protocol,
    parameters: match[1],
    created,
    expires,
    nonce: match[4],
    keyId: match[5],
    signature: decode64(signed[1]),
  };
}
export async function gatewayKey(secret: string): Promise<CryptoKey> {
  const bytes = decode64(secret);
  if (bytes.length < 32 || bytes.length > 64) {
    throw new HttpError(503, "Gateway authentication is unavailable.");
  }
  return await crypto.subtle.importKey(
    "raw",
    new Uint8Array(bytes),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}
export async function verifySignedGatewayJson(
  request: Request,
  signature: GatewaySignature,
  secret: string,
  targetUri: string,
): Promise<{ data: Record<string, unknown>; digest: string }> {
  if (
    request.headers.has("origin") || new URL(request.url).search ||
    !targetUri.startsWith("https://")
  ) throw new HttpError(401, "Gateway authentication required.");
  const digest = request.headers.get("content-digest") ?? "";
  const match = /^sha-256=:([A-Za-z0-9+/]{43}=):$/.exec(digest);
  if (
    !match ||
    !await crypto.subtle.verify(
      "HMAC",
      await gatewayKey(secret),
      new Uint8Array(signature.signature),
      encoder.encode(
        signatureBase(
          targetUri,
          digest,
          signature.parameters,
          signature.protocol,
        ),
      ),
    )
  ) throw new HttpError(401, "Gateway authentication required.");
  const bytes = await readBoundedBytes(request, {
    maxBytes: 8192,
    timeoutMs: 5000,
  });
  const actual = encode64(await sha256(bytes));
  if (actual !== match[1]) {
    throw new HttpError(401, "Gateway content digest mismatch.");
  }
  let body: unknown;
  try {
    body = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
  } catch {
    throw new HttpError(400, "Gateway evidence must contain JSON.");
  }
  if (
    !body || typeof body !== "object" || Array.isArray(body) ||
    (body as Record<string, unknown>).protocol !== signature.protocol
  ) {
    throw new HttpError(400, "Gateway evidence protocol mismatch.");
  }
  return { data: body as Record<string, unknown>, digest: actual };
}
export async function verifyGatewayRequest(
  request: Request,
  signature: GatewaySignature,
  secret: string,
  targetUri: string,
): Promise<{ projection: GatewayProjection; digest: string }> {
  const verified = await verifySignedGatewayJson(
    request,
    signature,
    secret,
    targetUri,
  );
  return {
    projection: validateProjection(verified.data),
    digest: verified.digest,
  };
}
export function validateProjection(value: unknown): GatewayProjection {
  const fields = [
    "protocol",
    "eventId",
    "checkoutReference",
    "providerTransactionId",
    "receiver",
    "provider",
    "country",
    "currency",
    "amount",
    "settledAt",
    "settlementStatus",
    "payerAccountDigest",
    "settlementRecordId",
    "settlementRecordDigest",
  ];
  if (
    !value || typeof value !== "object" || Array.isArray(value) ||
    Object.keys(value).sort().join() !== fields.sort().join()
  ) throw new HttpError(400, "Unsupported gateway evidence fields.");
  const p = value as GatewayProjection;
  if (
    fields.some((field) =>
      field !== "amount" &&
      typeof (value as Record<string, unknown>)[field] !== "string"
    )
  ) throw new HttpError(400, "Invalid receiver settlement evidence.");
  if (
    p.protocol !== gatewayProtocol || p.settlementStatus !== "settled" ||
    !/^[0-9a-f]{64}$/.test(p.payerAccountDigest) ||
    !uuid.test(p.eventId) || !Number.isSafeInteger(p.amount) || p.amount < 1 ||
    p.amount > 2_000_000_000 ||
    !/^[A-Za-z0-9_-]{1,128}$/.test(p.checkoutReference) ||
    !/^[A-Za-z0-9_-]{1,128}$/.test(p.providerTransactionId) ||
    !/^\d{3,20}$/.test(p.receiver) ||
    !/^[a-z][a-z0-9_]{1,39}$/.test(p.provider) ||
    !/^[A-Z]{2}$/.test(p.country) || !/^[A-Z]{3}$/.test(p.currency) ||
    !/^[A-Za-z0-9_.:/-]{1,128}$/.test(p.settlementRecordId) ||
    !/^[0-9a-f]{64}$/.test(p.settlementRecordDigest) ||
    !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{3})?Z$/.test(p.settledAt) ||
    !Number.isFinite(Date.parse(p.settledAt))
  ) throw new HttpError(400, "Invalid receiver settlement evidence.");
  return p;
}
