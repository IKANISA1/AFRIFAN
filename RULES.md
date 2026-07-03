# **AFRICLUB PLATFORM — RULES.md**

## **Agent & Developer Guardrails · Mandatory Compliance Document**

**Applies to:** Claude Code · Codex · Antigravity · Cursor · GitHub Copilot · all AI coding agents and human contributors  
 **Authority:** IKANISA Ltd. — sole owner and approver is **the repository owner**  
 **Last updated:** March 2026  
 **Enforcement:** These rules are not suggestions. Violations require rollback. Any agent that cannot confirm understanding of these rules must stop and request clarification before proceeding.

---

## **⚠️ MANDATORY PRE-TASK PROTOCOL**

Before executing **any** task — no matter how small — every agent must complete the following steps in order:

1. **Read this file in full.** Do not assume you remember it from a previous session.  
2. **Do a full-stack repo review.** Read the directory tree, key config files, `DESIGN.md`, and the files listed in §4 before touching any user-facing surface.
4. **State your plan** before writing a single line of code. Summarise what you will change, which files are affected, and what you will NOT touch.  
5. **Confirm there are no locked files in your change set** (see §2 for the lock list).  
6. **Ask before acting on any ambiguity.** A wrong assumption costs more than a 30-second clarification.

---

## **SECTION 1 — APPROVAL & OWNERSHIP RULES**

### **1.1 Single owner before any agent or developer may proceed**

No exceptions, no "best guess" implementations, no "I'll do it and mention it later."

**Items requiring owner approval before any work begins:**

| \# | Protected Item | Why It's Protected |
| ----- | ----- | ----- |
| A | `home_screen.dart` and all files it imports | Home screen UI is finalized — see §2.1 |
| B | Shared runtime theme implementation files | Changes cascade to all club flavors |
| C | Any new package addition to `pubspec.yaml` | Every dependency is a supply-chain risk |
| D | Any change to `supabase/migrations/` | Migrations run against all 50+ clubs simultaneously |
| E | Any change to RLS policies in Supabase | Incorrect RLS \= data leak across clubs |
| F | Any change to the `clubs` table schema | Master tenant registry — breaking change |
| G | Generating, downloading, or embedding repo-owned visual assets | See §2.5 |
| H | Changes to CI/CD workflows in `.github/workflows/` | Build pipeline failure affects all clubs |
| I | Adding, removing, or renaming a Flutter flavor | Affects published app store listings |
| J | Any change to the anonymous auth flow | Core privacy contract with users |
| K | Modifying `melos.yaml` workspace structure | Monorepo-wide impact |

### **1.2 How to Request Approval**

Do not implement a workaround while waiting. Pause, create a clearly labelled GitHub Issue titled `[APPROVAL REQUIRED] — <description>`, and wait. The owner will respond with written approval or rejection.

---

## **SECTION 2 — LOCKED RULES (Zero Tolerance)**

These rules have **zero tolerance**. Violating them requires an immediate full rollback of all changes in the offending session.

### **2.1 LOCKED - Supporter Home Contract**

The supporter home surface is protected. Product behavior, route ownership, and
user-facing interface decisions for that surface must follow `DESIGN.md` and
the active feature contracts. This file must not define its visual layout,
component recipes, icon choices, or color rules.

### **2.2 🔒 LOCKED — MOMO Number is NOT Collected During Onboarding**

The MOMO number input **must not appear** in the onboarding flow (screens 1.1 through 1.4).

* Profile Setup screen (1.5) **is removed from onboarding** — it lives in Settings → Account → MOMO Number  
* Anonymous sign-in completes onboarding. The user lands on the Home screen immediately after  
* A non-intrusive banner or nudge may appear on the Home screen after first login: *"Link your MOMO to unlock features"* — this requires owner approval before implementation  
* **Never** gate any feature with a hard MOMO-required wall on first launch

**Why:** Users must experience the app before being asked for sensitive information. Asking for MOMO on first launch causes drop-off and erodes trust.

### **2.3 LOCKED - Empty And Loading State Contract**

Empty, loading, and unavailable data behavior is governed by `DESIGN.md` and
feature-specific product contracts. This file must not define a second visual
empty-state pattern or component recipe.

### **2.4 🔒 LOCKED — No Hardcoded Content**

**Nothing visible to the user may be hardcoded in Dart source code.**

This includes but is not limited to:

* Club names, colors, taglines, mottos  
* Match schedules, scores, player names  
* Promotional text, banner copy, news headlines  
* Membership tier perks descriptions  
* Challenge names, FET values, badge names  
* MOMO numbers (club or personal)  
* Contribution group descriptions

