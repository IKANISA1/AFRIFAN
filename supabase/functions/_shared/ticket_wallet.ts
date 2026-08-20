export const WALLET_TOTP_PERIOD_MILLIS = 30_000;
export const WALLET_TOTP_DIGITS = 8;

export class TicketWalletValidationError extends Error {
  constructor(
    public readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

export class GoogleWalletApiError extends Error {
  constructor(
    public readonly operation: "authorization" | "state_update",
    public readonly status: number,
  ) {
    super(`Google Wallet ${operation} failed (${status}).`);
  }
}

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ISSUER_ID_PATTERN = /^[0-9]{8,32}$/;
const WALLET_RESOURCE_ID_PATTERN = /^[0-9]{8,32}\.[A-Za-z0-9._-]{1,220}$/;
const ROTATING_BARCODE_PATTERN =
  /^AFC1\.([0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})\.([1-9][0-9]{0,8})\.([0-9]{10,13})\.([0-9]{8})$/i;

export type GoogleServiceAccount = {
  clientEmail: string;
  privateKey: string;
};

export type PreparedWalletTicket = {
  ticketId: string;
  ticketNumber: string;
  credentialId: string;
  credentialVersion: number;
  ticketEventId: string;
  organizationId: string;
  organizationName: string;
  issuerId: string;
  entryOpensAt: string;
  entryClosesAt: string;
  seatType: string;
  matchId: string;
  homeTeam: string;
  awayTeam: string;
  competition: string;
  venue: string;
  venueAddress: string;
  venueCountryCode: string;
  venueTimezone: string;
  matchDate: string;
  kickoffTime: string;
};

export type RotatingBarcode = {
  credentialId: string;
  credentialVersion: number;
  timestampSeconds: number;
  totp: string;
};

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(
    /=+$/,
    "",
  );
}

function textToBase64Url(value: unknown): string {
  return bytesToBase64Url(new TextEncoder().encode(JSON.stringify(value)));
}

function pemToBytes(pem: string): Uint8Array {
  const base64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replaceAll(/\s/g, "");
  if (!base64) throw new Error("Google Wallet private key is invalid.");
  const binary = atob(base64);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function hexToBytes(hex: string): Uint8Array {
  if (!/^[0-9a-f]+$/i.test(hex) || hex.length % 2 !== 0) {
    throw new Error("Invalid hexadecimal secret.");
  }
  return Uint8Array.from(
    { length: hex.length / 2 },
    (_, index) => Number.parseInt(hex.slice(index * 2, index * 2 + 2), 16),
  );
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join(
    "",
  );
}

function bytesToArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  const copy = new Uint8Array(new ArrayBuffer(bytes.byteLength));
  copy.set(bytes);
  return copy.buffer;
}

function requiredString(
  value: unknown,
  field: string,
  maximum = 255,
): string {
  if (typeof value !== "string") throw new Error(`${field} is missing.`);
  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > maximum) {
    throw new Error(`${field} is invalid.`);
  }
  return normalized;
}

function requiredUuid(value: unknown, field: string): string {
  const normalized = requiredString(value, field, 36);
  if (!UUID_PATTERN.test(normalized)) throw new Error(`${field} is invalid.`);
  return normalized.toLowerCase();
}

function requiredPositiveInteger(value: unknown, field: string): number {
  if (!Number.isSafeInteger(value) || Number(value) < 1) {
    throw new Error(`${field} is invalid.`);
  }
  return Number(value);
}

function normalizedCountryCode(value: unknown): string {
  const countryCode = requiredString(value, "venue_country_code", 2)
    .toUpperCase();
  if (!/^[A-Z]{2}$/.test(countryCode)) {
    throw new Error("venue_country_code is invalid.");
  }
  return countryCode;
}

