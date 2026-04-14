import { createAdminClient } from "./supabase.ts";
import { sendTextMessage } from "./whatsapp.ts";
import {
  planRayonInitiativeConfirmation,
  planRayonShopOrderConfirmation,
  planRayonTicketConfirmation,
} from "../parse-momo-sms/rayon_confirmation.ts";

type AdminClient = ReturnType<typeof createAdminClient>;

export type RayonReferenceMatch = {
  reference: string;
  user_id: string | null;
};

type UserContactRecord = {
  phone: string | null;
  whatsapp_number: string | null;
};

type RsTicketRecord = {
  id: string;
  user_id: string;
  club_id: number | null;
  referral_invite_id: string | null;
  seat_type: string | null;
  amount_paid: number;
  momo_reference: string | null;
  status: string | null;
  match_title: string;
  venue: string | null;
  match_date: string | null;
  kickoff_time: string | null;
  partner_id: string | null;
};

type RsShopOrderRecord = {
  id: string;
  user_id: string;
  club_id: number | null;
  partner_id: string | null;
  referral_invite_id: string | null;
  total: number;
  delivery_address: string | null;
  momo_reference: string | null;
  status: string | null;
};

type RsInitiativeContributionRecord = {
  id: string;
  user_id: string;
  club_id: number | null;
  referral_invite_id: string | null;
  initiative_id: string | null;
  amount: number;
  momo_reference: string | null;
  status: string | null;
  initiative_title: string;
  partner_id: string | null;
};

export type RayonPaymentConfirmationResult = {
  matchType: string;
  matchStatus: "matched" | "pending_review" | "manual_review";
  ledgerStatus: "draft" | "posted";
  targetTable: string | null;
  targetRecordId: string | null;
  matchedReference: string | null;
  notes: string | null;
  metadata: Record<string, unknown>;
};

export type RayonPaymentConfirmationContext = {
  source: "parse-momo-sms";
  timestamp: string;
  provider: string | null;
  amount: number | null;
  transactionId?: string | null;
  payeeNumberOrCode?: string | null;
  merchantCode?: string | null;
  candidateScore?: number | null;
  confidence?: number | null;
  rawSmsId?: string | null;
  parsedSmsId?: string | null;
  sender?: string | null;
  country?: string | null;
  extraPayload?: Record<string, unknown>;
};

type PaymentBranding = {
  clubLabel: string;
  currencyCode: string;
  fallbackPartnerNames: string[];
  resolvedClubId: number | null;
  resolvedPartnerId: string | null;
  routeCountry: string | null;
};

function asString(value: unknown): string | null {
  if (typeof value === "string") {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : null;
  }
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  return null;
}

function asNullableInt(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.round(value);
  }
  if (typeof value === "string") {
    const cleaned = value.replaceAll(/[^\d.-]/g, "");
    if (!cleaned) return null;
    const parsed = Number.parseFloat(cleaned);
    return Number.isFinite(parsed) ? Math.round(parsed) : null;
  }
  return null;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return null;
}

function shortTime(value: string | null): string | null {
  if (!value) {
    return null;
  }
  return value.length > 5 ? value.slice(0, 5) : value;
}

function normalizeProviderId(value: string | null | undefined): string | null {
  const normalized = value?.trim().toLowerCase();
  switch (normalized) {
    case "mtn":
    case "mtn rwanda":
    case "mtn_rwanda":
      return "mtn_rwanda";
    case "airtel":
      return "airtel";
    case "orange":
      return "orange";
    default:
      return normalized?.length ? normalized : null;
  }
}

export function looksLikeRayonTicketReference(reference: string): boolean {
  return reference.trim().toUpperCase().startsWith("RS-TICKET-");
}

export function looksLikeRayonShopReference(reference: string): boolean {
  return reference.trim().toUpperCase().startsWith("RS-SHOP-");
}

export function looksLikeRayonSupportReference(reference: string): boolean {
  return reference.trim().toUpperCase().startsWith("RS-SUPPORT-");
}

export function looksLikeRayonReference(reference: string): boolean {
  return looksLikeRayonTicketReference(reference) ||
    looksLikeRayonShopReference(reference) ||
    looksLikeRayonSupportReference(reference);
}

