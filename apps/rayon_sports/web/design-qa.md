# Gikundiro revamp design QA

## Scope

- Canonical implementation: `/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/web`
- Selected visual direction: The Blue Wall reference recovered from the owner task
- Reference capture: `/Users/jeanbosco/Documents/Codex/2026-08-21/check-this-mac-mini-and-connected/artifacts/shared-gikundiro-reference/rayon-home-desktop-qa.png`
- Final homepage capture: `/Users/jeanbosco/Documents/Codex/2026-08-21/check-this-mac-mini-and-connected/artifacts/gikundiro-audit-2026-08-21/06-blue-wall-home-implementation.png`
- Normalized side-by-side comparison: `/Users/jeanbosco/Documents/Codex/2026-08-21/check-this-mac-mini-and-connected/artifacts/gikundiro-audit-2026-08-21/07-blue-wall-reference-comparison.png`
- Final membership captures: `/Users/jeanbosco/Documents/Codex/2026-08-21/check-this-mac-mini-and-connected/artifacts/gikundiro-audit-2026-08-21/08-membership-hero-final.png` and `/Users/jeanbosco/Documents/Codex/2026-08-21/check-this-mac-mini-and-connected/artifacts/gikundiro-audit-2026-08-21/09-membership-portal-final.png`

## Baseline findings

| Priority | Finding | Resolution |
| --- | --- | --- |
| P0 | Mobile menu trigger had no working open action. | Wired the persistent accessible drawer, route-change close, Escape close, focus trap, scrim, and reduced-motion behavior. |
| P0 | Membership stopped at a public catalog and did not provide the requested owned journey. | Added WhatsApp OTP, member activation, private six-digit code, contribution dashboard, official MoMo dialer handoff, pending state, refresh, and confirmed history. |
| P1 | Homepage first viewport was an oversized empty blue surface with weak hierarchy and zero useful content. | Rebuilt the first viewport around the selected Blue Wall matchday direction with real club-hosted media, score strip, hierarchy, CTAs, and resilient feature modules. |
| P1 | Navigation collapsed when live feature configuration was unavailable. | Added a safe, complete primary-route fallback for desktop and mobile. |
| P1 | Headlines wrapped into cramped, unintended fragments on desktop and mobile. | Added a condensed matchday typeface, explicit two-line championship lockup, bounded membership lockup, and responsive sizing. |
| P1 | Loading and service failures visually dominated or erased the experience. | Preserved a complete static brand surface and truthful recovery state while keeping transactional state fail-closed. |
| P1 | Contribution creation could be retried into duplicate pending rows. | Added per-member transaction locking, 15-minute pending-intent reuse, and hourly abuse bounds in the database RPC. |
| P2 | Motion was minimal and generic. | Added staged headline reveal, cinematic hero drift, image hover depth, existing drawer motion, and complete reduced-motion overrides. |
| P2 | Membership language communicated catalog comparison rather than belonging. | Changed the hero to “Own the belonging” and made WhatsApp access the primary owned journey. |

## Visual comparison

- Browser: the user-selected Chrome session
- Canonical browser viewport: 1823 × 788 CSS pixels at DPR 1
- Reference capture: 1031 × 708 pixels
- Comparison method: the canonical 1210 × 788 content frame and reference were independently scaled to fit equal 1130 × 915 review frames without stretching or cropping the reference.
- States reviewed: homepage recovery state, membership recovery state, signed-out WhatsApp form, invalid phone feedback, persistent navigation fallback.
- P0 remaining: none
- P1 remaining: none in local design or interaction scope
- P2 remaining: live club photography can replace the approved platform-hosted video frames when the club supplies an owned high-resolution campaign library.

## Verification

- ESLint: passed with zero warnings
- TypeScript: passed after Next route type generation
- Targeted component tests: 31 passed across home, membership, member portal, and navigation
- Next.js production build: passed; 35 static pages generated
- Browser DOM checks: fallback routes present, championship lockup present, membership lockup present, WhatsApp form present, external-confirmation boundary present
- Browser interaction check: invalid Rwanda WhatsApp number is rejected before any OTP request
- Mobile navigation interaction: component test confirms trigger state, dialog state, and fallback links
- Accessibility: semantic headings, status/alert regions, labelled inputs, focus handling, keyboard escape/trap, reduced-motion handling, and no browser-side payment confirmation
- Focused security diff scan: complete with zero reportable findings. Two defense-in-depth candidates were still remediated in source: contribution intents are bound to the trusted requesting club, and membership creation/reactivation now requires an explicit user activation step.

## External launch gates

- The connected Supabase project currently reports `exceed_storage_size_quota`; live catalog data, WhatsApp OTP, member activation, and contribution reconciliation cannot be proved until the service is restored.
- Local Supabase migration verification is additionally stopped by the already-committed hook-secret format in `supabase/config.toml`; no secret was changed or exposed during this work.
- The new migration is implemented but not applied to production.
- The canonical Cloudflare deployment was not changed. Local validation is not production activation evidence.
- The security scan sealed the original working-tree snapshot; the two hardening edits above were made afterward and were rechecked with lint, typecheck, targeted tests, and a production build.

Final result: passed
