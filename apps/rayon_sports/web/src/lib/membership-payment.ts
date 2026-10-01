import type { SupabaseClient } from "@supabase/supabase-js";
import { boundedMemberRequest, isMemberSignOutPending } from "./member-session";

export type MembershipPaymentReview = {
  id: string;
  clubId: number;
  tier: string;
  amount: number;
  currency: string;
  recipientCode: string;
  country: string;
  ussdCode: string;
  userId: string;
};

export class MembershipPaymentChangedError extends Error {
  constructor(public readonly review: MembershipPaymentReview) {
    super("MEMBERSHIP_PAYMENT_CHANGED");
  }
}

async function verifiedUser(client: SupabaseClient) {
  if (isMemberSignOutPending()) throw new Error("MEMBER_AUTH_REQUIRED");
  const result = await boundedMemberRequest(client.auth.getUser());
  if (result.error || !result.data.user || isMemberSignOutPending()) throw new Error("MEMBER_AUTH_REQUIRED");
  return result.data.user.id;
}

/** Only the server can supply the amount, denomination and receiving account. */
export async function preparePaidMembership(
  client: SupabaseClient,
  tier: string,
  clubId: number,
  expectedCurrency: string,
  isCurrent: () => boolean = () => true,
): Promise<MembershipPaymentReview | null> {
  const userId = await verifiedUser(client);
  if (!isCurrent()) return null;
  const prepared = await boundedMemberRequest(client.rpc("prepare_membership_payment_for_club", {
    p_tier: tier, p_expected_club_id: clubId,
  }));
  if (prepared.error) throw prepared.error;
  const payment = prepared.data as Record<string, unknown> | null;
  if (!payment || payment.club_id !== clubId || payment.tier !== tier ||
      typeof payment.id !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(payment.id) ||
      !Number.isSafeInteger(payment.amount) || Number(payment.amount) <= 0 ||
      typeof payment.currency !== "string" || !/^[A-Z]{3}$/.test(payment.currency) || payment.currency !== expectedCurrency ||
      typeof payment.recipient_code !== "string" || !/^[0-9]{1,40}$/.test(payment.recipient_code) ||
      typeof payment.country !== "string" || !/^[A-Z]{2}$/.test(payment.country) ||
      typeof payment.ussd_code !== "string" || !/^\*[0-9*]+#$/.test(payment.ussd_code)) {
    throw new Error("MEMBERSHIP_PAYMENT_INVALID");
  }
  if (await verifiedUser(client) !== userId) throw new Error("MEMBER_AUTH_REQUIRED");
  if (!isCurrent()) return null;
  return { id: payment.id, clubId, tier, amount: Number(payment.amount), currency: payment.currency,
    recipientCode: payment.recipient_code, country: payment.country, ussdCode: payment.ussd_code, userId };
}

/** Explicit confirmation renews the server facts and the current account binding. */
export async function confirmPaidMembership(
  client: SupabaseClient,
  review: MembershipPaymentReview,
  launch: (href: string) => void,
  isCurrent: () => boolean = () => true,
) {
  if (await verifiedUser(client) !== review.userId) throw new Error("MEMBER_AUTH_REQUIRED");
  if (!isCurrent()) return false;
  const current = await preparePaidMembership(client, review.tier, review.clubId, review.currency, isCurrent);
  if (!current) return false;
  if (current.userId !== review.userId) throw new Error("MEMBER_AUTH_REQUIRED");
  if (current.id !== review.id || current.amount !== review.amount || current.currency !== review.currency ||
      current.recipientCode !== review.recipientCode || current.country !== review.country || current.ussdCode !== review.ussdCode) {
    throw new MembershipPaymentChangedError(current);
  }
  if (!isCurrent() || isMemberSignOutPending()) return false;
  launch(`tel:${current.ussdCode.replace(/#/g, "%23")}`);
  return true;
}