export function buildManualReviewResult(
  reason: string,
  metadata: Record<string, unknown> = {},
): RayonPaymentConfirmationResult {
  return {
    matchType: "manual_review",
    matchStatus: "manual_review",
    ledgerStatus: "draft",
    targetTable: null,
    targetRecordId: null,
    matchedReference: null,
    notes: reason,
    metadata: {
      auto_match: false,
      ...metadata,
    },
  };
}

async function resolveUserContact(
  adminClient: AdminClient,
  userId: string,
): Promise<UserContactRecord | null> {
  const result = await adminClient
    .from("user_private_contacts")
    .select("momo_number, whatsapp_number")
    .eq("user_id", userId)
    .maybeSingle();

  if (result.error) {
    throw result.error;
  }

  if (!result.data) {
    return null;
  }

  return {
    phone: asString(result.data.momo_number),
    whatsapp_number: asString(result.data.whatsapp_number),
  };
}

type PartnerPaymentRouteRecord = {
  club_id: number | null;
  partner_id: string | null;
  partner_name: string | null;
  country: string | null;
};

async function resolvePaymentRouteRecord(
  adminClient: AdminClient,
  codeOrNumber: string | null | undefined,
): Promise<PartnerPaymentRouteRecord | null> {
  const routeCode = asString(codeOrNumber);
  if (!routeCode) {
    return null;
  }

  const activeResult = await adminClient
    .from("partner_payment_routes")
    .select("club_id, partner_id, partner_name, country")
    .eq("recipient_code", routeCode)
    .eq("status", "active")
    .maybeSingle();

  if (activeResult.error) {
    throw activeResult.error;
  }

  const activeRow = asRecord(activeResult.data);
  if (activeRow) {
    return {
      club_id: asNullableInt(activeRow.club_id),
      partner_id: asString(activeRow.partner_id),
      partner_name: asString(activeRow.partner_name),
      country: asString(activeRow.country),
    };
  }

  const fallbackResult = await adminClient
    .from("partner_payment_routes")
    .select("club_id, partner_id, partner_name, country")
    .eq("recipient_code", routeCode)
    .maybeSingle();

  if (fallbackResult.error) {
    throw fallbackResult.error;
  }

  const fallbackRow = asRecord(fallbackResult.data);
  if (!fallbackRow) {
    return null;
  }

  return {
    club_id: asNullableInt(fallbackRow.club_id),
    partner_id: asString(fallbackRow.partner_id),
    partner_name: asString(fallbackRow.partner_name),
    country: asString(fallbackRow.country),
  };
}

async function resolvePartnerIdByNames(
  adminClient: AdminClient,
  lookupNames: string[],
): Promise<string | null> {
  if (lookupNames.length === 0) {
    return null;
  }

  const exactResult = await adminClient
    .from("partners")
    .select("id, name")
    .in("name", lookupNames);

  if (exactResult.error) {
    throw exactResult.error;
  }

  const exactRows = Array.isArray(exactResult.data)
    ? exactResult.data as Record<string, unknown>[]
    : [];
  for (const name of lookupNames) {
    for (const row of exactRows) {
      if (asString(row.name) == name) {
        const id = asString(row.id);
        if (id) {
          return id;
        }
      }
    }
  }

  const fallbackResult = await adminClient
    .from("partners")
    .select("id")
    .ilike("name", `${lookupNames[0]?.replaceAll("%", "").trim() ?? ""}%`)
    .maybeSingle();

  if (fallbackResult.error) {
    throw fallbackResult.error;
  }

  return asString(fallbackResult.data?.id);
}