All such content must be sourced from Supabase, a ClubConfig value, or a dart-define compile-time constant (for club identity only). If content is not in the database, the section must follow rule §2.3 (not render).

### **2.5 LOCKED - No Repo-Stored Visual Assets**

Repo-owned visual assets are forbidden unless the repository owner explicitly
approves an exception. Product media from live services may still be rendered
as content when the relevant feature contract allows it. `DESIGN.md` remains
the only authority for visual treatment.

---

## **SECTION 3 — REPO HYGIENE RULES**

### **3.1 Clean Repo Policy**

**The repository must never accumulate dead code, deprecated files, or unused assets.**

When a file, class, widget, function, screen, or asset is replaced or deprecated:

* **Delete** the old file in the same PR/commit that introduces the replacement  
* **Remove** all imports referencing the deleted file  
* **Remove** the asset entry from `pubspec.yaml` if an asset file is deleted  
* **Search** for all usages (`grep -r "OldClassName"`) and update or remove every one  
* **Do not** leave `// TODO: remove this later` comments in production code — act now or create a GitHub Issue

### **3.2 No Commented-Out Code**

Never commit commented-out code blocks. If code is removed, it is removed. Git history preserves it. The only acceptable inline comments are:

* `// TODO(owner): [description] — [GitHub Issue #]` for genuinely pending owner decisions  
* `// NOTE: [brief explanation]` for non-obvious logic that requires explanation  
* `// FIXME: [description] — [GitHub Issue #]` for known bugs that are tracked

### **3.3 No Duplicate Logic**

Before creating a new utility function, widget, provider, or service:

1. Search the entire repo for existing implementations  
2. If one exists, extend it — do not create a parallel version  
3. If a shared widget needs a slight variant, use parameters — do not copy-paste the widget

### **3.4 Dart Analysis Must Stay Green**

Before submitting any change:

* Run `flutter analyze` — zero warnings, zero errors  
* Run `dart format .` — all files formatted  
* Run `melos analyze` — all packages clean

Never suppress analyzer warnings with `// ignore:` unless you explain the suppression in a comment and it is a known false positive. Never use `// ignore_for_file:`.

### **3.5 No Orphaned Packages**

After any refactor that moves or removes features:

* Run `melos exec -- flutter pub get` across all packages  
* Verify no package has an import it no longer needs  
* Remove any `packages/features/feat_*` package that is no longer referenced by any app

---

## **SECTION 4 - DESIGN AUTHORITY LOCK**

Before touching any user-facing Flutter, web, admin, venue, or native TV
surface, read `DESIGN.md` first. It is the sole design authority for this
repository.

This file may only enforce that authority. It must not define visual rules,
screen inventories, screenshot matrices, product briefs, token values,
component recipes, motion values, typography sizes, icon choices, or alternate
visual direction.

Architecture docs, runbooks, tests, runtime token classes, generated CSS, and
component source files may implement or verify `DESIGN.md`, but they must not
become a second design contract.

---

## **SECTION 5 — ARCHITECTURE & CODE RULES**

### **5.1 State Management — Riverpod Only**

This project uses **Riverpod 3.x exclusively**.

* **Never** introduce `Provider` (package), `GetX`, `BLoC`, `setState` (for shared state), or `InheritedWidget` patterns  
* All async data must use `AsyncNotifierProvider` or `StreamProvider`  
* All local UI state may use `NotifierProvider` or `StateProvider` for simple cases  
* Never call `ref.read()` inside `build()` — use `ref.watch()` for reactive state

### **5.2 Navigation — GoRouter Only**

* **Never** use `Navigator.push()` or `Navigator.pop()` directly in feature code  
* All navigation goes through GoRouter named routes defined in `core_router`  
* Deep links must be registered in `core_router` — never handle them ad hoc in a screen

### **5.3 Supabase — Never Bypass RLS**

* **Never** use the Supabase `service_role` key in any Flutter client code  
* **Never** use `.from('table').select()` without trusting RLS to filter by `club_id`  
* **Never** add `eq('club_id', someValue)` manually in Flutter — RLS handles this server-side  
* **Never** store raw MOMO phone numbers in any application table — use encrypted fields only
* **Never** expose LiveScore credentials, private feed URLs, service-role keys, or contract details in Flutter or browser clients

### **5.4 Feature Flags Must Be Respected**

Every optional feature must check `ClubConfig.instance.features['feature_key']` before rendering:

```
// ✅ CORRECT
if (ClubConfig.instance.features['fan_clubs'] == true)
  FanClubsModule()

// ❌ FORBIDDEN — feature rendered for clubs that haven't enabled it
FanClubsModule() // unconditional
```

