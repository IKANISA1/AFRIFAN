# Public-site search verification

Use this procedure for the public domain assigned to the candidate deployment.
Confirm the domain and serving version first; a configured hostname does not
prove that this checkout is serving it.

1. Verify the public domain in [Google Search Console](https://search.google.com/search-console)
   using the approved DNS or site verification method.
2. Fetch `/robots.txt` and `/sitemap.xml` from the deployed origin. Compare them
   with `src/app/robots.ts` and `src/app/sitemap.ts`.
3. Check that sitemap URLs use the intended public origin, return successful
   responses, and contain public content. Private member, admin, venue, and API
   responses must not be exposed through the public sitemap.
4. Submit the sitemap and inspect representative public routes. Record the
   observed crawl and indexing result; successful submission alone does not
   prove indexing.
5. Review field performance when traffic data is available. Use the repository
   Lighthouse command for reproducible lab checks and investigate regressions
   against the same route, device profile, and deployed version.
6. Validate any structured data actually emitted by the candidate. Do not infer
   eligibility for search features from a schema type alone.

Keep deployment-specific verification receipts outside tracked source. Never
publish member identifiers or authenticated operator content as search evidence.
