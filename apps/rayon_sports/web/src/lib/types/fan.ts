/**
 * Fan-facing authenticated types.
 */
import type { MembershipTierSlug } from "./site";

export interface FanProfile {
  id: string;
  clubId: string;
  publicUserId?: string | null;
  displayName?: string | null;
  countryCode?: string | null;
  languageCode?: string | null;
  isActive?: boolean;
  momoNumber?: string | null;
  whatsappNumber?: string | null;
}

export interface FanMembership {
  id: string;
  clubId: number | null;
  partnerId?: string | null;
  tier: MembershipTierSlug;
  points: number;
  chapter: string;
  membershipNumber?: string | null;
}

export interface TicketOrder {
  id: string;
  matchId: string;
  userId: string;
  seatType: string;
  amountPaid: number;
  status: string;
  qrCode?: string | null;
  purchasedAt: string;
}

export interface ShopOrder {
  id: string;
  userId: string;
  total: number;
  status: string;
  deliveryAddress?: string | null;
  momoReference?: string | null;
  createdAt: string;
}
