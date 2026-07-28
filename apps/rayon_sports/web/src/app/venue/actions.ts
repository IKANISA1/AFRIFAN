"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { resolveVenueAccess } from "@/lib/data/venue-access";

export interface VenueActionState {
  status: "idle" | "success" | "error";
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

const promotionSchema = z.object({ campaignId: z.uuid() });

async function requireVenueAccess() {
  const result = await resolveVenueAccess();
  if (result.status !== "ready") throw new Error("Venue access denied");
  return result;
}

export async function updateVenueOrderStatus(
  _previous: VenueActionState,
  formData: FormData,
): Promise<VenueActionState> {
  try {
    const scoped = await requireVenueAccess();
    if (!scoped.access.canOperateOrders) throw new Error("Your role is read-only");
    const parsed = orderSchema.safeParse(Object.fromEntries(formData));
    if (!parsed.success) return { status: "error", message: "Invalid order update." };

    const { data, error } = await scoped.client.rpc("venue_order_update_status", {
      p_club_id: scoped.access.clubId,
      p_order_id: parsed.data.orderId,
      p_status: parsed.data.nextStatus,
      p_reason: parsed.data.reason || null,
    });
    if (error) throw error;
    const result = data as { code?: unknown; status?: unknown } | null;
    if (result?.code !== "ok") throw new Error(String(result?.code || "Update rejected"));
    revalidatePath("/venue/orders");
    revalidatePath("/venue");
    return { status: "success", message: `Order moved to ${String(result.status)}.` };
  } catch (error) {
    return { status: "error", message: error instanceof Error ? error.message : "Order update failed." };
  }
}

export async function saveVenueMenuItem(
  _previous: VenueActionState,
  formData: FormData,
): Promise<VenueActionState> {
  try {
    const scoped = await requireVenueAccess();
    if (!scoped.access.canManageMenu) throw new Error("Only owners and managers can edit the menu");
    const parsed = menuSchema.safeParse({
      ...Object.fromEntries(formData),
      isAlcohol: formData.get("isAlcohol") === "on",
      isActive: formData.get("isActive") === "on",
    });
    if (!parsed.success) return { status: "error", message: "Check the menu item fields." };
    const { data, error } = await scoped.client.rpc("venue_menu_upsert", {
      p_venue_id: scoped.access.venueId,
      p_item_id: parsed.data.itemId || null,
      p_name: parsed.data.name,
      p_description: parsed.data.description,
      p_price_amount: parsed.data.priceAmount,
      p_currency_code: parsed.data.currencyCode,
      p_is_alcohol: parsed.data.isAlcohol,
      p_is_active: parsed.data.isActive,
      p_sort_order: parsed.data.sortOrder,
    });
    if (error) throw error;
    const result = data as { code?: unknown } | null;
    if (result?.code !== "ok") throw new Error(String(result?.code || "Menu update rejected"));
    revalidatePath("/venue/menu");
    return { status: "success", message: "Menu item saved." };
  } catch (error) {
    return { status: "error", message: error instanceof Error ? error.message : "Menu update failed." };
  }
}

export async function launchVenuePromotion(
  _previous: VenueActionState,
  formData: FormData,
): Promise<VenueActionState> {
  try {
    const scoped = await requireVenueAccess();
    if (!scoped.access.canLaunchPromotions) throw new Error("Only owners and managers can launch promotions");
    const parsed = promotionSchema.safeParse(Object.fromEntries(formData));
    if (!parsed.success) return { status: "error", message: "Invalid campaign." };
    const { data, error } = await scoped.client.rpc("venue_promotion_launch", {
      p_venue_id: scoped.access.venueId,
      p_campaign_id: parsed.data.campaignId,
      p_idempotency_key: crypto.randomUUID(),
    });
    if (error) throw error;
    const result = data as { code?: unknown } | null;
    if (result?.code !== "ok" && result?.code !== "idempotent_replay") {
      throw new Error(String(result?.code || "Promotion launch rejected"));
    }
    revalidatePath("/venue/promotions");
    return { status: "success", message: "Promotion launch recorded." };
  } catch (error) {
    return { status: "error", message: error instanceof Error ? error.message : "Promotion launch failed." };
  }
}