### **5.5 No Business Logic in Widgets**

Widgets display data. They do not fetch it, transform it, or make decisions about it.

* All data fetching → Riverpod providers  
* All business logic → Repository or UseCase classes  
* All error handling → provider layer, never in `build()`  
* Widgets call `ref.watch()` and `ref.read()` — nothing else

### **5.6 Null Safety — No Forced Unwrapping**

* Never use the `!` null assertion operator on values that could realistically be null  
* Use `?.` and `??` with meaningful fallbacks  
* Supabase responses must always be null-checked before use

### **5.7 Async — No Unhandled Futures**

* Never call an async function and discard the future with `// ignore`  
* All `Future<void>` calls must be `await`\-ed or wrapped in `unawaited()` with explicit intent  
* Never use `.then()` chains — use `async/await` consistently

### **5.8 Package Additions**

Before adding any new pub.dev package:

1. Search the existing codebase — does an already-installed package solve this?  
2. Check the package's pub score, null safety, and last publish date  
3. Create a GitHub Issue tagged `[NEW PACKAGE REQUEST]` with justification  
4. Wait for owner approval (§1.1 Item C)  
5. Never add a package to `pubspec.yaml` speculatively "in case it's needed"

---

## **SECTION 6 — SUPABASE & BACKEND RULES**

### **6.1 Every New Table Requires**

When creating a new Supabase table migration:

* \[ \] `club_id TEXT NOT NULL REFERENCES clubs(id)` column (unless it is a global reference table)  
* \[ \] `CREATE INDEX idx_{table}_club_id ON {table}(club_id);`  
* \[ \] RLS enabled: `ALTER TABLE {table} ENABLE ROW LEVEL SECURITY;`  
* \[ \] All four RLS policies (SELECT, INSERT, UPDATE, DELETE) using `auth.club_id()`  
* \[ \] Created at timestamp: `created_at TIMESTAMPTZ DEFAULT now()`

### **6.2 Migrations Are Permanent**

* Never `DROP TABLE` or `DROP COLUMN` in a migration without explicit owner approval  
* Never rename a column in a migration — add the new column, migrate data, deprecate the old one across releases  
* Every migration file must have a descriptive name: `YYYYMMDDHHMMSS_description_of_change.sql`  
* Test every migration against the staging Supabase project before pushing to production

### **6.3 Edge Functions**

* Every Edge Function must validate that the incoming `club_id` matches the caller's JWT claim  
* Never trust `club_id` from the request body — always verify against `auth.jwt() ->> 'club_id'`  
* All Edge Functions must have error handling that returns structured JSON error responses  
* The Gemini API key must never appear in any Flutter client code or dart-define file

### **6.4 Realtime Channel Naming**

All Realtime channel subscriptions must follow the naming convention:

```
{club_id}:{feature}:{resource_id}
```

Example: `rayon_sports_rw:ledger:group-uuid-123`

Never subscribe to a channel without the `club_id` prefix — this is what prevents cross-club data leakage in Realtime.

### **6.5 Venue, TV, And FET Rules**

* Venue-owned records must include both `club_id` and `venue_id`
* Venue check-in must use rotating QR/TV codes first; foreground geolocation is optional verification only
* Venue ordering is drinks-only top-10 MVP unless the owner approves a wider POS scope
* TV surfaces are read-only and must never show personal data, wallet balances, check-in identity, or order queues
* FET is a closed-loop monetary-equivalent reward ledger until legal/payment review approves otherwise
* FET copy must never imply cash-out, odds, betting, stake, deposit, payout, or open-loop stored value
* AI-generated drafts must never auto-publish

---

## **SECTION 7 — MONOREPO & MULTI-CLUB RULES**

### **7.1 Never Edit Core Packages for a Single Club's Benefit**

If a change in `packages/core/` or `packages/features/` is needed only for one club:

* It must be implemented via feature flags in `ClubConfig` (§5.4)  
* If it truly cannot be generalized, it belongs in `packages/clubs/club_{slug}/` only  
* Never add `if (clubId == 'rayon_sports_rw')` conditionals anywhere outside of `packages/clubs/`

### **7.2 New Feature \= New Package**

If a substantial new feature (\>3 screens) is added:

* It must live in a new `packages/features/feat_{name}/` package  
* It must export a `FeatureModule` with routes and providers  
* It must be gated by a feature flag in `ClubConfig`  
* It must follow the package interface defined in `packages/features/README.md`

### **7.3 dart-define Values Are Read-Only at Runtime**

Values injected via `dart-define-from-file` at compile time are constants. They must:

