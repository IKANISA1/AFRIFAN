"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { resolveVenueAccess } from "@/lib/data/venue-access";

export interface VenueActionState {
  status:
    | "idle"
    | "success"
    | "error"
    | "permission_denied"
    | "conflict"
    | "security_timeout";
  message: string;
}

export const initialVenueActionState: VenueActionState = {
  status: "idle",
  message: "",
};

const orderSchema = z.object({
  orderId: z.uuid(),
  nextStatus: z.enum(["accepted", "preparing", "ready", "served", "cancelled"]),
  reason: z.string().trim().max(240).optional(),
  confirmConsequence: z.literal("confirmed"),
});

const menuSchema = z.object({
  itemId: z.union([z.literal(""), z.uuid()]),
  name: z.string().trim().min(2).max(80),
  description: z.string().trim().max(240),
  priceAmount: z.coerce.number().int().min(0).max(10_000_000),
  currencyCode: z.string().trim().regex(/^[A-Z]{3}$/),
  isAlcohol: z.coerce.boolean(),
  isActive: z.coerce.boolean(),
  sortOrder: z.coerce.number().int().min(0).max(100),
});

const promotionSchema = z.object({
  campaignId: z.uuid(),
  idempotencyKey: z.uuid(),
  confirmConsequence: z.literal("confirmed"),
});

const VENUE_ACTION_TIMEOUT_MS = 12_000;

class VenueActionError extends Error {
  constructor(
    readonly kind:
      | "error"
      | "permission_denied"
      | "conflict"
      | "security_timeout",
    message: string,
  ) {
    super(message);
    this.name = "VenueActionError";
  }
}

function failureCode(error: unknown) {
  if (typeof error !== "object" || error == null) return "";
  const candidate = error as { code?: unknown; status?: unknown };
  return typeof candidate.code === "string"
    ? candidate.code
    : typeof candidate.status === "string"
      ? candidate.status
      : "";
}

function safeActionFailure(
  error: unknown,
  fallback: string,
): VenueActionState {
  if (error instanceof VenueActionError) {
    return { status: error.kind, message: error.message };
  }
  const code = failureCode(error);
  if (["42501", "PGRST301", "permission_denied"].includes(code)) {
    return {
      status: "permission_denied",
      message: "Your venue permission changed. Refresh before continuing.",
    };
  }
  if (["23505", "40001", "STALE_RECORD", "conflict"].includes(code)) {
    return {
      status: "conflict",
      message:
        "This record changed elsewhere. Refresh before attempting another update.",
    };
  }
  if (["57014", "PGRST003", "security_timeout"].includes(code)) {
    return {
      status: "security_timeout",
      message:
        "The result is not confirmed. Refresh before attempting another update.",
    };
  }
  return { status: "error", message: fallback };
}

async function withActionTimeout<T>(operation: PromiseLike<T>) {
  let timeoutId: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      Promise.resolve(operation),
      new Promise<never>((_resolve, reject) => {
        timeoutId = setTimeout(
          () =>
            reject(
              new VenueActionError(
                "security_timeout",
                "The result is not confirmed. Refresh before attempting another update.",
              ),
            ),
          VENUE_ACTION_TIMEOUT_MS,
        );
      }),
    ]);
  } finally {
    if (timeoutId != null) clearTimeout(timeoutId);
  }
}

async function requireVenueAccess() {
  const result = await resolveVenueAccess();
  if (result.status !== "ready") {
    throw new VenueActionError(
      "permission_denied",
      "Venue access is no longer confirmed. Sign in again or ask a club administrator to review the assignment.",
    );
  }
  return result;
}

