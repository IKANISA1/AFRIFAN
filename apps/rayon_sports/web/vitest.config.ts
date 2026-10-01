import path from "node:path";
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./vitest.setup.ts"],
    // Keep installed context lookup inside Vitest's module boundary so its
    // optional Wrangler factory is intercepted by the context regression.
    server: { deps: { inline: ["@opennextjs/cloudflare"] } },
    exclude: ["e2e/**", "node_modules/**", ".next/**", ".open-next/**", "tmp/**", "coverage/**"],
    coverage: {
      provider: "v8",
      reporter: ["text", "html", "json-summary"],
      include: ["src/lib/**/*.ts", "src/components/**/*.tsx"],
    },
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
