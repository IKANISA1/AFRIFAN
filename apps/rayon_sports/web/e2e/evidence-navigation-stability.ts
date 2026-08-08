import type { BrowserContext, Page } from "@playwright/test";

type NavigationTransitionEvent = Event & {
  viewTransition?: {
    skipTransition(): void;
  } | null;
};

/**
 * Prevent automatic cross-document view transitions from being captured
 * halfway through a governed evidence screenshot. This is test-only and does
 * not alter the product's motion behavior.
 */
export async function installEvidenceNavigationStability(
  context: BrowserContext,
) {
  await context.addInitScript(() => {
    const disableAutomaticNavigationTransitions = () => {
      if (
        document.querySelector(
          "style[data-evidence-navigation-stability='true']",
        )
      ) {
        return;
      }
      const style = document.createElement("style");
      style.dataset.evidenceNavigationStability = "true";
      style.textContent = "@view-transition { navigation: none; }";
      (document.head ?? document.documentElement).append(style);
    };

    if (document.readyState === "loading") {
      document.addEventListener(
        "DOMContentLoaded",
        disableAutomaticNavigationTransitions,
        { once: true },
      );
    } else {
      disableAutomaticNavigationTransitions();
    }

    const skipNavigationTransition = (event: Event) => {
      (event as NavigationTransitionEvent).viewTransition?.skipTransition();
    };

    window.addEventListener("pageswap", skipNavigationTransition);
    window.addEventListener("pagereveal", skipNavigationTransition);
  });
}

/**
 * Let finite navigation motion settle naturally. Force-finishing every
 * document animation can leave Chromium's view-transition compositor in a
 * partially painted state even though DOM visibility assertions pass.
 */
export async function settleEvidenceVisuals(page: Page) {
  await page.evaluate(async () => {
    await document.fonts.ready;
    await new Promise<void>((resolve) => setTimeout(resolve, 350));
    await new Promise<void>((resolve) =>
      requestAnimationFrame(() => requestAnimationFrame(() => resolve())),
    );
  });
}

/**
 * Materialize Chromium's compositor surface before a governed responsive
 * capture. The discarded frame prevents an intermittent stale transition
 * layer from becoming the evidence artifact after a viewport-context change.
 */
export async function primeEvidenceScreenshot(page: Page, fullPage: boolean) {
  await page.bringToFront();
  for (let frame = 0; frame < 3; frame += 1) {
    await page.screenshot({ fullPage });
    await page.evaluate(
      () =>
        new Promise<void>((resolve) =>
          requestAnimationFrame(() => requestAnimationFrame(() => resolve())),
        ),
    );
  }
}