export function parsePreparedWalletTicket(
  value: unknown,
): PreparedWalletTicket {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Wallet preparation result is invalid.");
  }
  const source = value as Record<string, unknown>;
  if (source["status"] !== "success" || source["code"] !== "ready") {
    const code = typeof source["code"] === "string"
      ? source["code"]
      : "not_ready";
    throw new TicketWalletValidationError(409, code);
  }
  const issuerId = requiredString(source["issuer_id"], "issuer_id", 32);
  if (!ISSUER_ID_PATTERN.test(issuerId)) {
    throw new Error("issuer_id is invalid.");
  }

  return {
    ticketId: requiredUuid(source["ticket_id"], "ticket_id"),
    ticketNumber: requiredString(source["ticket_number"], "ticket_number", 24),
    credentialId: requiredUuid(source["credential_id"], "credential_id"),
    credentialVersion: requiredPositiveInteger(
      source["credential_version"],
      "credential_version",
    ),
    ticketEventId: requiredUuid(source["ticket_event_id"], "ticket_event_id"),
    organizationId: requiredUuid(source["organization_id"], "organization_id"),
    organizationName: requiredString(
      source["organization_name"],
      "organization_name",
      120,
    ),
    issuerId,
    entryOpensAt: requiredString(
      source["entry_opens_at"],
      "entry_opens_at",
      64,
    ),
    entryClosesAt: requiredString(
      source["entry_closes_at"],
      "entry_closes_at",
      64,
    ),
    seatType: requiredString(source["seat_type"], "seat_type", 64),
    matchId: requiredUuid(source["match_id"], "match_id"),
    homeTeam: requiredString(source["home_team"], "home_team", 120),
    awayTeam: requiredString(source["away_team"], "away_team", 120),
    competition: requiredString(source["competition"], "competition", 120),
    venue: requiredString(source["venue"], "venue", 160),
    venueAddress: requiredString(source["venue_address"], "venue_address", 240),
    venueCountryCode: normalizedCountryCode(source["venue_country_code"]),
    venueTimezone: requiredString(
      source["venue_timezone"],
      "venue_timezone",
      64,
    ),
    matchDate: requiredString(source["match_date"], "match_date", 10),
    kickoffTime: requiredString(source["kickoff_time"], "kickoff_time", 24),
  };
}

export function parseGoogleServiceAccount(raw: string): GoogleServiceAccount {
  let value: unknown;
  try {
    value = JSON.parse(raw);
  } catch {
    throw new Error("GOOGLE_WALLET_SERVICE_ACCOUNT_JSON is invalid.");
  }
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("GOOGLE_WALLET_SERVICE_ACCOUNT_JSON is invalid.");
  }
  const source = value as Record<string, unknown>;
  const clientEmail = requiredString(
    source["client_email"],
    "client_email",
    320,
  );
  const privateKey = requiredString(
    source["private_key"],
    "private_key",
    10_000,
  );
  if (!clientEmail.includes("@") || !privateKey.includes("BEGIN PRIVATE KEY")) {
    throw new Error("Google Wallet service account credentials are invalid.");
  }
  return { clientEmail, privateKey };
}

async function importPrivateKey(privateKey: string): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    "pkcs8",
    bytesToArrayBuffer(pemToBytes(privateKey)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

export async function signRs256Jwt(
  serviceAccount: GoogleServiceAccount,
  payload: Record<string, unknown>,
): Promise<string> {
  const encodedHeader = textToBase64Url({ alg: "RS256", typ: "JWT" });
  const encodedPayload = textToBase64Url(payload);
  const unsigned = `${encodedHeader}.${encodedPayload}`;
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    await importPrivateKey(serviceAccount.privateKey),
    new TextEncoder().encode(unsigned),
  );
  return `${unsigned}.${bytesToBase64Url(new Uint8Array(signature))}`;
}

export async function derivePassTotpSecretHex(
  masterSecret: string,
  credentialId: string,
  credentialVersion: number,
): Promise<string> {
  if (masterSecret.trim().length < 32) {
    throw new Error(
      "GOOGLE_WALLET_TOTP_MASTER_SECRET must be at least 32 characters.",
    );
  }
  if (!UUID_PATTERN.test(credentialId) || credentialVersion < 1) {
    throw new Error("Ticket credential is invalid.");
  }
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(masterSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(
      `africlub-google-wallet-ticket:${credentialId.toLowerCase()}:${credentialVersion}`,
    ),
  );
  return bytesToHex(new Uint8Array(signature).slice(0, 20));
}

