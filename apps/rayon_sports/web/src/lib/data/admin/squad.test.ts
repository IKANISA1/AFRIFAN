import { describe, expect, it } from "vitest";
import { normalizeAdminSquad } from "./squad";

const validPlayer = {
  id: "player-1",
  clubId: 24,
  name: "Aline Umutoni",
  role: "Midfielder",
  number: 8,
  nationality: "Rwanda",
  bio: "First-team midfielder.",
  imageUrl: "https://cdn.example.com/player.webp",
  isActive: true,
  createdAt: "2026-07-20T12:00:00.000Z",
  updatedAt: "2026-07-29T12:00:00.000Z",
  medicalNotes: "must not render",
  accessToken: "private-token",
};

describe("admin squad response normalization", () => {
  it("keeps only bounded roster fields and drops private extras", () => {
    const [result] = normalizeAdminSquad([validPlayer]);

    expect(result).toEqual({
      id: "player-1",
      clubId: 24,
      name: "Aline Umutoni",
      role: "Midfielder",
      number: 8,
      nationality: "Rwanda",
      bio: "First-team midfielder.",
      imageUrl: "https://cdn.example.com/player.webp",
      isActive: true,
      createdAt: "2026-07-20T12:00:00.000Z",
      updatedAt: "2026-07-29T12:00:00.000Z",
    });
    expect(JSON.stringify(result)).not.toContain("medicalNotes");
    expect(JSON.stringify(result)).not.toContain("private-token");
  });

  it("rejects invalid roles, numbers, identifiers, dates, and malformed rows", () => {
    expect(
      normalizeAdminSquad([
        { ...validPlayer, id: "" },
        { ...validPlayer, id: "bad-role", role: "Administrator" },
        { ...validPlayer, id: "bad-number", number: 100 },
        { ...validPlayer, id: "bad-date", updatedAt: "not-a-date" },
        null,
      ]),
    ).toEqual([]);
  });

  it("caps the collection and removes unsafe media", () => {
    const unsafeScheme = ["java", "script:alert(1)"].join("");
    const safeLocalMedia = "/admin/squad/player-image";
    const rows = Array.from({ length: 510 }, (_, index) => ({
      ...validPlayer,
      id: `player-${index + 1}`,
      number: (index % 99) + 1,
      imageUrl: index === 0 ? unsafeScheme : safeLocalMedia,
    }));
    const normalized = normalizeAdminSquad(rows);

    expect(normalized).toHaveLength(500);
    expect(normalized[0]?.imageUrl).toBeNull();
    expect(normalized[1]?.imageUrl).toBe(safeLocalMedia);
  });

  it("fails closed for a non-array response", () => {
    expect(normalizeAdminSquad({ data: [validPlayer] })).toEqual([]);
  });
});
