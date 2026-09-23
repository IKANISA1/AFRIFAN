module.exports = {
  ci: {
    collect: {
      startServerCommand:
        "npx next start --hostname 127.0.0.1 --port 3310",
      startServerReadyPattern: "Ready in",
      url: [
        "http://127.0.0.1:3310/",
        "http://127.0.0.1:3310/fixtures",
        "http://127.0.0.1:3310/news",
      ],
      numberOfRuns: 3,
      settings: {
        // Lighthouse no longer supports the legacy "mobile" preset flag.
        // These settings preserve a mobile audit profile on throttled hardware.
        formFactor: "mobile",
        screenEmulation: {
          mobile: true,
          width: 390,
          height: 844,
          deviceScaleFactor: 2,
          disabled: false,
        },
        throttling: {
          cpuSlowdownMultiplier: 4,
        },
      },
    },
    assert: {
      assertions: {
        // Performance — Essential CWV targets (world-class: ≥ 0.90 on mobile)
        "categories:performance": ["error", { minScore: 0.9 }],

        // Accessibility (WCAG 2.2 AA — world-class: ≥ 0.90)
        "categories:accessibility": ["error", { minScore: 0.9 }],

        // Best Practices
        "categories:best-practices": ["error", { minScore: 0.9 }],

        // SEO
        "categories:seo": ["error", { minScore: 0.9 }],
      },
    },
  },
};