async function resolvePaymentBranding(
  adminClient: AdminClient,
  options: {
    clubId?: number | null;
    partnerId?: string | null;
    routeCodeOrNumber?: string | null;
    fallbackClubName?: string | null;
  },
): Promise<PaymentBranding> {
  const fallbackNames = new Set<string>();
  const fallbackClubName = asString(options.fallbackClubName);
  if (fallbackClubName) {
    fallbackNames.add(fallbackClubName);
  }

  let clubLabel = fallbackClubName ?? "Club";
  let currencyCode = "";
  let resolvedClubId: number | null = null;
  let resolvedPartnerId: string | null = null;
  let routeCountry: string | null = null;

  const routeRecord = await resolvePaymentRouteRecord(
    adminClient,
    options.routeCodeOrNumber,
  );
  if (routeRecord?.partner_name) {
    fallbackNames.add(routeRecord.partner_name);
    if (clubLabel === "Club") {
      clubLabel = routeRecord.partner_name;
    }
  }

  routeCountry = routeRecord?.country ?? null;
  resolvedClubId = routeRecord?.club_id ?? null;
  resolvedPartnerId = routeRecord?.partner_id ?? null;

  const clubId = options.clubId ?? resolvedClubId;
  if (typeof clubId === "number" && Number.isFinite(clubId) && clubId > 0) {
    const clubResult = await adminClient
      .from("african_football_clubs")
      .select("club_name, nickname_brand_identity, currency_code")
      .eq("id", clubId)
      .maybeSingle();

    if (clubResult.error) {
      throw clubResult.error;
    }

    const clubRow = asRecord(clubResult.data);
    const clubName = asString(clubRow?.club_name);
    const nickname = asString(clubRow?.nickname_brand_identity);
    clubLabel = nickname ?? clubName ?? clubLabel;
    currencyCode = asString(clubRow?.currency_code) ?? currencyCode;
    if (clubName) {
      fallbackNames.add(clubName);
    }
    if (nickname) {
      fallbackNames.add(nickname);
    }

    resolvedClubId = clubId;
  }

  const partnerId = asString(options.partnerId) ?? resolvedPartnerId;
  if (partnerId) {
    const partnerResult = await adminClient
      .from("partners")
      .select("name, country")
      .eq("id", partnerId)
      .maybeSingle();

    if (partnerResult.error) {
      throw partnerResult.error;
    }

    const partnerName = asString(partnerResult.data?.name);
    const partnerCountry = asString(partnerResult.data?.country);
    if (partnerName) {
      clubLabel = clubLabel === "Club" ? partnerName : clubLabel;
      fallbackNames.add(partnerName);
    }

    resolvedPartnerId = partnerId;
    routeCountry = routeCountry ?? partnerCountry;

    if (!currencyCode && routeCountry) {
      const countryResult = await adminClient
        .from("countries")
        .select("currency")
        .eq("id", routeCountry)
        .maybeSingle();

      if (countryResult.error) {
        throw countryResult.error;
      }

      currencyCode = asString(countryResult.data?.currency) ?? currencyCode;
    }
  }

  return {
    clubLabel,
    currencyCode,
    fallbackPartnerNames: [...fallbackNames].filter((value) =>
      value.length > 0
    ),
    resolvedClubId,
    resolvedPartnerId,
    routeCountry,
  };
}

async function resolveRayonTickets(
  adminClient: AdminClient,
  referenceMatch: RayonReferenceMatch,
): Promise<RsTicketRecord[]> {
  const result = await adminClient
    .from("rs_tickets")
    .select(
      "id, user_id, club_id, referral_invite_id, match_id, seat_type, amount_paid, qr_code, momo_reference, status, rs_matches(home_team, away_team, competition, venue, match_date, kickoff_time, partner_id)",
    )
    .eq("momo_reference", referenceMatch.reference)
    .order("purchased_at", { ascending: false });

  if (result.error) {
    throw result.error;
  }

  const rows = Array.isArray(result.data) ? result.data : [];
  return rows.map((value) => {
    const row = value as Record<string, unknown>;
    const match = asRecord(row.rs_matches);
    const homeTeam = asString(match?.home_team) ?? "Home Club";
    const awayTeam = asString(match?.away_team) ?? "Opponent";

    return {
      id: asString(row.id) ?? "",
      user_id: asString(row.user_id) ?? "",
      club_id: asNullableInt(row.club_id),
      referral_invite_id: asString(row.referral_invite_id),
      seat_type: asString(row.seat_type),
      amount_paid: asNullableInt(row.amount_paid) ?? 0,
      momo_reference: asString(row.momo_reference),
      status: asString(row.status),
      match_title: `${homeTeam} vs ${awayTeam}`,
      venue: asString(match?.venue),
      match_date: asString(match?.match_date),
      kickoff_time: shortTime(asString(match?.kickoff_time)),
      partner_id: asString(match?.partner_id),
    };
  });
}