* Never be overridden at runtime  
* Never be fetched from an API and then overridden locally  
* Always be accessed via `ClubConfig.instance` — never via `String.fromEnvironment()` directly in feature code

### **7.4 The `clubs` Table Is the Source of Truth**

If there is ever a conflict between what `ClubConfig` says and what the `clubs` Supabase table says for a property that can be updated post-launch (e.g., feature flags, CMS content), the **database value wins**. ClubConfig is compile-time only; dynamic runtime values come from the database.

---

## **SECTION 8 — SECURITY RULES**

### **8.1 Secrets**

* The Supabase `service_role` key must **never** appear in any client-side file  
* No API keys may be committed to the repository in any file — use GitHub Secrets for CI/CD  
* The Supabase `anon` key in `dart-define` JSON files is acceptable (it is designed to be public)  
* Face embedding vectors must be stored encrypted in Supabase Storage — never in plaintext columns

### **8.2 User Privacy**

* Real names must never be collected, stored, or displayed  
* Phone numbers (MOMO) must be stored encrypted and only displayed masked (`07XX ***XXX`)  
* The 6-digit numeric alias is the only public-facing identity token — never expose `auth.uid()` in the UI  
* SMS content must never be stored in full — only the parsed structured fields from Gemini

### **8.3 Input Validation**

* All user text inputs must be validated and sanitised before sending to Supabase  
* MOMO number inputs must be validated against a country-specific regex from `ClubConfig`  
* Never pass raw user input directly into a Supabase `.eq()` or `.filter()` call without validation

### **8.4 Dependency Security**

* Run `flutter pub outdated` monthly and update packages with known CVEs immediately  
* Never use a package that has been flagged on pub.dev for security issues  
* Review the permissions requested by any new package before approval (§1.1 Item C)

---

## **SECTION 9 — TESTING RULES**

### **9.1 Tests Are Not Optional**

Every new feature package must include:

* Unit tests for all repository methods  
* Unit tests for all Riverpod providers  
* Widget tests for every screen's key UI states (loading, data, empty, error)

### **9.2 The Empty State Must Be Tested**

For every section governed by rule §2.3:

* A widget test must verify that when the data list is empty, `SizedBox.shrink()` is returned and no visible widget is rendered  
* A widget test must verify that when data is present, the section renders correctly

### **9.3 Test Naming Convention**

```
// Format: test('description of what it does', () { ... })
test('returns SizedBox.shrink when news list is empty', () { ... })
test('renders NewsFeedSection when news list has items', () { ... })
test('hides active Groups zone when user has no groups', () { ... })
```

### **9.4 CI Must Stay Green**

* Never merge a PR that fails `melos test_changed`  
* Never merge a PR that fails `flutter analyze`  
* Never merge a PR with a test file that has `// TODO: add tests` — write them now

---

## **SECTION 10 — PROHIBITED PATTERNS (COMPLETE ANTI-PATTERN LIST)**

The following are explicitly forbidden. Any agent generating these patterns must self-correct before submitting.

### **Interface Anti-Patterns**

`DESIGN.md` and the shared runtime implementation define interface rules.
Feature code must not introduce hardcoded visual values, static brand asset
paths, duplicate component recipes, or alternate interface conventions.

### **State Management Anti-Patterns**

```
❌ setState() for anything other than widget-local ephemeral state
❌ Provider (package), GetX, BLoC, or InheritedWidget
❌ ref.read() inside build()
❌ Storing Supabase responses directly as widget state
❌ FutureBuilder with a Future created inside build()
❌ Calling an API directly from initState()
❌ Global variables holding application state
```

### **Architecture Anti-Patterns**

```
❌ Navigator.push() / Navigator.pop() in feature code
❌ BuildContext used outside the widget tree (passed to async methods)
❌ Business logic (if/else, data transformation) inside build()
❌ Repository classes directly instantiated in widgets (use DI)
❌ Supabase.instance.client accessed directly in feature code (use injected client)
❌ String.fromEnvironment() called directly in feature code (use ClubConfig)
❌ if (clubId == 'specific_club') conditionals in shared packages
```

### **Supabase / Backend Anti-Patterns**

```
❌ service_role key in any Flutter file
❌ .select() queries without trusting RLS (adding manual club_id filter)
❌ Storing MOMO numbers in plaintext columns
❌ Realtime channels without club_id prefix
❌ Edge Functions that trust club_id from request body without JWT verification
❌ DROP TABLE or DROP COLUMN in a migration without owner approval
❌ Direct Gemini API calls from Flutter client (must go via Edge Function)
```

### **Security Anti-Patterns**

