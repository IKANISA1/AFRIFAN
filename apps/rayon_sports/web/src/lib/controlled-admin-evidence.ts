export type ControlledAdminEvidenceInput = {
  previewEnabled?: string;
  adminEvidenceEnabled?: string;
  evidenceRequested?: boolean;
  host?: string | null;
};

export const controlledAdminEvidenceRequestHeader =
  "x-africlub-controlled-admin-evidence";

function normalizeHostname(host: string | null | undefined) {
  const value = host?.trim();
  if (!value || value.includes(",")) {
    return null;
  }

  try {
    return new URL(`http://${value}`).hostname.toLowerCase();
  } catch {
    return null;
  }
}

export function isControlledAdminEvidenceAllowed({
  previewEnabled,
  adminEvidenceEnabled,
  evidenceRequested,
  host,
}: ControlledAdminEvidenceInput) {
  if (
    previewEnabled !== "1" ||
    adminEvidenceEnabled !== "1" ||
    evidenceRequested !== true
  ) {
    return false;
  }

  const hostname = normalizeHostname(host);
  return (
    hostname === "127.0.0.1" ||
    hostname === "localhost" ||
    hostname === "[::1]"
  );
}
