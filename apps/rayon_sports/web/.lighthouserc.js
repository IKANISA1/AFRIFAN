module.exports = {
  ci: {
    collect: {
      // Run against the production build output
      staticDistDir: ".next",
      url: ["/", "/app", "/admin"],
      numberOfRuns: 3,
      settings: {
        // Simulate a mid-range mobile device on 4G
        preset: "desktop",
        throttling: {
          cpuSlowdownMultiplier: 2,
        },
      },
    },
    assert: {
      assertions: {
        // Performance — Essential CWV targets
        "categories:performance": ["warn", { minScore: 0.85 }],

        // PWA audit
        "categories:pwa": ["error", { minScore: 0.9 }],

        // Accessibility
        "categories:accessibility": ["warn", { minScore: 0.85 }],

        // Best Practices
        "categories:best-practices": ["warn", { minScore: 0.9 }],

        // SEO
        "categories:seo": ["warn", { minScore: 0.9 }],
      },
    },
    upload: {
      target: "temporary-public-storage",
    },
  },
};