async function resolveRayonShopOrder(
  adminClient: AdminClient,
  referenceMatch: RayonReferenceMatch,
): Promise<RsShopOrderRecord | null> {
  const result = await adminClient
    .from("rs_shop_orders")
    .select(
      "id, user_id, club_id, partner_id, referral_invite_id, total, delivery_address, momo_reference, status",
    )
    .eq("momo_reference", referenceMatch.reference)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (result.error) {
    throw result.error;
  }

  if (!result.data) {
    return null;
  }

  return {
    id: asString(result.data.id) ?? "",
    user_id: asString(result.data.user_id) ?? "",
    club_id: asNullableInt(result.data.club_id),
    partner_id: asString(result.data.partner_id),
    referral_invite_id: asString(result.data.referral_invite_id),
    total: asNullableInt(result.data.total) ?? 0,
    delivery_address: asString(result.data.delivery_address),
    momo_reference: asString(result.data.momo_reference),
    status: asString(result.data.status),
  };
}

async function resolveRayonInitiativeContribution(
  adminClient: AdminClient,
  referenceMatch: RayonReferenceMatch,
): Promise<RsInitiativeContributionRecord | null> {
  const result = await adminClient
    .from("rs_initiative_contributions")
    .select(
      "id, user_id, club_id, referral_invite_id, initiative_id, amount, momo_reference, status, rs_initiatives(title, partner_id)",
    )
    .eq("momo_reference", referenceMatch.reference)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (result.error) {
    throw result.error;
  }

  if (!result.data) {
    return null;
  }

  const initiative = asRecord(result.data.rs_initiatives);
  return {
    id: asString(result.data.id) ?? "",
    user_id: asString(result.data.user_id) ?? "",
    club_id: asNullableInt(result.data.club_id),
    referral_invite_id: asString(result.data.referral_invite_id),
    initiative_id: asString(result.data.initiative_id),
    amount: asNullableInt(result.data.amount) ?? 0,
    momo_reference: asString(result.data.momo_reference),
    status: asString(result.data.status),
    initiative_title: asString(initiative?.title) ?? "Club Initiative",
    partner_id: asString(initiative?.partner_id),
  };
}

function formatAmount(branding: PaymentBranding, amount: number): string {
  return branding.currencyCode
    ? `${branding.currencyCode} ${amount}`
    : `${amount}`;
}

async function maybeAwardMembershipPoints(
  adminClient: AdminClient,
  userId: string,
  partnerId: string | null,
  points: number,
): Promise<boolean> {
  if (!partnerId || points <= 0) {
    return false;
  }

  const result = await adminClient.rpc("rs_apply_membership_points", {
    p_user_id: userId,
    p_partner_id: partnerId,
    p_points: points,
  });

  if (result.error) {
    console.error("Failed to award membership points", result.error);
    return false;
  }

  return true;
}

async function maybeActivateReferralInvite(
  adminClient: AdminClient,
  inviteId: string | null,
  inviteeId: string,
  qualifyingEventType: string,
  qualifyingEventId: string,
  inviterPoints: number,
  inviteePoints: number,
): Promise<boolean> {
  if (!inviteId || !inviteeId) {
    return false;
  }

  const result = await adminClient.rpc("activate_referral_invite_for_user", {
    p_referral_invite_id: inviteId,
    p_invitee_id: inviteeId,
    p_qualifying_event_type: qualifyingEventType,
    p_qualifying_event_id: qualifyingEventId,
    p_inviter_points: inviterPoints,
    p_invitee_points: inviteePoints,
  });

  if (result.error) {
    console.error("Failed to activate referral invite", result.error);
    return false;
  }

  return true;
}

async function maybeSendWhatsAppConfirmation(
  phone: string | null,
  body: string,
): Promise<boolean> {
  if (!phone) {
    return false;
  }

  try {
    await sendTextMessage({ phone, body });
    return true;
  } catch (error) {
    console.error("Failed to send WhatsApp confirmation", error);
    return false;
  }
}

