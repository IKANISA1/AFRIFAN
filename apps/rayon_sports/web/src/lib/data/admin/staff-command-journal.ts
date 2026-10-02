import type { AdminAccess } from "@/lib/types";

export type StaffCommandOwner = Pick<AdminAccess, "userId" | "clubId">;
export interface StaffCommandReference {
  version: 1;
  operationId: string;
  userId: string;
  clubId: string;
  domain: string;
  argumentsSha256: string;
}
const prefix = "africlub.staff-command.v1";
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const unavailable = "The original command could not be retained. Check browser storage before sending.";
function storage() {
  try { if (typeof localStorage !== "undefined") return localStorage; } catch { /* Fail closed. */ }
  throw new Error(unavailable);
}
function key(owner: StaffCommandOwner, domain: string) {
  if (!owner.userId || !owner.clubId || !/^[1-9][0-9]*$/.test(owner.clubId)
    || !/^(notification|image-generation:[a-z_]+:[0-9a-f]{64})$/.test(domain)) {
    throw new Error("A verified account, club and command scope are required.");
  }
  return `${prefix}:${owner.userId}:${owner.clubId}:${domain}`;
}
function get(at: string) {
  try { return storage().getItem(at); } catch { throw new Error(unavailable); }
}
function persist(at: string, raw: string) {
  try { storage().setItem(at, raw); if (storage().getItem(at) === raw) return; } catch { /* Preserve all original records. */ }
  throw new Error(unavailable);
}
function parse(raw: string, owner: StaffCommandOwner, domain: string): StaffCommandReference {
  try {
    const entry = JSON.parse(raw) as StaffCommandReference;
    if (Object.keys(entry).sort().join(",") !== "argumentsSha256,clubId,domain,operationId,userId,version"
      || entry.version !== 1 || entry.userId !== owner.userId || entry.clubId !== owner.clubId
      || entry.domain !== domain || !uuid.test(entry.operationId) || !/^[0-9a-f]{64}$/.test(entry.argumentsSha256)) throw new Error();
    return entry;
  } catch { throw new Error("The saved command reference needs recovery. No replacement command was sent."); }
}
export function readPendingStaffCommand(owner: StaffCommandOwner, domain: string): StaffCommandReference | null {
  const at = key(owner, domain);
  const raw = get(`${at}:pending`);
  if (raw === null) return null;
  const entry = parse(raw, owner, domain);
  if (get(`${at}:${entry.operationId}`) !== raw) throw new Error("The saved command reference needs recovery. No replacement command was sent.");
  return entry;
}
export async function withStaffCommandJournal<T>(owner: StaffCommandOwner, domain: string,
  action: (entry: StaffCommandReference | null) => Promise<T>): Promise<T> {
  const at = key(owner, domain);
  if (typeof navigator === "undefined" || !navigator.locks?.request) {
    throw new Error("This browser cannot safely retain commands. Use a browser with secure operation locking.");
  }
  return navigator.locks.request(at, () => action(readPendingStaffCommand(owner, domain)));
}
// Only called while holding the journal lock, after current owner verification.
export function retainStaffCommand(owner: StaffCommandOwner, domain: string, argumentsSha256: string): StaffCommandReference {
  const at = key(owner, domain);
  const prior = readPendingStaffCommand(owner, domain);
  if (prior) {
    if (prior.argumentsSha256 !== argumentsSha256) throw new Error("Check the original command before changing its contents or sending another command.");
    return prior;
  }
  const entry = parse(JSON.stringify({ version: 1, operationId: crypto.randomUUID(), userId: owner.userId,
    clubId: owner.clubId, domain, argumentsSha256 }), owner, domain);
  const raw = JSON.stringify(entry);
  persist(`${at}:${entry.operationId}`, raw);
  persist(`${at}:pending`, raw);
  return entry;
}
export function acknowledgeStaffCommand(entry: StaffCommandReference, receipt: { state: string; resourceId?: string | null }) {
  const at = key(entry, entry.domain);
  if (readPendingStaffCommand(entry, entry.domain)?.operationId !== entry.operationId) throw new Error("The original command reference changed. Check its status.");
  // Persist metadata only: no message, prompt, bearer, provider proof or lease.
  persist(`${at}:${entry.operationId}:acknowledged`, JSON.stringify({ ...entry, state: receipt.state, resourceId: receipt.resourceId ?? null }));
  try { storage().removeItem(`${at}:pending`); if (storage().getItem(`${at}:pending`) === null) return; } catch { /* Retain the original reference. */ }
  throw new Error("The command was confirmed. Recover its original acknowledgement before continuing.");
}
export async function staffCommandSha256(value: string) {
  return [...new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)))].map(b => b.toString(16).padStart(2, "0")).join("");
}
