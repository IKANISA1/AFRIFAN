import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { serverSupabaseConfig } from "@/lib/config";
import { acknowledgeStaffCommand, readPendingStaffCommand, retainStaffCommand, staffCommandSha256,
  withStaffCommandJournal, type StaffCommandReference } from "./staff-command-journal";

export interface AdminNotificationPayload {
  title: string; body: string; audience: "all_fans" | "by_tier" | "by_group";
  tier?: string | null; groupId?: string | null; groupName?: string | null;
  deliveryMode: "send_now" | "schedule"; scheduledAt?: string | null; imageUrl?: string | null;
}
type NotificationArguments = { title: string; body: string; audience: string; tier: string | null;
  group_id: string | null; group_name: string | null; delivery_mode: string;
  scheduled_at: string | null; image_url: string | null };
export interface AdminNotificationReceipt {
  command: { version: 1; operation_id: string; actor_id: string | null; club_id: number;
    arguments_sha256: string | null; notification_id: string | null; delivery_mode: "send_now" | "schedule" | null;
    state: "not_admitted" | "admitted" | "scheduled" | "processing" | "completed" | "unknown" | "blocked" };
  delivery: { status: "scheduled" | "processing" | "sent" | "partial" | "failed" | "unknown";
    requested_recipient_count: number; successful_user_count: number; failed_user_count: number;
    sent_count: number; failed_count: number; cleaned_tokens: number; unknown_count: number;
    pending_count: number; scheduled_at: string | null } | null;
  notification: Record<string, unknown> | null;
}
export class AdminNotificationPendingError extends Error {
  constructor(readonly operationId: string, message = "The original notification is unconfirmed. Keep its reference and check status before sending another notification.") {
    super(message); this.name = "AdminNotificationPendingError";
  }
}
const operationPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const resourcePattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const argumentKeys = ["title", "body", "audience", "tier", "group_id", "group_name", "delivery_mode", "scheduled_at", "image_url"];
export function normalizeAdminNotificationArguments(payload: AdminNotificationPayload): NotificationArguments {
  const title = payload.title?.trim(), body = payload.body?.trim();
  if (!title || !body || title.length > 120 || body.length > 500
    || !["all_fans", "by_tier", "by_group"].includes(payload.audience)
    || !["send_now", "schedule"].includes(payload.deliveryMode)) throw new Error("Add a valid notification title, body, audience and delivery mode.");
  let tier = payload.audience === "by_tier" ? payload.tier?.trim().toLowerCase().replaceAll(" ", "_") ?? null : null;
  if (tier === "silver") tier = "bronze";
  if (tier === "legend") tier = "platinum";
  if (payload.audience === "by_tier" && !["fan", "bronze", "gold", "platinum"].includes(tier ?? "")) throw new Error("Choose a supported membership tier.");
  const groupId = payload.audience === "by_group" ? payload.groupId?.trim() ?? null : null;
  const groupName = payload.audience === "by_group" ? payload.groupName?.trim() || null : null;
  if (payload.audience === "by_group" && (!resourcePattern.test(groupId ?? "") || (groupName?.length ?? 0) > 160)) throw new Error("Choose a current contribution group.");
  let scheduledAt: string | null = null;
  if (payload.deliveryMode === "schedule") {
    const date = Date.parse(payload.scheduledAt ?? "");
    if (!Number.isFinite(date)) throw new Error("Choose a valid scheduled time.");
    scheduledAt = new Date(date).toISOString();
  }
  let imageUrl: string | null = null;
  if (payload.imageUrl?.trim()) {
    const url = new URL(payload.imageUrl.trim());
    if (!["http:", "https:"].includes(url.protocol) || url.toString().length > 2048) throw new Error("Choose a valid notification image URL.");
    imageUrl = url.toString();
  }
  const args = { title, body, audience: payload.audience, tier, group_id: groupId, group_name: groupName,
    delivery_mode: payload.deliveryMode, scheduled_at: scheduledAt, image_url: imageUrl };
  if (new TextEncoder().encode(canonicalAdminNotificationArguments(args)).length > 4096) throw new Error("The notification is too large.");
  return args;
}
export function canonicalAdminNotificationArguments(args: NotificationArguments) {
  return JSON.stringify(Object.fromEntries(Object.keys(args).sort().map(key => [key, args[key as keyof NotificationArguments]])));
}
function assertOwner(access: AdminAccess, isCurrent?: () => boolean) {
  if (isCurrent?.() === false || !access.hasAccess || !access.isAuthenticated || !access.isSuperAdmin
    || !access.userId || !/^[1-9][0-9]*$/.test(access.clubId ?? "") || Number(access.clubId) > 2147483647) {
    throw new Error("Current platform staff permission and a selected club are required.");
  }
}
async function verifiedToken(client: SupabaseClient, access: AdminAccess, isCurrent?: () => boolean) {
  assertOwner(access, isCurrent);
  const session = await client.auth.getSession();
  assertOwner(access, isCurrent);
  if (session.error || !session.data.session || session.data.session.user.id !== access.userId) throw new Error("The current account no longer owns this notification.");
  const token = session.data.session.access_token;
  const verified = await client.auth.getUser(token);
  assertOwner(access, isCurrent);
  if (verified.error || verified.data.user?.id !== access.userId) throw new Error("The current account no longer owns this notification.");
  return token;
}
export function parseAdminNotificationReceipt(raw: unknown, entry: StaffCommandReference): AdminNotificationReceipt {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) throw new Error("Notification acknowledgement is invalid.");
  const value = raw as AdminNotificationReceipt;
  const command = value.command;
  if (!command || command.version !== 1 || command.operation_id !== entry.operationId || command.club_id !== Number(entry.clubId)
    || !["not_admitted", "admitted", "scheduled", "processing", "completed", "unknown", "blocked"].includes(command.state)) throw new Error("Notification acknowledgement does not match the original command.");
  if (command.state === "not_admitted") {
    if (command.actor_id !== null || command.arguments_sha256 !== null || command.notification_id !== null
      || command.delivery_mode !== null || value.notification !== null || value.delivery !== null) throw new Error("Unadmitted notification acknowledgement is invalid.");
    return { command, notification: null, delivery: null };
  }
  if (command.actor_id !== entry.userId || command.arguments_sha256 !== entry.argumentsSha256
    || !resourcePattern.test(command.notification_id ?? "") || !["send_now", "schedule"].includes(command.delivery_mode ?? "")
    || !value.notification || Array.isArray(value.notification) || value.notification.id !== command.notification_id) {
    throw new Error("Notification acknowledgement does not match the original account, club and contents.");
  }
  const delivery = value.delivery;
  const counters = ["requested_recipient_count", "successful_user_count", "failed_user_count", "sent_count", "failed_count", "cleaned_tokens", "unknown_count", "pending_count"] as const;
  if (!delivery || !["scheduled", "processing", "sent", "partial", "failed", "unknown"].includes(delivery.status)
    || counters.some(key => !Number.isSafeInteger(delivery[key]) || delivery[key] < 0 || delivery[key] > 500)
    || (delivery.scheduled_at !== null && (typeof delivery.scheduled_at !== "string" || !Number.isFinite(Date.parse(delivery.scheduled_at))))
    || (command.state === "completed" && (delivery.pending_count !== 0 || delivery.unknown_count !== 0 || !["sent", "partial", "failed"].includes(delivery.status)))
    || (command.state === "scheduled" && (command.delivery_mode !== "schedule" || delivery.status !== "scheduled"))) throw new Error("Notification delivery acknowledgement is invalid.");
  // Only declared public fields leave this parser; opaque dispatch proofs never enter the journal.
  return { command, notification: value.notification, delivery };
}
function acknowledgeIfFinal(entry: StaffCommandReference, receipt: AdminNotificationReceipt) {
  if (["completed", "scheduled"].includes(receipt.command.state)) acknowledgeStaffCommand(entry,
    { state: receipt.command.state, resourceId: receipt.command.notification_id });
}
async function invokeCommand(client: SupabaseClient, access: AdminAccess, entry: StaffCommandReference,
  body: Record<string, unknown>, isCurrent?: () => boolean) {
  const token = await verifiedToken(client, access, isCurrent);
  const result = await client.functions.invoke<unknown>("admin-send-notification", {
    headers: { Authorization: `Bearer ${token}` }, body });
  await verifiedToken(client, access, isCurrent);
  if (result.error || !result.data || typeof result.data !== "object" || (result.data as { success?: boolean }).success !== true) {
    throw new AdminNotificationPendingError(entry.operationId);
  }
  return parseAdminNotificationReceipt((result.data as { data?: unknown }).data, entry);
}
export function readPendingAdminNotification(access: Pick<AdminAccess, "userId" | "clubId">) {
  return readPendingStaffCommand(access, "notification");
}
export async function checkAdminNotificationStatus(client: SupabaseClient, access: AdminAccess,
  options: { isCurrent?: () => boolean } = {}): Promise<AdminNotificationReceipt | null> {
  assertOwner(access, options.isCurrent);
  return withStaffCommandJournal(access, "notification", async entry => {
    if (!entry) return null;
    const receipt = await invokeCommand(client, access, entry,
      { action: "status", operation_id: entry.operationId, club_id: Number(entry.clubId) }, options.isCurrent);
    assertOwner(access, options.isCurrent); acknowledgeIfFinal(entry, receipt); return receipt;
  });
}
async function submitOriginalAdminNotification(client: SupabaseClient, payload: AdminNotificationPayload, access: AdminAccess,
  options: { isCurrent?: () => boolean } = {}): Promise<AdminNotificationReceipt> {
  assertOwner(access, options.isCurrent);
  const args = normalizeAdminNotificationArguments(payload);
  const argumentsSha256 = await staffCommandSha256(canonicalAdminNotificationArguments(args));
  assertOwner(access, options.isCurrent);
  return withStaffCommandJournal(access, "notification", async prior => {
    await verifiedToken(client, access, options.isCurrent);
    const entry = retainStaffCommand(access, "notification", argumentsSha256);
    try {
      if (prior) {
        const recovered = await invokeCommand(client, access, entry,
          { action: "status", operation_id: entry.operationId, club_id: Number(entry.clubId) }, options.isCurrent);
        if (recovered.command.state !== "not_admitted") {
          assertOwner(access, options.isCurrent); acknowledgeIfFinal(entry, recovered); return recovered;
        }
      }
      const receipt = await invokeCommand(client, access, entry,
        { action: "submit", operation_id: entry.operationId, club_id: Number(entry.clubId), ...args }, options.isCurrent);
      assertOwner(access, options.isCurrent); acknowledgeIfFinal(entry, receipt); return receipt;
    } catch (caught) {
      if (caught instanceof AdminNotificationPendingError) throw caught;
      throw new AdminNotificationPendingError(entry.operationId, caught instanceof Error ? caught.message : undefined);
    }
  });
}
const inFlight = new Map<string, { canonical: string; promise: Promise<AdminNotificationReceipt> }>();
export async function sendAdminNotification(client: SupabaseClient, payload: AdminNotificationPayload, access: AdminAccess,
  options: { isCurrent?: () => boolean } = {}): Promise<AdminNotificationReceipt> {
  assertOwner(access, options.isCurrent);
  const canonical = canonicalAdminNotificationArguments(normalizeAdminNotificationArguments(payload));
  const key = `${access.userId}:${access.clubId}`;
  const existing = inFlight.get(key);
  if (existing) {
    if (existing.canonical !== canonical) throw new Error("The original notification is still being checked. Keep its contents and reference.");
    const receipt = await existing.promise;
    await verifiedToken(client, access, options.isCurrent);
    return receipt;
  }
  const promise = submitOriginalAdminNotification(client, payload, access, options);
  inFlight.set(key, { canonical, promise });
  try { return await promise; }
  finally { if (inFlight.get(key)?.promise === promise) inFlight.delete(key); }
}
/** Actual server route forwards the current verified staff token and exact original command. */
export async function forwardAdminNotificationCommand(client: SupabaseClient, raw: Record<string, unknown>, access: AdminAccess) {
  assertOwner(access);
  const allowed = raw.action === "status" ? ["action", "operation_id", "club_id"] : ["action", "operation_id", "club_id", ...argumentKeys];
  if (!["submit", "status"].includes(String(raw.action)) || !operationPattern.test(String(raw.operation_id))
    || raw.club_id !== Number(access.clubId) || Object.keys(raw).some(key => !allowed.includes(key))) throw new Error("A bound original notification command is required.");
  const token = await verifiedToken(client, access);
  const { url, anonKey } = serverSupabaseConfig;
  if (!url || !anonKey) throw new Error("Supabase server configuration is not available.");
  const response = await fetch(`${url}/functions/v1/admin-send-notification`, { method: "POST",
    headers: { Authorization: `Bearer ${token}`, apikey: anonKey, "Content-Type": "application/json" }, body: JSON.stringify(raw), cache: "no-store" });
  await verifiedToken(client, access);
  const result = await response.json().catch(() => null) as { success?: boolean; data?: Record<string, unknown> } | null;
  if (!response.ok || result?.success !== true || !result.data) throw new Error("Could not confirm the original notification command.");
  const { command, notification, delivery } = result.data;
  return { command, notification, delivery };
}