function buildRayonTicketConfirmationMessage(
  tickets: RsTicketRecord[],
  branding: PaymentBranding,
): string {
  const ticket = tickets[0];
  if (!ticket) {
    return `✅ ${branding.clubLabel} ticket confirmed`;
  }

  const totalAmount = tickets.reduce(
    (sum, entry) => sum + entry.amount_paid,
    0,
  );
  const lines = [
    `✅ ${branding.clubLabel} ticket confirmed`,
    ticket.match_title,
  ];
  const matchMeta = [ticket.venue, ticket.match_date, ticket.kickoff_time]
    .filter((value) => value && value.length > 0)
    .join(" · ");

  if (matchMeta.length > 0) {
    lines.push(matchMeta);
  }

  if (tickets.length > 1) {
    lines.push(
      `${tickets.length} tickets · ${formatAmount(branding, totalAmount)}`,
      `Reference: ${ticket.momo_reference ?? ticket.id}`,
    );
  } else {
    lines.push(
      `${ticket.seat_type ?? "General"} · ${
        formatAmount(branding, ticket.amount_paid)
      }`,
      `Reference: ${ticket.momo_reference ?? ticket.id}`,
    );
  }

  return lines.join("\n");
}

function buildRayonShopConfirmationMessage(
  order: RsShopOrderRecord,
  branding: PaymentBranding,
): string {
  const lines = [
    `✅ ${branding.clubLabel} shop order confirmed`,
    `${formatAmount(branding, order.total)} · Official club merchandise`,
  ];

  if (order.delivery_address) {
    lines.push(`Delivery: ${order.delivery_address}`);
  }

  lines.push(`Reference: ${order.momo_reference ?? order.id}`);
  return lines.join("\n");
}

function buildRayonSupportConfirmationMessage(
  contribution: RsInitiativeContributionRecord,
  branding: PaymentBranding,
): string {
  return [
    `✅ ${branding.clubLabel} support confirmed`,
    contribution.initiative_title,
    `${formatAmount(branding, contribution.amount)} contributed`,
    `Reference: ${contribution.momo_reference ?? contribution.id}`,
  ].join("\n");
}

async function confirmRayonTickets(
  adminClient: AdminClient,
  referenceMatch: RayonReferenceMatch,
  context: RayonPaymentConfirmationContext,
  tickets: RsTicketRecord[],
): Promise<RayonPaymentConfirmationResult> {
  const ticket = tickets[0];
  if (!ticket) {
    return buildManualReviewResult(
      "Rayon ticket rows were not found for the matched payment reference.",
      {
        reason: "missing_rayon_ticket_rows",
        matched_reference: referenceMatch.reference,
      },
    );
  }

  const confirmations = tickets.map((entry) => ({
    ticket: entry,
    confirmation: planRayonTicketConfirmation(entry.status),
  }));

  for (const entry of confirmations) {
    const updateResult = await adminClient
      .from("rs_tickets")
      .update({
        status: entry.confirmation.nextStatus,
        updated_at: context.timestamp,
      })
      .eq("id", entry.ticket.id);

    if (updateResult.error) {
      throw updateResult.error;
    }
  }

  const pointsToAward = confirmations.reduce(
    (sum, entry) => sum + entry.confirmation.pointsToAward,
    0,
  );
  const branding = await resolvePaymentBranding(adminClient, {
    clubId: ticket.club_id,
    partnerId: ticket.partner_id,
    routeCodeOrNumber: context.payeeNumberOrCode ?? context.merchantCode,
  });
  const pointsAwarded = await maybeAwardMembershipPoints(
    adminClient,
    ticket.user_id,
    ticket.partner_id ?? branding.resolvedPartnerId,
    pointsToAward,
  );
  const referralActivated = await maybeActivateReferralInvite(
    adminClient,
    ticket.referral_invite_id,
    ticket.user_id,
    "rayon_ticket_bought",
    ticket.id,
    140,
    60,
  );
  const shouldSendWhatsApp = confirmations.some((entry) =>
    entry.confirmation.shouldSendWhatsApp
  );
  const contact = shouldSendWhatsApp
    ? await resolveUserContact(adminClient, ticket.user_id)
    : null;
  const whatsappSent = await maybeSendWhatsAppConfirmation(
    contact?.whatsapp_number ?? contact?.phone ?? null,
    buildRayonTicketConfirmationMessage(tickets, branding),
  );

  return {
    matchType: "rayon_ticket",
    matchStatus: "matched",
    ledgerStatus: "posted",
    targetTable: "rs_tickets",
    targetRecordId: ticket.id,
    matchedReference: referenceMatch.reference,
    notes: "Club ticket payment confirmed.",
    metadata: {
      auto_match: true,
      candidate_score: context.candidateScore ?? null,
      provider: normalizeProviderId(context.provider),
      partner_id: ticket.partner_id,
      club_label: branding.clubLabel,
      currency_code: branding.currencyCode,
      ticket_count: tickets.length,
      ticket_ids: tickets.map((entry) => entry.id),
      points_awarded: pointsAwarded ? pointsToAward : 0,
      referral_activated: referralActivated,
      whatsapp_sent: whatsappSent,
      source: context.source,
    },
  };
}

