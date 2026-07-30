import type { SupabaseClient } from "@supabase/supabase-js";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { revalidatePath } from "next/cache";
import { resolveVenueAccess } from "@/lib/data/venue-access";
import {
  initialVenueActionState,
  launchVenuePromotion,
  saveVenueMenuItem,
  updateVenueOrderStatus,
} from "./actions";

vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));
vi.mock("@/lib/data/venue-access", () => ({ resolveVenueAccess: vi.fn() }));

const orderId = "33333333-3333-4333-8333-333333333333";
const campaignId = "44444444-4444-4444-8444-444444444444";
const idempotencyKey = "55555555-5555-4555-8555-555555555555";

function form(entries: Record<string, string>) {
  const value = new FormData();
  for (const [key, item] of Object.entries(entries)) value.set(key, item);
  return value;
}

function ready(
  rpc: ReturnType<typeof vi.fn>,
  overrides: Partial<{
    canOperateOrders: boolean;
    canManageMenu: boolean;
    canLaunchPromotions: boolean;
  }> = {},
) {
  vi.mocked(resolveVenueAccess).mockResolvedValue({
    status: "ready",
    client: { rpc } as unknown as SupabaseClient,
    user: { id: "11111111-1111-4111-8111-111111111111" },
    access: {
      userId: "11111111-1111-4111-8111-111111111111",
      clubId: 24,
      venueId: "22222222-2222-4222-8222-222222222222",
      venueName: "Amahoro Hospitality",
      venueCity: "Kigali",
      role: "manager",
      canOperateOrders: true,
      canManageMenu: true,
      canLaunchPromotions: true,
      ...overrides,
    },
  } as Awaited<ReturnType<typeof resolveVenueAccess>>);
}

beforeEach(() => {
  vi.clearAllMocks();
});

describe("venue actions", () => {
  it("updates a confirmed order through the scoped RPC", async () => {
    const rpc = vi.fn().mockResolvedValue({
      data: { code: "ok", status: "accepted" },
      error: null,
    });
    ready(rpc);

    await expect(
      updateVenueOrderStatus(
        initialVenueActionState,
        form({
          orderId,
          nextStatus: "accepted",
          reason: "Kitchen accepted",
          confirmConsequence: "confirmed",
        }),
      ),
    ).resolves.toEqual({
      status: "success",
      message: "Order moved to accepted.",
    });
    expect(rpc).toHaveBeenCalledWith("venue_order_update_status", {
      p_club_id: 24,
      p_order_id: orderId,
      p_status: "accepted",
      p_reason: "Kitchen accepted",
    });
    expect(revalidatePath).toHaveBeenCalledWith("/venue/orders");
  });

  it("rejects an unconfirmed order change before mutation", async () => {
    const rpc = vi.fn();
    ready(rpc);
    await expect(
      updateVenueOrderStatus(
        initialVenueActionState,
        form({ orderId, nextStatus: "cancelled", reason: "" }),
      ),
    ).resolves.toEqual({
      status: "error",
      message: "Invalid order update.",
    });
    expect(rpc).not.toHaveBeenCalled();
  });

  it("does not expose provider details when a menu save fails", async () => {
    const rpc = vi.fn().mockResolvedValue({
      data: null,
      error: { code: "XX000", message: "private provider stack" },
    });
    ready(rpc);
    await expect(
      saveVenueMenuItem(
        initialVenueActionState,
        form({
          itemId: "",
          name: "Water",
          description: "",
          priceAmount: "1000",
          currencyCode: "RWF",
          sortOrder: "0",
          isActive: "on",
        }),
      ),
    ).resolves.toEqual({
      status: "error",
      message: "The menu item could not be saved.",
    });
  });

  it("reuses the supplied promotion idempotency key", async () => {
    const rpc = vi.fn().mockResolvedValue({
      data: { code: "idempotent_replay" },
      error: null,
    });
    ready(rpc);
    await expect(
      launchVenuePromotion(
        initialVenueActionState,
        form({
          campaignId,
          idempotencyKey,
          confirmConsequence: "confirmed",
        }),
      ),
    ).resolves.toEqual({
      status: "success",
      message: "Promotion launch recorded.",
    });
    expect(rpc).toHaveBeenCalledWith("venue_promotion_launch", {
      p_venue_id: "22222222-2222-4222-8222-222222222222",
      p_campaign_id: campaignId,
      p_idempotency_key: idempotencyKey,
    });
  });

  it("fails closed when the current venue role is read-only", async () => {
    const rpc = vi.fn();
    ready(rpc, { canLaunchPromotions: false });
    await expect(
      launchVenuePromotion(
        initialVenueActionState,
        form({
          campaignId,
          idempotencyKey,
          confirmConsequence: "confirmed",
        }),
      ),
    ).resolves.toEqual({
      status: "permission_denied",
      message: "Only venue owners and managers can launch promotions.",
    });
    expect(rpc).not.toHaveBeenCalled();
  });

  it("locks uncertain mutations behind an authoritative refresh", async () => {
    const rpc = vi.fn().mockResolvedValue({
      data: null,
      error: { code: "57014", message: "statement cancelled" },
    });
    ready(rpc);
    await expect(
      updateVenueOrderStatus(
        initialVenueActionState,
        form({
          orderId,
          nextStatus: "accepted",
          reason: "",
          confirmConsequence: "confirmed",
        }),
      ),
    ).resolves.toEqual({
      status: "security_timeout",
      message:
        "The result is not confirmed. Refresh before attempting another update.",
    });
  });
});
