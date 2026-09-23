import { act, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { ShareTargetContent } from "./share-target-content";

function renderTarget(
  overrides: Partial<Parameters<typeof ShareTargetContent>[0]> = {},
) {
  return render(
    <ShareTargetContent
      appHref="/app"
      query=""
      sharedTitle=""
      sharedText=""
      sharedUrl={null}
      unsafeUrlOmitted={false}
      shortTitle="AfriClub"
      {...overrides}
    />,
  );
}

describe("ShareTargetContent", () => {
  it("renders a truthful empty state and safe destinations", () => {
    renderTarget();

    expect(
      screen.getByRole("heading", { name: /no shared content was received/i }),
    ).toBeVisible();
    expect(
      screen.getByText(/nothing has been submitted or published/i),
    ).toBeVisible();
    expect(
      screen.getByRole("link", { name: /search the official site/i }),
    ).toHaveAttribute("href", "/search");
    expect(
      screen.queryByRole("link", { name: /open original/i }),
    ).toBeNull();
  });

  it("retains bounded content and reports offline consequences", () => {
    renderTarget({
      query: "Match report https://example.com/story",
      sharedTitle: "Match report",
      sharedText: "Official recap",
      sharedUrl: "https://example.com/story",
    });

    expect(screen.getByText("Match report")).toBeVisible();
    expect(screen.getByText("Official recap")).toBeVisible();
    expect(
      screen.getByRole("link", { name: /open original secure link/i }),
    ).toHaveAttribute("href", "https://example.com/story");

    act(() => {
      Object.defineProperty(window.navigator, "onLine", {
        configurable: true,
        value: false,
      });
      window.dispatchEvent(new Event("offline"));
    });

    expect(screen.getByRole("status")).toHaveTextContent(
      /external destinations need a connection/i,
    );
  });

  it("explains when an unsupported link is omitted", () => {
    renderTarget({ unsafeUrlOmitted: true });

    expect(screen.getByRole("alert")).toHaveTextContent(
      /only HTTP and HTTPS web links/i,
    );
  });
});