async function confirmRayonShopOrder(
  adminClient: AdminClient,
  referenceMatch: RayonReferenceMatch,
  context: RayonPaymentConfirmationContext,
  order: RsShopOrderRecord,
): Promise<RayonPaymentConfirmationResult> {
  const confirmation = planRayonShopOrderConfirmation(
    order.status,
    order.total,
  );

  const updateResult = await adminClient
    .from("rs_shop_orders")
    .update({
      status: confirmation.nextStatus,
      updated_at: context.timestamp,
    })
    .eq("id", order.id);

  if (updateResult.error) {
    throw updateResult.error;
  }

  const branding = await resolvePaymentBranding(adminClient, {
    clubId: order.club_id,
    partnerId: order.partner_id,
    routeCodeOrNumber: context.payeeNumberOrCode ?? context.merchantCode,
  });
  const partnerId = order.partner_id ??
    branding.resolvedPartnerId ??
    await resolvePartnerIdByNames(adminClient, branding.fallbackPartnerNames);
  const pointsAwarded = await maybeAwardMembershipPoints(
    adminClient,
    order.user_id,
    partnerId,
    confirmation.pointsToAward,
  );
  const referralActivated = await maybeActivateReferralInvite(
    adminClient,
    order.referral_invite_id,
    order.user_id,
    "rayon_shop_order_confirmed",
    order.id,
    120,
    50,
  );
  const contact = confirmation.shouldSendWhatsApp
    ? await resolveUserContact(adminClient, order.user_id)
    : null;
  const whatsappSent = await maybeSendWhatsAppConfirmation(
    contact?.whatsapp_number ?? contact?.phone ?? null,
    buildRayonShopConfirmationMessage(order, branding),
  );

  return {
    matchType: "rayon_shop_order",
    matchStatus: "matched",
    ledgerStatus: "posted",
    targetTable: "rs_shop_orders",
    targetRecordId: order.id,
    matchedReference: referenceMatch.reference,
    notes: "Club shop order payment confirmed.",
    metadata: {
      auto_match: true,
      candidate_score: context.candidateScore ?? null,
      provider: normalizeProviderId(context.provider),
      partner_id: partnerId,
      club_label: branding.clubLabel,
      currency_code: branding.currencyCode,
      points_awarded: pointsAwarded ? confirmation.pointsToAward : 0,
      referral_activated: referralActivated,
      whatsapp_sent: whatsappSent,
      source: context.source,
      applied_status: confirmation.nextStatus,
    },
  };
}

