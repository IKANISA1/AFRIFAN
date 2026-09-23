# Product map corrections — 20 September 2026

The local Product Design map and working source implement the owner's corrections:

- One central admin manages Rayon Sports, Vital’O, Nkana and AS Vita.
- Predict is the only supported prediction destination. Active old navigation, entry workflows and compatibility redirects are removed.
- Every offered membership is paid. A signed-in supporter selects any configured paid tier; the app prepares an authoritative payment order and opens the configured MoMo dialer. Posted, matched payment evidence activates the selected tier automatically. There is no application, eligibility check or approval queue in this journey.
- Published tier prices must be positive whole amounts. The mobile catalog, server catalog policy and admin editor exclude zero-price memberships. Old free-activation endpoints are no longer executable by client or service roles.
- Mobile and web both open server-prepared, club-bound MoMo instructions. They reject stale account/club responses and duplicate in-flight taps. Membership data refreshes after returning from payment.
- Home displays the purchased tier without contribution qualification. Wallet credits, debits and Predict settlement preserve it. Unpaid wallet rows and retired free fan records do not display as paid membership cards.
- The manual membership-review API, client mutation helpers, legacy confirmation sheet and unused review copy are removed. Database grants also prevent calls through the old review wrappers.
- Shared admin payment routes preserve the selected club country; Burundi is included alongside Rwanda, Zambia and DR Congo. Provider configuration is still required.
- CI enforces the revised source boundary and runs the isolated paid-membership database regression contract. Stored feature/navigation constraints prevent reintroducing retired destinations.
- FanClubs replaces Chapter/Chapters in customer and admin display copy. Existing database/API field names are preserved.
- Contribution payment matching stays in the backend; the product map describes amount entry, payment, confirmed history and statement download.

## Data migrations

Four new migrations retire unsupported prediction surfaces, standardize stored display labels, and introduce automatic paid membership orders, and enforce the revised product boundaries. Historical financial records are retained in a private schema. Retirement refuses to proceed while unsettled old entries would strand funds. Historical migration definitions and explicit negative regression assertions remain in the repository so existing databases can be upgraded safely.

The paid-membership trigger binds user, club, package price snapshot, receiver, intent, parsed SMS, reconciliation and posted ledger entry. A retry cannot activate twice or extend the expiry a second time.

## Local verification

Latest enforcement pass:

- Strict Flutter workspace analysis: passed, no issues.
- Workspace architecture validator: passed.
- Flutter membership tests: 85 passed, including a real Supabase client with synthetic HTTP transport, payment selection, boundary checks and visual comparisons.
- Flutter Home tests: 114 passed, including paid-tier projection, guest reads and recovery.
- Localization tests: 8 passed after removing obsolete membership/confirmation copy.
- Web/API suites: 209 tests passed. Additional club-scope and updated member-portal lifecycle checks also passed.
- TypeScript check and focused ESLint with zero warnings: passed.
- Isolated PostgreSQL contract: passed using the actual membership and enforcement migrations, actual Predict balance mutation, and synthetic dependency fixtures. Covers fixed-scale monetary prices, authoritative dialer instructions, club mismatch rejection, zero-price refusal, column and function ACL revocation, route-country preservation, retired configuration rejection, matched activation, purchased-tier preservation through credit/debit, and idempotent renewal.
- Revised product source guard: passed across 704 runtime files and the four supported app shells; wired into CI.
- The changed membership loading-state image was regenerated, visually checked, and then passed without update mode. Its manifest hash was updated. Evidence privacy scan: passed.
- Repository-wide golden manifest validation currently stops at `packages/features/feat_home/test/goldens/home_state_large_text_dark_320x720.png`. It was already modified at the start of this enforcement pass. Its manifest was not normalized as part of this change.
- The regenerated interactive map was inspected in the browser. The 12-diagram inventory contains no free-tier membership branch; the source inventory now contains 30 references.

Earlier checks for the Predict cleanup and reconciliation remain recorded in the local work logs: 22 focused Predict tests, 41 payment-intent/reconciliation tests and the isolated retirement database contract passed.

## Verification limits

The checkout contains substantial pre-existing and concurrent work. The focused tests establish the named local changes, not full-system or release acceptance. A full isolated Supabase replay was attempted but Docker timed out while creating the disposable container, and also timed out during cleanup. The successful native PostgreSQL harness uses a minimal fixture schema and does not replace that full replay.

No production migration, deployment, hosted CI run or real-device MoMo transaction was performed. Apply the forward migrations before releasing clients that call `prepare_membership_payment_for_club`. Live matching also requires the club's configured prices, receiver account, country/provider route and working SMS ingestion. Historical SQL and financial records remain for safe upgrades and audit; active routes and application APIs are removed or non-executable.
