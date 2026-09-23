import type { SupabaseClient } from "@supabase/supabase-js";
import { boundedMemberRequest, isMemberSignOutPending } from "./member-session";

/** No client price, recipient, eligibility or approval can authorize a tier. */
export async function launchPaidMembership(
  client: SupabaseClient,
  tier: string,
  clubId: number,
  launch: (href: string) => void,
  isCurrent: () => boolean = () => true,
) {
  if (isMemberSignOutPending()) throw new Error("MEMBER_AUTH_REQUIRED");
  const first = await boundedMemberRequest(client.auth.getUser());
  if (first.error || !first.data.user) throw new Error("MEMBER_AUTH_REQUIRED");
  if (!isCurrent()) return false;
  const prepared = await boundedMemberRequest(client.rpc("prepare_membership_payment_for_club", {
    p_tier: tier,
    p_expected_club_id: clubId,
  }));
  if (prepared.error) throw prepared.error;
  const payment = prepared.data as Record<string, unknown> | null;
  if (!payment || payment.club_id !== clubId || payment.tier !== tier ||
      !Number.isSafeInteger(payment.amount) || Number(payment.amount) <= 0 ||
      typeof payment.ussd_code !== "string" || !/^\*[0-9*]+#$/.test(payment.ussd_code)) {
    throw new Error("MEMBERSHIP_PAYMENT_INVALID");
  }
  const current = await boundedMemberRequest(client.auth.getUser());
  if (current.error || current.data.user?.id !== first.data.user.id ||
      isMemberSignOutPending()) throw new Error("MEMBER_AUTH_REQUIRED");
  if (!isCurrent()) return false;
  launch(`tel:${payment.ussd_code.replace(/#/g, "%23")}`);
  return true;
}
