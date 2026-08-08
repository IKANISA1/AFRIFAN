export type ControlledVenueEvidenceInput = {
  previewEnabled?: string;
  venueEvidenceEnabled?: string;
  host?: string | null;
};

function normalizeHostname(host: string | null | undefined) {
  const value = host?.trim();
  if (!value || value.includes(",")) return null;

  try {
    return new URL(`http://${value}`).hostname.toLowerCase();
  } catch {
    return null;
  }
}

export function isControlledVenueEvidenceAllowed({
  previewEnabled,
  venueEvidenceEnabled,
  host,
}: ControlledVenueEvidenceInput) {
  if (previewEnabled !== "1" || venueEvidenceEnabled !== "1") return false;

  const hostname = normalizeHostname(host);
  return (
    hostname === "127.0.0.1" || hostname === "localhost" || hostname === "[::1]"
  );
}
