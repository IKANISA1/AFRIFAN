import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import {
  LegalDocument,
  normalizeLegalParagraphs,
  resolveLegalDocumentText,
} from "./legal-document";

describe("LegalDocument", () => {
  it("renders one descriptive heading and normalized document paragraphs", () => {
    const { container } = render(
      <LegalDocument
        eyebrow="Privacy"
        title="Privacy policy"
        content={"First paragraph.\r\n\r\n  Second paragraph.  "}
        documentKind="privacy"
      />,
    );

    expect(
      screen.getByRole("heading", { level: 1, name: "Privacy policy" }),
    ).toBeVisible();
    expect(screen.getByText("First paragraph.")).toBeVisible();
    expect(screen.getByText("Second paragraph.")).toBeVisible();
    expect(
      container.querySelectorAll("a, button, input, select, textarea"),
    ).toHaveLength(0);
    expect(
      container.querySelector("[data-legal-document='privacy']"),
    ).toBeTruthy();
  });

  it("falls back when CMS title or body is absent or whitespace-only", () => {
    expect(resolveLegalDocumentText(null, "Fallback")).toBe("Fallback");
    expect(resolveLegalDocumentText("   ", "Fallback")).toBe("Fallback");
    expect(resolveLegalDocumentText(" Current ", "Fallback")).toBe("Current");
    expect(normalizeLegalParagraphs("\n\n First \n\n\n Second \n\n")).toEqual([
      "First",
      "Second",
    ]);
  });
});