async function confirmRayonInitiativeContribution(
  adminClient: AdminClient,
  referenceMatch: RayonReferenceMatch,
  context: RayonPaymentConfirmationContext,
  contribution: RsInitiativeContributionRecord,
): Promise<RayonPaymentConfirmationResult> {
  const confirmation = planRayonInitiativeConfirmation(
    contribution.status,
    contribution.amount,
  );

  const updateResult = await adminClient
    .from("rs_initiative_contributions")
    .update({
      status: confirmation.nextStatus,
      updated_at: context.timestamp,
    })
    .eq("id", contribution.id);

  if (updateResult.error) {
    throw updateResult.error;
  }

  if (
    confirmation.shouldIncrementInitiativeTotals && contribution.initiative_id
  ) {
    const initiativeResult = await adminClient
      .from("rs_initiatives")
      .select("raised_amount, supporter_count")
      .eq("id", contribution.initiative_id)
      .maybeSingle();

    if (initiativeResult.error) {
      throw initiativeResult.error;
    }

    const currentRaised = asNullableInt(initiativeResult.data?.raised_amount) ??
      0;
    const currentSupporters =
      asNullableInt(initiativeResult.data?.supporter_count) ?? 0;

    const correctedResult = await adminClient
      .from("rs_initiatives")
      .update({
        raised_amount: currentRaised + contribution.amount,
        supporter_count: currentSupporters + 1,
        updated_at: context.timestamp,
      })
      .eq("id", contribution.initiative_id);

    if (correctedResult.error) {
      throw correctedResult.error;
    }
  }

  const branding = await resolvePaymentBranding(adminClient, {
    clubId: contribution.club_id,
    partnerId: contribution.partner_id,
    routeCodeOrNumber: context.payeeNumberOrCode ?? context.merchantCode,
  });
  const pointsAwarded = await maybeAwardMembershipPoints(
    adminClient,
    contribution.user_id,
    contribution.partner_id ?? branding.resolvedPartnerId,
    confirmation.pointsToAward,
  );
  const referralActivated = await maybeActivateReferralInvite(
    adminClient,
    contribution.referral_invite_id,
    contribution.user_id,
    "rayon_support_confirmed",
    contribution.id,
    130,
    50,
  );
  const contact = confirmation.shouldSendWhatsApp
    ? await resolveUserContact(adminClient, contribution.user_id)
    : null;
  const whatsappSent = await maybeSendWhatsAppConfirmation(
    contact?.whatsapp_number ?? contact?.phone ?? null,
    buildRayonSupportConfirmationMessage(contribution, branding),
  );

  return {
    matchType: "rayon_initiative_support",
    matchStatus: "matched",
    ledgerStatus: "posted",
    targetTable: "rs_initiative_contributions",
    targetRecordId: contribution.id,
    matchedReference: referenceMatch.reference,
    notes: "Club initiative contribution confirmed.",
    metadata: {
      auto_match: true,
      candidate_score: context.candidateScore ?? null,
      provider: normalizeProviderId(context.provider),
      partner_id: contribution.partner_id,
      club_label: branding.clubLabel,
      currency_code: branding.currencyCode,
      points_awarded: pointsAwarded ? confirmation.pointsToAward : 0,
      referral_activated: referralActivated,
      whatsapp_sent: whatsappSent,
      source: context.source,
    },
  };
}

export async function confirmRayonReferenceMatch(
  adminClient: AdminClient,
  referenceMatch: RayonReferenceMatch,
  context: RayonPaymentConfirmationContext,
): Promise<RayonPaymentConfirmationResult> {
  if (looksLikeRayonTicketReference(referenceMatch.reference)) {
    const tickets = await resolveRayonTickets(adminClient, referenceMatch);
    if (tickets.length === 0) {
      return buildManualReviewResult(
        "No ticket rows matched the payment reference.",
        {
          reason: "missing_rayon_ticket_rows",
          matched_reference: referenceMatch.reference,
        },
      );
    }

    return await confirmRayonTickets(
      adminClient,
      referenceMatch,
      context,
      tickets,
    );
  }

  if (looksLikeRayonSupportReference(referenceMatch.reference)) {
    const contribution = await resolveRayonInitiativeContribution(
      adminClient,
      referenceMatch,
    );
    if (!contribution) {
      return buildManualReviewResult(
        "No initiative contribution matched the payment reference.",
        {
          reason: "missing_rayon_support_row",
          matched_reference: referenceMatch.reference,
        },
      );
    }

    return await confirmRayonInitiativeContribution(
      adminClient,
      referenceMatch,
      context,
      contribution,
    );
  }

  if (looksLikeRayonShopReference(referenceMatch.reference)) {
    const order = await resolveRayonShopOrder(adminClient, referenceMatch);
    if (!order) {
      return buildManualReviewResult(
        "No shop order matched the payment reference.",
        {
          reason: "missing_rayon_shop_order",
          matched_reference: referenceMatch.reference,
        },
      );
    }

    return await confirmRayonShopOrder(
      adminClient,
      referenceMatch,
      context,
      order,
    );
  }

  return buildManualReviewResult(
    "Payment reference is not a supported club payment.",
    {
      reason: "unsupported_rayon_reference",
      matched_reference: referenceMatch.reference,
    },
  );
}
