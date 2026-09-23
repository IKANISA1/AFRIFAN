import { defineConfig, devices } from "@playwright/test";

const port = 3200;
const baseURL = `http://127.0.0.1:${port}`;

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: false,
  workers: 1,
  reporter: "list",
  use: {
    baseURL,
    trace: "on-first-retry",
    screenshot: "only-on-failure",
  },
  projects: [
    {
      name: "desktop-chromium",
      use: {
        ...devices["Desktop Chrome"],
        // The full browser supplies the worker BadgeService used by the PWA.
        // chromium-headless-shell exposes the API but crashes on its IPC call.
        channel: "chromium",
        viewport: { width: 1440, height: 900 },
        launchOptions: {
          args: ["--disable-features=ViewTransitionOnNavigation"],
        },
      },
    },
    {
      name: "desktop-webkit",
      use: {
        ...devices["Desktop Safari"],
        viewport: { width: 1440, height: 900 },
      },
    },
    {
      name: "desktop-firefox",
      use: {
        ...devices["Desktop Firefox"],
        viewport: { width: 1440, height: 900 },
      },
    },
    {
      name: "mobile-chromium",
      use: {
        browserName: "chromium",
        ...devices["Pixel 7"],
        channel: "chromium",
        launchOptions: {
          args: ["--disable-features=ViewTransitionOnNavigation"],
        },
      },
    },
    {
      name: "tablet-chromium",
      use: {
        browserName: "chromium",
        ...devices["iPad Pro 11"],
        channel: "chromium",
      },
    },
    {
      name: "mobile-webkit",
      use: {
        browserName: "webkit",
        ...devices["iPhone 14"],
      },
    },
  ],
});