export async function generateTotpFromHex(
  secretHex: string,
  timestampSeconds: number,
  periodMillis = WALLET_TOTP_PERIOD_MILLIS,
  digits = WALLET_TOTP_DIGITS,
): Promise<string> {
  if (!Number.isSafeInteger(timestampSeconds) || timestampSeconds < 0) {
    throw new Error("TOTP timestamp is invalid.");
  }
  const counter = Math.floor(timestampSeconds * 1000 / periodMillis);
  const counterBytes = new Uint8Array(8);
  new DataView(counterBytes.buffer).setBigUint64(0, BigInt(counter), false);
  const key = await crypto.subtle.importKey(
    "raw",
    bytesToArrayBuffer(hexToBytes(secretHex)),
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, counterBytes),
  );
  const offset = signature[signature.length - 1] & 0x0f;
  const binary = ((signature[offset] & 0x7f) << 24) |
    ((signature[offset + 1] & 0xff) << 16) |
    ((signature[offset + 2] & 0xff) << 8) |
    (signature[offset + 3] & 0xff);
  return (binary % 10 ** digits).toString().padStart(digits, "0");
}

export function parseRotatingBarcode(value: unknown): RotatingBarcode {
  if (typeof value !== "string" || value.length > 180) {
    throw new TicketWalletValidationError(400, "Ticket code is invalid.");
  }
  const match = ROTATING_BARCODE_PATTERN.exec(value.trim());
  if (!match) {
    throw new TicketWalletValidationError(400, "Ticket code is invalid.");
  }
  const timestampSeconds = Number.parseInt(match[3], 10);
  if (!Number.isSafeInteger(timestampSeconds)) {
    throw new TicketWalletValidationError(400, "Ticket code is invalid.");
  }
  return {
    credentialId: match[1].toLowerCase(),
    credentialVersion: Number.parseInt(match[2], 10),
    timestampSeconds,
    totp: match[4],
  };
}

export function constantTimeEqual(left: string, right: string): boolean {
  const maximum = Math.max(left.length, right.length);
  let difference = left.length ^ right.length;
  for (let index = 0; index < maximum; index += 1) {
    difference |= (left.charCodeAt(index) || 0) ^
      (right.charCodeAt(index) || 0);
  }
  return difference === 0;
}

export async function verifyRotatingBarcode(
  value: unknown,
  masterSecret: string,
  now = new Date(),
): Promise<RotatingBarcode> {
  const parsed = parseRotatingBarcode(value);
  const nowSeconds = Math.floor(now.getTime() / 1000);
  const submittedCounter = Math.floor(
    parsed.timestampSeconds * 1000 / WALLET_TOTP_PERIOD_MILLIS,
  );
  const nowCounter = Math.floor(nowSeconds * 1000 / WALLET_TOTP_PERIOD_MILLIS);
  if (Math.abs(submittedCounter - nowCounter) > 1) {
    throw new TicketWalletValidationError(409, "Ticket code has expired.");
  }
  const secretHex = await derivePassTotpSecretHex(
    masterSecret,
    parsed.credentialId,
    parsed.credentialVersion,
  );
  const expected = await generateTotpFromHex(
    secretHex,
    parsed.timestampSeconds,
  );
  if (!constantTimeEqual(expected, parsed.totp)) {
    throw new TicketWalletValidationError(409, "Ticket code is invalid.");
  }
  return parsed;
}

function localized(value: string) {
  return {
    defaultValue: {
      language: "en-US",
      value,
    },
  };
}

export function walletResourceIds(ticket: PreparedWalletTicket) {
  const classId = `${ticket.issuerId}.africlub_event_${
    ticket.ticketEventId.replaceAll("-", "")
  }`;
  const objectId = `${ticket.issuerId}.africlub_ticket_${
    ticket.ticketId.replaceAll("-", "")
  }`;
  if (
    !WALLET_RESOURCE_ID_PATTERN.test(classId) ||
    !WALLET_RESOURCE_ID_PATTERN.test(objectId)
  ) {
    throw new Error("Google Wallet resource identifier is invalid.");
  }
  return { classId, objectId };
}

