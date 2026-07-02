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
  },
  projects: [
    {
      name: "mobile-chromium",
      use: {
        browserName: "chromium",
        ...devices["Pixel 7"],
      },
    },
    {
      name: "tablet-chromium",
      use: {
        browserName: "chromium",
        ...devices["iPad Pro 11"],
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