export async function updateVenueOrderStatus(
  _previous: VenueActionState,
  formData: FormData,
): Promise<VenueActionState> {
  try {
    const scoped = await requireVenueAccess();
    if (!scoped.access.canOperateOrders) {
      throw new VenueActionError(
        "permission_denied",
        "Your venue role is read-only.",
      );
    }
    const parsed = orderSchema.safeParse(Object.fromEntries(formData));
    if (!parsed.success) return { status: "error", message: "Invalid order update." };

    const { data, error } = await withActionTimeout(
      scoped.client.rpc("venue_order_update_status", {
        p_club_id: scoped.access.clubId,
        p_order_id: parsed.data.orderId,
        p_status: parsed.data.nextStatus,
        p_reason: parsed.data.reason || null,
      }),
    );
    if (error) throw error;
    const result = data as { code?: unknown; status?: unknown } | null;
    if (
      result?.code !== "ok" ||
      typeof result.status !== "string" ||
      result.status !== parsed.data.nextStatus
    ) {
      throw new VenueActionError(
        "conflict",
        "The order changed elsewhere. Refresh before attempting another update.",
      );
    }
    revalidatePath("/venue/orders");
    revalidatePath("/venue");
    return { status: "success", message: `Order moved to ${String(result.status)}.` };
  } catch (error) {
    return safeActionFailure(error, "The order could not be updated.");
  }
}

export async function saveVenueMenuItem(
  _previous: VenueActionState,
  formData: FormData,
): Promise<VenueActionState> {
  try {
    const scoped = await requireVenueAccess();
    if (!scoped.access.canManageMenu) {
      throw new VenueActionError(
        "permission_denied",
        "Only venue owners and managers can edit the menu.",
      );
    }
    const parsed = menuSchema.safeParse({
      ...Object.fromEntries(formData),
      isAlcohol: formData.get("isAlcohol") === "on",
      isActive: formData.get("isActive") === "on",
    });
    if (!parsed.success) return { status: "error", message: "Check the menu item fields." };
    const { data, error } = await withActionTimeout(
      scoped.client.rpc("venue_menu_upsert", {
        p_venue_id: scoped.access.venueId,
        p_item_id: parsed.data.itemId || null,
        p_name: parsed.data.name,
        p_description: parsed.data.description,
        p_price_amount: parsed.data.priceAmount,
        p_currency_code: parsed.data.currencyCode,
        p_is_alcohol: parsed.data.isAlcohol,
        p_is_active: parsed.data.isActive,
        p_sort_order: parsed.data.sortOrder,
      }),
    );
    if (error) throw error;
    const result = data as { code?: unknown } | null;
    if (result?.code !== "ok") {
      throw new VenueActionError(
        "conflict",
        "The menu changed elsewhere. Refresh before attempting another update.",
      );
    }
    revalidatePath("/venue/menu");
    return { status: "success", message: "Menu item saved." };
  } catch (error) {
    return safeActionFailure(error, "The menu item could not be saved.");
  }
}

export async function launchVenuePromotion(
  _previous: VenueActionState,
  formData: FormData,
): Promise<VenueActionState> {
  try {
    const scoped = await requireVenueAccess();
    if (!scoped.access.canLaunchPromotions) {
      throw new VenueActionError(
        "permission_denied",
        "Only venue owners and managers can launch promotions.",
      );
    }
    const parsed = promotionSchema.safeParse(Object.fromEntries(formData));
    if (!parsed.success) return { status: "error", message: "Invalid campaign." };
    const { data, error } = await withActionTimeout(
      scoped.client.rpc("venue_promotion_launch", {
        p_venue_id: scoped.access.venueId,
        p_campaign_id: parsed.data.campaignId,
        p_idempotency_key: parsed.data.idempotencyKey,
      }),
    );
    if (error) throw error;
    const result = data as { code?: unknown } | null;
    if (result?.code !== "ok" && result?.code !== "idempotent_replay") {
      throw new VenueActionError(
        "conflict",
        "Promotion state changed elsewhere. Refresh before attempting another launch.",
      );
    }
    revalidatePath("/venue/promotions");
    return { status: "success", message: "Promotion launch recorded." };
  } catch (error) {
    return safeActionFailure(error, "The promotion could not be launched.");
  }
}