export function buildEventTicketClass(
  ticket: PreparedWalletTicket,
  classId: string,
): Record<string, unknown> {
  const kickoff = `${ticket.matchDate}T${ticket.kickoffTime}`;
  return {
    id: classId,
    issuerName: ticket.organizationName,
    localizedIssuerName: localized(ticket.organizationName),
    eventName: localized(`${ticket.homeTeam} vs ${ticket.awayTeam}`),
    eventId: ticket.ticketEventId,
    venue: {
      name: localized(ticket.venue),
      address: localized(ticket.venueAddress),
    },
    dateTime: {
      start: kickoff,
      doorsOpen: ticket.entryOpensAt,
      end: ticket.entryClosesAt,
    },
    reviewStatus: "UNDER_REVIEW",
    countryCode: ticket.venueCountryCode,
    multipleDevicesAndHoldersAllowedStatus: "ONE_USER_ALL_DEVICES",
    viewUnlockRequirement: "UNLOCK_REQUIRED_TO_VIEW",
    securityAnimation: { animationType: "FOIL_SHIMMER" },
  };
}

export function buildEventTicketObject(
  ticket: PreparedWalletTicket,
  classId: string,
  objectId: string,
  passSecretHex: string,
): Record<string, unknown> {
  return {
    id: objectId,
    classId,
    state: "ACTIVE",
    ticketNumber: ticket.ticketNumber,
    ticketType: localized(ticket.seatType.toUpperCase()),
    seatInfo: { section: localized(ticket.seatType.toUpperCase()) },
    rotatingBarcode: {
      type: "QR_CODE",
      valuePattern:
        `AFC1.${ticket.credentialId}.${ticket.credentialVersion}.{totp_timestamp_seconds}.{totp_value_0}`,
      alternateText: `Ticket ${ticket.ticketNumber}`,
      totpDetails: {
        algorithm: "TOTP_SHA1",
        periodMillis: `${WALLET_TOTP_PERIOD_MILLIS}`,
        parameters: [{
          key: passSecretHex,
          valueLength: `${WALLET_TOTP_DIGITS}`,
        }],
      },
    },
    passConstraints: { screenshotEligibility: "INELIGIBLE" },
    textModulesData: [
      {
        id: "competition",
        header: "Competition",
        body: ticket.competition,
      },
      {
        id: "entry_window",
        header: "Entry window",
        body: `${ticket.entryOpensAt} – ${ticket.entryClosesAt}`,
      },
    ],
  };
}

type FetchLike = typeof fetch;

type AccessTokenCache = {
  serviceAccountEmail: string;
  token: string;
  expiresAtSeconds: number;
};

let accessTokenCache: AccessTokenCache | null = null;

async function googleAccessToken(
  serviceAccount: GoogleServiceAccount,
  fetcher: FetchLike,
  nowSeconds: number,
): Promise<string> {
  if (
    accessTokenCache?.serviceAccountEmail === serviceAccount.clientEmail &&
    accessTokenCache.expiresAtSeconds - nowSeconds > 60
  ) {
    return accessTokenCache.token;
  }
  const assertion = await signRs256Jwt(serviceAccount, {
    iss: serviceAccount.clientEmail,
    scope: "https://www.googleapis.com/auth/wallet_object.issuer",
    aud: "https://oauth2.googleapis.com/token",
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  });
  const response = await fetcher("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) {
    throw new GoogleWalletApiError("authorization", response.status);
  }
  const payload = await response.json() as Record<string, unknown>;
  const token = requiredString(payload["access_token"], "access_token", 4096);
  const expiresIn = Number.isFinite(payload["expires_in"])
    ? Number(payload["expires_in"])
    : 3600;
  accessTokenCache = {
    serviceAccountEmail: serviceAccount.clientEmail,
    token,
    expiresAtSeconds: nowSeconds + Math.max(60, expiresIn),
  };
  return token;
}

