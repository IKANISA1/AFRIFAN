import { defineConfig, devices } from "@playwright/test";
import { localClubs } from "./fixtures/local-route-assertions.mjs";

export default defineConfig({
  testDir: ".",
  testMatch: "*state-evidence.spec.ts",
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: "json",
  use: { baseURL: "http://127.0.0.1:3200", trace: "off", screenshot: "only-on-failure", serviceWorkers: "block" },
  projects: localClubs.map((club) => ({
    name: `${club.slug}-desktop-chromium`,
    metadata: { localClub: club.slug },
    use: { ...devices["Desktop Chrome"], channel: "chromium", viewport: { width: 1440, height: 900 }, extraHTTPHeaders: { "x-forwarded-host": club.host }, launchOptions: { args: [
      "--disable-features=ViewTransitionOnNavigation",
    ] } },
  })),
});
