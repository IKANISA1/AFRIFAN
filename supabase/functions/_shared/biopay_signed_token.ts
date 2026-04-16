const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder();
const compactHeader = {
  alg: "HS256",
  typ: "BioPay",
};

export type SignedBioPayTokenPayload = {
  kind: string;
  v: number;
  exp: string;
  iat: string;
  nonce: string;
  [key: string]: unknown;
};

function requireSigningSecret(explicitSecret?: string): string {
  const value = explicitSecret?.trim() ||
    Deno.env.get("BioPay_TOKEN_SIGNING_KEY")?.trim() ||
    Deno.env.get("BioPay_HANDOFF_SIGNING_KEY")?.trim();

  if (!value) {
    throw new Error(
      "Missing environment variable: BioPay_TOKEN_SIGNING_KEY or BioPay_HANDOFF_SIGNING_KEY",
    );
  }

  return value;
}

function encodeBase64Url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

function decodeBase64Url(value: string): Uint8Array {
  const padded = value
    .replaceAll("-", "+")
    .replaceAll("_", "/")
    .padEnd(Math.ceil(value.length / 4) * 4, "=");
  const binary = atob(padded);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function toArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  return bytes.buffer.slice(
    bytes.byteOffset,
    bytes.byteOffset + bytes.byteLength,
  ) as ArrayBuffer;
}

async function importSigningKey(secret: string) {
  return crypto.subtle.importKey(
    "raw",
    textEncoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}

export function generateBioPayNonce(length = 24): string {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  return Array.from(bytes)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export async function signBioPayToken(
  payload: SignedBioPayTokenPayload,
  options: { secret?: string } = {},
): Promise<string> {
  const secret = requireSigningSecret(options.secret);
  const key = await importSigningKey(secret);
  const encodedHeader = encodeBase64Url(
    textEncoder.encode(JSON.stringify(compactHeader)),
  );
  const encodedPayload = encodeBase64Url(
    textEncoder.encode(JSON.stringify(payload)),
  );
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    textEncoder.encode(unsignedToken),
  );
  return `${unsignedToken}.${encodeBase64Url(new Uint8Array(signature))}`;
}

export async function verifyBioPayToken(
  token: string,
  options: { secret?: string; expectedKind?: string } = {},
): Promise<SignedBioPayTokenPayload> {
  const trimmed = token.trim();
  const segments = trimmed.split(".");
  if (segments.length != 3) {
    throw new Error("Invalid BioPay token.");
  }

  const [encodedHeader, encodedPayload, encodedSignature] = segments;
  const secret = requireSigningSecret(options.secret);
  const key = await importSigningKey(secret);
  const isValid = await crypto.subtle.verify(
    "HMAC",
    key,
    toArrayBuffer(decodeBase64Url(encodedSignature)),
    textEncoder.encode(`${encodedHeader}.${encodedPayload}`),
  );
  if (!isValid) {
    throw new Error("Invalid BioPay token signature.");
  }

  const header = JSON.parse(
    textDecoder.decode(decodeBase64Url(encodedHeader)),
  ) as Record<string, unknown>;
  if (header["alg"] !== "HS256" || header["typ"] !== "BioPay") {
    throw new Error("Unsupported BioPay token header.");
  }

  const payload = JSON.parse(
    textDecoder.decode(decodeBase64Url(encodedPayload)),
  ) as SignedBioPayTokenPayload;
  if (typeof payload.kind !== "string" || typeof payload.exp !== "string") {
    throw new Error("Invalid BioPay token payload.");
  }
  if (
    options.expectedKind != null && payload.kind.trim() !== options.expectedKind
  ) {
    throw new Error("Unexpected BioPay token kind.");
  }

  const expiresAt = Date.parse(payload.exp);
  if (Number.isNaN(expiresAt)) {
    throw new Error("Invalid BioPay token expiry.");
  }
  if (expiresAt <= Date.now()) {
    throw new Error("BioPay token has expired.");
  }

  return payload;
}
