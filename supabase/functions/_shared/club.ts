type ClubResolverClient = {
  rpc(
    fn: string,
    args: Record<string, unknown>,
  ):
    | PromiseLike<{ data: unknown; error: unknown }>
    | { data: unknown; error: unknown };
};

function asTrimmedString(value: unknown): string | null {
  if (typeof value == "number" && Number.isFinite(value)) {
    return Math.trunc(value).toString();
  }
  if (typeof value != "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

export async function resolveClubIdFromMetadata(
  adminClient: ClubResolverClient,
  appMetadata: Record<string, unknown> | null | undefined,
): Promise<number> {
  const rawClubId = asTrimmedString(appMetadata?.["club_id"]);
  if (rawClubId == null) {
    throw new Error("Club context required.");
  }

  if (/^[0-9]+$/.test(rawClubId)) {
    const numericClubId = Number.parseInt(rawClubId, 10);
    if (Number.isFinite(numericClubId)) {
      return numericClubId;
    }
  }

  const { data, error } = await adminClient.rpc("normalize_club_id", {
    raw_club_id: rawClubId,
  });
  if (error) {
    throw error;
  }

  const normalizedClubId = Number(data);
  if (!Number.isFinite(normalizedClubId)) {
    throw new Error("Club context required.");
  }

  return normalizedClubId;
}