```
❌ Any API key in any Dart file or JSON config file (except Supabase anon key)
❌ User real name collection at any point in the UX
❌ Phone numbers displayed unmasked to any user
❌ auth.uid() displayed in any UI element
❌ Face photos stored on any server (embeddings only)
❌ Raw SMS text stored in any database table
❌ User input passed directly to database queries without validation
```

### **Repo Hygiene Anti-Patterns**

```
❌ Commented-out code blocks committed to the repo
❌ Unused imports left in any file
❌ Old files left alongside replacement files
❌ TODO comments without a GitHub Issue number
❌ Packages added to pubspec.yaml without approval
❌ Duplicate widget implementations for marginally different use cases
❌ print() statements in production code (use a logging service)
❌ debugPrint() in production builds
❌ assert() used for production error handling (use proper null safety)
```

### **Visual Asset Anti-Patterns**

Repo-stored visual assets and static brand media are prohibited by §2.5 unless
the owner records an explicit exception.

---

## **SECTION 11 — COMMIT & PR RULES**

### **11.1 Commit Message Format**

```
type(scope): short description

Types: feat | fix | refactor | style | test | docs | chore | revert
Scope: the package or feature name (e.g. feat_home, core_theme, supabase)

Examples:
feat(feat_contributions): add group statement download as CSV
fix(core_theme): correct Android border regression
refactor(feat_gamification): extract FET progress widget
chore(melos): add build_club_ios script
```

### **11.2 PR Checklist**

Every PR must confirm:

* \[ \] `flutter analyze` passes on all affected packages  
* \[ \] All new code has tests (§9.1)  
* \[ \] No locked files modified without approval issue linked (§1.1)  
* \[ \] No hardcoded content (§2.4)  
* \[ \] No empty state violations (§2.3)  
* \[ \] No repo-stored visual assets added without approval (§2.5)
* \[ \] Dead code from replaced functionality deleted (§3.1)  
* \[ \] `dart format .` run on all changed files

### **11.3 Branch Naming**

```
feature/feat-name-short-description
fix/bug-description
refactor/what-was-refactored
chore/maintenance-task
```

Never commit directly to `main`. All changes go through PRs.

---

## **SECTION 12 — DOCUMENT MAINTENANCE**

This file must be updated whenever:

* A new protected item is identified (add to §1.1)  
* A new anti-pattern is discovered in practice (add to §10)  
* A new architectural decision is made that future agents should know  
* A rule is changed or relaxed by the owner

Updates to this file require the same owner approval as any other critical change (§1.1).

When updating, add an entry to the changelog at the bottom of this file.

---

## **QUICK REFERENCE CARD**

```
ALWAYS:
  ✅ Read this file before starting any task
  ✅ Do a full repo review before writing code
  ✅ Read DESIGN.md before touching UI
  ✅ Use shared runtime implementation governed by DESIGN.md
  ✅ Follow DESIGN.md for empty, loading, and error states
  ✅ Delete old code when replacing it
  ✅ Use Riverpod for all state, GoRouter for all navigation
  ✅ Validate MOMO and text inputs before writing to Supabase
  ✅ Keep dart analyze green at all times


NEVER:
  🚫 Touch home_screen.dart without owner approval
  🚫 Ask for MOMO number during onboarding
  🚫 Define visual rules outside DESIGN.md
  🚫 Hardcode club names, static visual values, or user-facing content
  🚫 Add repo-stored visual assets without approval
  🚫 Add packages without approval
  🚫 Use service_role key in Flutter
  🚫 Expose LiveScore/private feed credentials in clients
  🚫 Put venue staff/admin operations in the supporter app
  🚫 Add browser check-in or public live order queues
  🚫 Use cash-out, odds, stake, payout, or betting copy for FET
  🚫 Store real names or unmasked phone numbers
  🚫 Add club-specific logic to shared packages
  🚫 Leave dead code in the repo
  🚫 Use Brightness.light anywhere
  🚫 Navigate with Navigator.push (use GoRouter)
```

---

## **CHANGELOG**

| Date | Version | Change | Author |
| ----- | ----- | ----- | ----- |
| March 2026 | 1.0.0 | Initial rules document created | IKANISA Ltd. |
| March 2026 | 1.1.0 | Added runtime theme governance and hardcoded-value cleanup rules | IKANISA Ltd. |
| 2026-07-02 | 1.2.0 | Added venue, TV, LiveScore, FET, and no-browser-check-in guardrails for Rayon venue rollout | Codex |

---

*This document is the authoritative source of truth for all AI agent and developer behavior in this repository. When in doubt, stop and ask — do not guess.*
