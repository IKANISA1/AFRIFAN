import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  {
    rules: {
      "@typescript-eslint/no-unused-vars": [
        "warn",
        {
          argsIgnorePattern: "^_",
          caughtErrorsIgnorePattern: "^_",
          varsIgnorePattern: "^_",
        },
      ],
    },
  },
  {
    // Node's --require preload hooks must stay CommonJS. Keep this exemption
    // scoped to the two immutable-input/evidence guards, not all E2E code.
    files: [
      "e2e/fixtures/local-evidence-inputs-readonly.cjs",
      "e2e/fixtures/local-evidence-thread-proof.cjs",
    ],
    rules: { "@typescript-eslint/no-require-imports": "off" },
  },
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    "node_modules/**",
    ".next/**",
    ".open-next/**",
    "out/**",
    "build/**",
    "coverage/**",
    "test-results/**",
    "tmp/**",
    "next-env.d.ts",
  ]),
]);

export default eslintConfig;
