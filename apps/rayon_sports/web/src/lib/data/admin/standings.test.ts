import { describe, expect, it } from "vitest";
import { normalizeAdminStandings } from "./standings";

const validRow = {
  id: "standing-1",
  clubId: 24,
  position: 1,
  club: "Rayon Sports",
  played: 18,
  goalDifference: 24,
  points: 45,
  form: ["W", "W", "D", "W", "L"],
  clubSlug: "rayon-sports",
  updatedAt: "2026-07-29T12:00:00.000Z",
  privateBudget: 12_000,
  accessToken: "private-token",
};

describe("admin standings response normalization", () => {
  it("keeps only bounded competition fields and drops private extras", () => {
    const [result] = normalizeAdminStandings([validRow]);

    expect(result).toEqual({
      id: "standing-1",
      clubId: 24,
      position: 1,
      club: "Rayon Sports",
      played: 18,
      goalDifference: 24,
      points: 45,
      form: ["W", "W", "D", "W", "L"],
      clubSlug: "rayon-sports",
      updatedAt: "2026-07-29T12:00:00.000Z",
    });
    expect(JSON.stringify(result)).not.toContain("privateBudget");
    expect(JSON.stringify(result)).not.toContain("private-token");
  });

  it("rejects invalid positions, totals, form values, dates, and malformed rows", () => {
    expect(
      normalizeAdminStandings([
        { ...validRow, id: "bad-position", position: 0 },
        { ...validRow, id: "bad-played", played: -1 },
        { ...validRow, id: "bad-form", form: ["W", "SECRET"] },
        { ...validRow, id: "bad-date", updatedAt: "not-a-date" },
        null,
      ]),
    ).toEqual([]);
  });

  it("caps the collection at 500 valid rows", () => {
    const normalized = normalizeAdminStandings(
      Array.from({ length: 510 }, (_, index) => ({
        ...validRow,
        id: `standing-${index + 1}`,
        position: index + 1,
      })),
    );

    expect(normalized).toHaveLength(500);
    expect(normalized.at(-1)?.id).toBe("standing-500");
  });

  it("fails closed for a non-array response", () => {
    expect(normalizeAdminStandings({ data: [validRow] })).toEqual([]);
  });
});
