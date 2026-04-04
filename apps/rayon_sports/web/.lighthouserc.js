module.exports = {
  ci: {
    collect: {
      // Run against the production build output
      staticDistDir: ".next",
      url: ["/", "/app", "/admin"],
      numberOfRuns: 3,
      settings: {
        // Simulate a mid-range mobile device on throttled 4G (world-class standard)
        preset: "mobile",
        throttling: {
          cpuSlowdownMultiplier: 4,
        },
      },
    },
    assert: {
      assertions: {
        // Performance — Essential CWV targets (world-class: ≥ 0.90 on mobile)
        "categories:performance": ["error", { minScore: 0.9 }],

        // PWA audit
        "categories:pwa": ["error", { minScore: 0.9 }],

        // Accessibility (WCAG 2.2 AA — world-class: ≥ 0.90)
        "categories:accessibility": ["error", { minScore: 0.9 }],

        // Best Practices
        "categories:best-practices": ["error", { minScore: 0.9 }],

        // SEO
        "categories:seo": ["error", { minScore: 0.9 }],
      },
    },
    upload: {
      target: "temporary-public-storage",
    },
  },
};
