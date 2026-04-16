type PaymentRoutingClient = {
  from(table: string): any;
};

export type BioPayPaymentRouting = {
  countryCode: string;
  currencyCode: string;
  currencySymbol: string;
  paymentMethod: "ussd_dial";
  paymentTemplate: string;
  senderName: string | null;
};

function asTrimmedString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function defaultCurrencySymbol(currencyCode: string): string {
  switch (currencyCode.trim().toUpperCase()) {
    case "RWF":
      return "FRw";
    case "BIF":
      return "FBu";
    case "CDF":
      return "FC";
    case "GHS":
      return "GH₵";
    case "TZS":
      return "TSh";
    case "MWK":
      return "MK";
    case "ZMW":
      return "K";
    case "XAF":
    case "XOF":
      return "CFA";
    default:
      return currencyCode.trim().toUpperCase() || "$";
  }
}

function collapseDialArtifacts(value: string): string {
  let normalized = value.trim();
  while (normalized.includes("**")) {
    normalized = normalized.replaceAll("**", "*");
  }
  normalized = normalized.replaceAll("*#", "#");
  return normalized;
}

export async function resolveBioPayPaymentRouting(
  adminClient: PaymentRoutingClient,
  options: {
    clubId?: number | null;
    countryCode?: string | null;
    routeType?: string | null;
  },
): Promise<BioPayPaymentRouting> {
  let effectiveCountryCode = asTrimmedString(options.countryCode)?.toUpperCase() ??
    null;
  let clubTemplate: string | null = null;
  let senderName: string | null = null;
  let currencyCode: string | null = null;
  let currencySymbol: string | null = null;

  if (options.clubId != null) {
    const { data: clubRow, error: clubError } = await adminClient
      .from("african_football_clubs")
      .select(
        "country_iso_code, momo_ussd_template, momo_sender_name, currency_code, currency_symbol",
      )
      .eq("id", options.clubId)
      .maybeSingle();

    if (clubError) {
      throw clubError;
    }

    if (clubRow) {
      effectiveCountryCode ??=
        asTrimmedString(clubRow["country_iso_code"])?.toUpperCase() ?? null;
      clubTemplate = asTrimmedString(clubRow["momo_ussd_template"]);
      senderName = asTrimmedString(clubRow["momo_sender_name"]);
      currencyCode = asTrimmedString(clubRow["currency_code"])?.toUpperCase() ??
        null;
      currencySymbol = asTrimmedString(clubRow["currency_symbol"]);
    }
  }

  effectiveCountryCode ??= "RW";

  const { data: countryRow, error: countryError } = await adminClient
    .from("countries")
    .select("id, currency, ussd_number_format, ussd_code_format, momo_brand")
    .eq("id", effectiveCountryCode)
    .maybeSingle();

  if (countryError) {
    throw countryError;
  }

  const routeType = asTrimmedString(options.routeType) ?? "phone_number";
  const preferredCountryTemplate = routeType === "code"
    ? asTrimmedString(countryRow?.["ussd_code_format"])
    : asTrimmedString(countryRow?.["ussd_number_format"]);
  const paymentTemplate = preferredCountryTemplate ??
    clubTemplate ??
    asTrimmedString(countryRow?.["ussd_number_format"]) ??
    asTrimmedString(countryRow?.["ussd_code_format"]);

  if (paymentTemplate == null) {
    throw new Error(
      `No BioPay payment template is configured for ${effectiveCountryCode}.`,
    );
  }

  const resolvedCurrencyCode = currencyCode ??
    asTrimmedString(countryRow?.["currency"])?.toUpperCase() ??
    "USD";

  return {
    countryCode: effectiveCountryCode,
    currencyCode: resolvedCurrencyCode,
    currencySymbol: currencySymbol ?? defaultCurrencySymbol(resolvedCurrencyCode),
    paymentMethod: "ussd_dial",
    paymentTemplate,
    senderName: senderName ?? asTrimmedString(countryRow?.["momo_brand"]),
  };
}

export function buildBioPayPaymentCode(options: {
  paymentTemplate: string;
  routeType: string;
  recipientValue: string;
  amount?: number | null;
}): string {
  const routeType = options.routeType.trim().toLowerCase();
  if (routeType !== "phone_number" && routeType !== "code") {
    throw new Error(`Unknown route type: ${options.routeType}`);
  }

  const cleanedRecipient = options.recipientValue.trim().replaceAll(
    /\s+/g,
    "",
  );
  const normalizedAmount = typeof options.amount === "number" &&
    Number.isFinite(options.amount) && options.amount > 0
    ? Math.trunc(options.amount).toString()
    : null;

  let paymentCode = options.paymentTemplate.trim();
  const recipientPlaceholders = routeType === "code"
    ? ["{recipient}", "{momo}", "{code}", "{merchant_code}"]
    : ["{recipient}", "{momo}", "{phone}", "{number}"];

  for (const placeholder of recipientPlaceholders) {
    paymentCode = paymentCode.replaceAll(placeholder, cleanedRecipient);
  }

  if (normalizedAmount != null) {
    paymentCode = paymentCode.replaceAll("{amount}", normalizedAmount);
  } else {
    paymentCode = paymentCode.replaceAll("*{amount}", "").replaceAll(
      "{amount}",
      "",
    );
  }

  return collapseDialArtifacts(paymentCode);
}