export async function updateGoogleWalletTicketState(options: {
  objectId: string;
  state: "ACTIVE" | "COMPLETED" | "EXPIRED" | "INACTIVE";
  serviceAccount: GoogleServiceAccount;
  fetcher?: FetchLike;
  now?: Date;
}): Promise<void> {
  if (!WALLET_RESOURCE_ID_PATTERN.test(options.objectId)) {
    throw new Error("Google Wallet object identifier is invalid.");
  }
  if (
    options.state !== "ACTIVE" &&
    options.state !== "COMPLETED" &&
    options.state !== "EXPIRED" &&
    options.state !== "INACTIVE"
  ) {
    throw new Error("Google Wallet object state is invalid.");
  }

  const fetcher = options.fetcher ?? fetch;
  const nowSeconds = Math.floor((options.now ?? new Date()).getTime() / 1000);
  const accessToken = await googleAccessToken(
    options.serviceAccount,
    fetcher,
    nowSeconds,
  );
  const response = await walletApiRequest(
    fetcher,
    accessToken,
    `eventTicketObject/${encodeURIComponent(options.objectId)}`,
    {
      method: "PATCH",
      body: JSON.stringify({ state: options.state }),
    },
  );
  if (!response.ok) {
    throw new GoogleWalletApiError("state_update", response.status);
  }
}

async function walletApiRequest(
  fetcher: FetchLike,
  accessToken: string,
  path: string,
  options: RequestInit = {},
): Promise<Response> {
  return await fetcher(
    `https://walletobjects.googleapis.com/walletobjects/v1/${path}`,
    {
      ...options,
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
        ...(options.headers ?? {}),
      },
    },
  );
}

async function ensureWalletResource(
  fetcher: FetchLike,
  accessToken: string,
  resourcePath: string,
  collectionPath: string,
  resourceId: string,
  payload: Record<string, unknown>,
  patchExisting: boolean,
): Promise<void> {
  const current = await walletApiRequest(
    fetcher,
    accessToken,
    `${resourcePath}/${encodeURIComponent(resourceId)}`,
  );
  if (current.ok) {
    if (!patchExisting) return;
    const patch = await walletApiRequest(
      fetcher,
      accessToken,
      `${resourcePath}/${encodeURIComponent(resourceId)}`,
      { method: "PATCH", body: JSON.stringify(payload) },
    );
    if (!patch.ok) {
      throw new Error(`Google Wallet update failed (${patch.status}).`);
    }
    return;
  }
  if (current.status !== 404) {
    throw new Error(`Google Wallet lookup failed (${current.status}).`);
  }
  const insert = await walletApiRequest(fetcher, accessToken, collectionPath, {
    method: "POST",
    body: JSON.stringify(payload),
  });
  if (!insert.ok) {
    throw new Error(`Google Wallet creation failed (${insert.status}).`);
  }
}

export async function provisionGoogleWalletTicket(options: {
  ticket: PreparedWalletTicket;
  serviceAccount: GoogleServiceAccount;
  totpMasterSecret: string;
  fetcher?: FetchLike;
  now?: Date;
}): Promise<
  { classId: string; objectId: string; saveJwt: string; saveUrl: string }
> {
  const fetcher = options.fetcher ?? fetch;
  const nowSeconds = Math.floor((options.now ?? new Date()).getTime() / 1000);
  const { classId, objectId } = walletResourceIds(options.ticket);
  const passSecretHex = await derivePassTotpSecretHex(
    options.totpMasterSecret,
    options.ticket.credentialId,
    options.ticket.credentialVersion,
  );
  const accessToken = await googleAccessToken(
    options.serviceAccount,
    fetcher,
    nowSeconds,
  );

  await ensureWalletResource(
    fetcher,
    accessToken,
    "eventTicketClass",
    "eventTicketClass",
    classId,
    buildEventTicketClass(options.ticket, classId),
    false,
  );
  await ensureWalletResource(
    fetcher,
    accessToken,
    "eventTicketObject",
    "eventTicketObject",
    objectId,
    buildEventTicketObject(
      options.ticket,
      classId,
      objectId,
      passSecretHex,
    ),
    true,
  );

  const saveJwt = await signRs256Jwt(options.serviceAccount, {
    iss: options.serviceAccount.clientEmail,
    aud: "google",
    typ: "savetowallet",
    iat: nowSeconds,
    payload: { eventTicketObjects: [{ id: objectId }] },
  });
  return {
    classId,
    objectId,
    saveJwt,
    saveUrl: `https://pay.google.com/gp/v/save/${saveJwt}`,
  };
}
