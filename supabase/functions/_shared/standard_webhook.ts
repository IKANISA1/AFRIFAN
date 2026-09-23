const standardWebhookToleranceSeconds = 5 * 60;

function decodeBase64(value: string): Uint8Array | null {
  try {
    const decoded = atob(value);
    return Uint8Array.from(decoded, (character) => character.charCodeAt(0));
  } catch {
    return null;
  }
}

function normalizeSecret(secret: string): Uint8Array | null {
  const normalized = secret.trim().replace(/^v1,whsec_/, "").replace(
    /^whsec_/,
    "",
  );
  return normalized ? decodeBase64(normalized) : null;
}

function constantTimeEqual(left: Uint8Array, right: Uint8Array): boolean {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) {
    difference |= left[index] ^ right[index];
  }
  return difference === 0;
}

function toOwnedArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  const owned = new Uint8Array(bytes.byteLength);
  owned.set(bytes);
  return owned.buffer;
}

async function expectedSignature(
  secret: Uint8Array,
  signedPayload: string,
): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey(
    "raw",
    toOwnedArrayBuffer(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      key,
      toOwnedArrayBuffer(new TextEncoder().encode(signedPayload)),
    ),
  );
}

export async function verifyStandardWebhook({
  payload,
  headers,
  secret,
  nowSeconds = Math.floor(Date.now() / 1000),
  toleranceSeconds = standardWebhookToleranceSeconds,
}: {
  payload: string;
  headers: Headers;
  secret: string;
  nowSeconds?: number;
  toleranceSeconds?: number;
}): Promise<boolean> {
  const webhookId = headers.get("webhook-id")?.trim() ?? "";
  const timestampValue = headers.get("webhook-timestamp")?.trim() ?? "";
  const signatureValue = headers.get("webhook-signature")?.trim() ?? "";
  const timestamp = Number(timestampValue);
  const secretBytes = normalizeSecret(secret);

  if (
    !webhookId ||
    !Number.isInteger(timestamp) ||
    !signatureValue ||
    secretBytes == null ||
    Math.abs(nowSeconds - timestamp) > toleranceSeconds
  ) {
    return false;
  }

  const expected = await expectedSignature(
    secretBytes,
    `${webhookId}.${timestampValue}.${payload}`,
  );
  for (const candidate of signatureValue.split(/\s+/)) {
    const [version, encoded] = candidate.split(",", 2);
    if (version !== "v1" || !encoded) continue;
    const actual = decodeBase64(encoded);
    if (actual != null && constantTimeEqual(expected, actual)) {
      return true;
    }
  }

  return false;
}
