export function normalizeAdminPhone(input: string) {
  const trimmed = input.trim();
  if (!trimmed) {
    throw new Error("Enter the admin phone number.");
  }

  let normalized = trimmed.replace(/[^\d+]/g, "");
  if (normalized.startsWith("00")) {
    normalized = `+${normalized.slice(2)}`;
  }

  if (!normalized.startsWith("+")) {
    if (/^0\d{9}$/.test(normalized)) {
      normalized = `+250${normalized.slice(1)}`;
    } else if (/^\d{9}$/.test(normalized)) {
      normalized = `+250${normalized}`;
    } else {
      normalized = `+${normalized}`;
    }
  }

  normalized = normalized.replace(/(?!^)\+/g, "");
  if (!/^\+[1-9]\d{7,14}$/.test(normalized)) {
    throw new Error("Use a valid phone number in international format.");
  }

  return normalized;
}

export function formatAdminPhoneForDisplay(phone: string) {
  if (!phone.startsWith("+")) {
    return phone;
  }

  if (phone.startsWith("+250") && phone.length === 13) {
    return `+250 ${phone.slice(4, 7)} ${phone.slice(7, 10)} ${phone.slice(10)}`;
  }

  return phone;
}

export function normalizeAdminPhoneDigits(input: string) {
  return normalizeAdminPhone(input).replace(/\D/g, "");
}

export function adminPhoneAccessDeniedMessage() {
  return "This phone number is not approved for admin access.";
}
