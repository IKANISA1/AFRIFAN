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
2. **Do a full-stack repo review.** Read the directory tree, key config files, all design documents, and the files* **Signature Textures:** Use `ColorTokens.heroGradient()` for hero backgrounds — transitions from `clubSecondary` to `clubPrimary` at a 135-degree angle. **Never hardcode hex values.**s** listed in §4 before touching any UI file.  
4. **State your plan** before writing a single line of code. Summarise what you will change, which files are affected, and what you will NOT touch.  
5. **Confirm there are no locked files in your change set** (see §2 for the lock list).  
6. **Ask before acting on any ambiguity.** A wrong assumption costs more than a 30-second clarification.

---

## **SECTION 1 — APPROVAL & OWNERSHIP RULES**

### **1.1 Single\* \*\*Interaction:\*\* On press, the icon scales up (1.2x), the \`label-md\` appears below it, and a haptic "pop" is triggered. Use `ColorTokens.navActive` (auto-derived pastel tint of club primary) for the active state icon.ry owner** before any agent or developer may proceed. No exceptions, no "best guess" implementations, no "I'll do it and mention it later."

**Items requiring owner approval before any work begins:**

| \# | Protected Item | Why It's Protected |
| ----- | ----- | ----- |
| A | `home_screen.dart` and all files it imports | Home screen UI is finalized — see §2.1 |
| B | `lib/core/theme/` — all design token files | Token changes cascade to all 50+ club flavors |
| C | Any new package addition to `pubspec.yaml` | Every dependency is a supply-chain risk |
| D | Any change to `supabase/migrations/` | Migrations run against all 50+ clubs simultaneously |
| E | Any change to RLS policies in Supabase | Incorrect RLS \= data leak across clubs |
| F | Any change to the `clubs` table schema | Master tenant registry — breaking change |
| G | Generating, downloading, or embedding any image or image asset | See §2.8 |
| H | Changes to CI/CD workflows in `.github/workflows/` | Build pipeline failure affects all clubs |
| I | Adding, removing, or renaming a Flutter flavor | Affects published app store listings |
| J | Any change to the anonymous auth flow | Core privacy contract with users |
| K | Modifying `melos.yaml` workspace structure | Monorepo-wide impact |

### **1.2 How to Request Approval**

Do not implement a workaround while waiting. Pause, create a clearly labelled GitHub Issue titled `[APPROVAL REQUIRED] — <description>`, and wait. The owner will respond with written approval or rejection.

---

## **SECTION 2 — LOCKED RULES (Zero Tolerance)**

These rules have **zero tolerance**. Violating them requires an immediate full rollback of all changes in the offending session.

### **2.1 🔒 LOCKED — Home Screen UI**

**The Home Screen UI layout, zones, components, and visual design are permanently locked.**

* **Never modify** `lib/features/feat_home/presentation/screens/home_screen.dart`  
* **Never modify** any widget imported exclusively by the home screen  
* **Never reorder, remove, or add** any of the 6 home screen zones  
* **Never change** the Quick Actions rail — its order, icons, labels, or destinations are fixed  
* **Never change** the bottom navigation bar — 3 tabs only: Home · BioPay · Settings  
* Bug fixes that do not alter visual output (e.g. fixing a null pointer crash) require owner notification but not prior approval

**Why:** The palette is rooted in the deep shadows of a midnight stadium, punctuated by high-velocity **dynamic club-specific** accents injected at startup via `ColorTokens.init(ClubConfig.colors)`. Any change that fans notice breaks brand trust.

### **2.2 🔒 LOCKED — MOMO Number is NOT Collected During Onboarding**

The MOMO number input **must not appear** in the onboarding flow (screens 1.1 through 1.4).

* Profile Setup screen (1.5) **is removed from onboarding** — it lives in Settings → Account → MOMO Number  
* Anonymous sign-in completes onboarding. The user lands on the Home screen immediately after  
* A non-intrusive banner or nudge may appear on the Home screen after first login: *"Link your MOMO to unlock features"* — this requires owner approval before implementation  
* **Never** gate any feature with a hard MOMO-required wall on first launch

**Why:** Users must experience the app before being asked for sensitive information. Asking for MOMO on first launch causes drop-off and erodes trust.

### **2.3 🔒 LOCKED — Dynamic UI: No Empty Section Rendering**

**A UI section must not be rendered if its data source is empty or unavailable.**

This is a **critical** UI and performance rule. It\* \*\*Visuals:\*\* Must float over a dynamic `ColorTokens.heroGradient()` background to maximize the blur effect.ire app — not just the home screen.

**The rule:**

```
if (data.isEmpty || data == null) {
  // Return SizedBox.shrink() — render nothing
  // NEVER return an empty card, placeholder card, "No items yet" card,
  // "Coming soon" card, or any visible container for that section
}
```

**Sections this applies to (non-exhaustive):**

* Home screen Zone 1 (Live/Next Match) — hide entirely if no upcoming or live match exists  
* Home screen Zone 3 (Admin Banner Carousel) — hide if no active banners in CMS  
* Home screen Zone 4 (My Active Circles) — hide if user has no active groups  
* Home screen Zone 5 (Gamification Teaser) — hide if user XP is 0 and no events recorded  
* Home screen Zone 6 (Club News Feed) — hide if no published news articles  
* Leaderboard — hide "Top Supporters" section if fewer than 3 ranked users exist  
* Any list screen — never show an empty-state card that mimics a populated card  
* Shop — hide a category section if that category has zero products  
* Fan Clubs — hide "Featured Clubs" if no clubs are marked as featured

**Correct implementation pattern:**

```
// In Riverpod provider or build method:
final items = ref.watch(newsProvider);
return items.when(
  data: (list) => list.isEmpty
      ? const SizedBox.shrink()   // ✅ CORRECT — nothing rendered
      : NewsFeedSection(items: list),
  loading: () => const SizedBox.shrink(), // skeleton shown at parent level
  error: (_, __) => const SizedBox.shrink(),
);
```

**Forbidden patterns:**

```
// ❌ FORBIDDEN — empty card visible
if (items.isEmpty) return EmptyStateCard(message: 'No news yet');

// ❌ FORBIDDEN — placeholder section
if (items.isEmpty) return ComingSoonSection();

// ❌ FORBIDDEN — section header with empty body
Column(children: [
  SectionHeader('Latest News'),
  if (items.isEmpty) SizedBox(height: 8), // still renders header
])
```

**Why:** Empty UI sections are visual noise that breaks the premium football-app feel. They make the app look unfinished and unpolished. The design mandate is: if there is nothing to show, there is nothing to show.

### **2.4 🔒 LOCKED — No Hardcoded Content**

**Nothing visible to the user may be hardcoded in Dart source code.**

This includes but is not limited to:

* Club names, colors, taglines, mottos  
* Match schedules, scores, player names  
* Promotional text, banner copy, news headlines  
* Membership tier perks descriptions  
* Challenge names, XP values, badge names  
* MOMO numbers (club or personal)  
* Contribution group descriptions

All such content must be sourced from Supabase, a ClubConfig value, or a dart-define compile-time constant (for club identity only). If content is not in the database, the section must follow rule §2.3 (not render).

### **2.5 🔒 LOCKED — No Image Generation Without Authorisation**

**AI agents must never generate, download, embed, or reference any image file without explicit written approval from the owner.**

This includes:

* Do not use placeholder image APIs (picsum.photos, via.placeholder.com, lorempixel.com, etc.)  
* Do not create `.png`, `.jpg`, `.webp`, `.svg` image files  
* Do not embed base64-encoded images in source code  
* Do not add `Image.network()` calls with hardcoded URLs  
* Do not add new entries to `pubspec.yaml` under `flutter: assets:` for images

**When an image is needed:** Create a task comment `// TODO(owner): image asset needed here — [description]` and stop. Do not attempt to substitute.

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

## **SECTION 4 — DESIGN & UI/UX RULES**

### **4.1 Design Documents Are Law**

Before touching **any** file in `lib/features/` or `lib/core/theme/`, read all of the following in order:

1. `docs/design.md` — ROUGEBLACK design language specification  
2. `docs/blueprint.md` — full app architecture and screen-by-screen specification  
3. `docs/design_mandate.md` — non-negotiable visual rules  
4. `docs/screen_inventory.md` — complete screen list with Stitch prompts  
5. The relevant feature's own `README.md` if it exists

**If any of these files do not exist yet, stop and alert the owner — do not proceed.**

### **4.2 Adaptive Theming (Light, Dark, System)**

This app supports **System, Light, and Dark mode**. Themes dynamically respond to user system preferences while maintaining the club's "Stadium Pulse" energetic feel across all variants.

* **Primary Action:** `ColorTokens.clubPrimary` background (dynamic per club). color  
* Never use `Colors.black` as a text color — use `AppColors.textPrimary` (`#F7F9FC`)  
* All surfaces must be deep navy variants (`#0A0F2C`, `#0D1333`, `#1A1F3A`)  

### **4.3 Design Token System — Never Bypass It**

All colors, typography, spacing, and border radii must use tokens from `core_theme`:

```dart
// ✅ CORRECT — dynamic club colors
Container(color: ColorTokens.clubPrimary)    // Dynamic per club via ColorTokens.init()
Text('Hello', style: TypographyTokens.headlineLarge())

// ✅ CORRECT — platform constants (ok as const)
Container(color: ColorTokens.background)     // #0C112E — same for all clubs

// ❌ FORBIDDEN — hardcoded values
Container(color: Color(0xFFC8102E))          // bypasses token system
Container(color: Color(0xFF0038A8))          // hardcoded Rayon blue — breaks other clubs
Text('Hello', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold))
```

**Why:** White-label platform — club colors are injected via `ClubConfig.colors` and initialized in `ColorTokens.init()` at bootstrap. A hardcoded color breaks every club except the one you were looking at.

### **4.3.1 Dynamic Color Architecture**

| Token | Resolves to | Fallback if white |
|-------|-------------|--------------------|
| `ColorTokens.clubPrimary` | `ClubConfig.colors.primary` | `#0038A8` |
| `ColorTokens.clubSecondary` | `ClubConfig.colors.secondary` | `#001F5C` |
| `ColorTokens.clubAccent` | `ClubConfig.colors.accent` | `#D4A017` |
| `ColorTokens.navActive` | HSL-derived pastel tint | Auto-computed |
| `ColorTokens.heroGradient()` | secondary → primary | Auto-computed |

**White-drop rule:** If any club color has luminance > 0.9 (white/near-white), it is automatically replaced with the design system default. White breaks the dark-mode UI.

**Legacy aliases:** `clubRed` → `clubPrimary`, `deepNavy` → `clubSecondary`, `trophyGold` → `clubAccent`.

### **4.4 Minimum Font Sizes**

| Use | Minimum size |
| ----- | ----- |
| Body text | 15sp |
| Interactive labels (buttons, chips) | 14sp |
| Supporting metadata, timestamps | 12sp |
| Fine print, legal | 11sp |

**Never go below 11sp for any visible text under any circumstances.**

### **4.5 No Inline Styling for Club-Specific Values**

Never read a club's primary color via `Theme.of(context).primaryColor` and then hardcode a variation of it. Use `ColorTokens.clubPrimary` / `.clubAccent` / `.clubSecondary` exclusively for club-specific values. These are initialized from `ClubConfig.colors` at bootstrap.

### **4.6 Glassmorphism — Use the Shared Widget**

Never re-implement glass card styling inline. Always use `GlassCard` from `core_theme`:

```
// ✅ CORRECT
GlassCard(blur: 12, glassOpacity: 0.06, child: content)

// ❌ FORBIDDEN — inline reimplementation
ClipRRect(
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
    child: Container(color: Colors.white.withOpacity(0.06), child: content),
  ),
)
```

### **4.7 Animations — Mandatory Standards**

| Animation type | Duration | Curve |
| ----- | ----- | ----- |
| Page transitions | 320ms | `Curves.easeInOutCubic` |
| Card entrances | 400ms staggered | `Curves.easeOutBack` |
| Button press scale | 80ms | `Curves.easeInOut` |
| Bottom sheets | 280ms | `Curves.easeOutCubic` |

Never use durations above 500ms except for looping ambient effects. Always pair visual animations with `HapticFeedback.lightImpact()`.

### **4.8 No Emoji as Icons**

Never use emoji characters as UI icons. Use the approved SVG icon set (`core_theme/icons/`) or Phosphor Icons. Emoji are culturally variable, render differently across Android versions, and are prohibited by the `design_mandate.md`.

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

### **5.4 Feature Flags Must Be Respected**

Every optional feature must check `ClubConfig.instance.features['feature_key']` before rendering:

```
// ✅ CORRECT
if (ClubConfig.instance.features['biopay'] == true)
  BiPayModule()

// ❌ FORBIDDEN — feature rendered for clubs that haven't enabled it
BiPayModule() // unconditional
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
test('hides active circles zone when user has no groups', () { ... })
```

### **9.4 CI Must Stay Green**

* Never merge a PR that fails `melos test_changed`  
* Never merge a PR that fails `flutter analyze`  
* Never merge a PR with a test file that has `// TODO: add tests` — write them now

---

## **SECTION 10 — PROHIBITED PATTERNS (COMPLETE ANTI-PATTERN LIST)**

The following are explicitly forbidden. Any agent generating these patterns must self-correct before submitting.

### **UI Anti-Patterns**

```
❌ Any color hardcoded as Color(0xFF...) outside of ColorTokens
❌ Any font size hardcoded as fontSize: N outside of TypographyTokens
❌ Colors.white as a background or club accent color
❌ Colors.black as text
❌ ThemeMode.light or ThemeMode.system
❌ Brightness.light in any ThemeData
❌ Emoji used as navigation or action icons, or anywhere else
❌ Text in images (always use actual Text widgets for accessibility)
❌ GestureDetector wrapping the entire screen
❌ Nested scrollables without physics: NeverScrollableScrollPhysics()
❌ Image.network() with a hardcoded URL
❌ Empty container/card shown when data is absent (§2.3)
❌ "Coming soon", "No items yet", "Nothing here" placeholder sections
❌ Inline BackdropFilter reimplementing GlassCard
❌ overflow: TextOverflow.clip without a maxLines constraint
❌ Hard-coded club name, color, or crest path in feature packages
❌ Using `const` with dynamic ColorTokens (clubRed, deepNavy, trophyGold, navActive)
```

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

### **Image Anti-Patterns**

```
❌ Any image generated, downloaded, or embedded without owner approval (§2.5)
❌ picsum.photos, lorempixel, via.placeholder.com, or any placeholder image service
❌ Base64-encoded images in source code
❌ New entries in pubspec.yaml flutter.assets for image files without approval
❌ SVG files containing rasterized image data
```

---

## **SECTION 11 — COMMIT & PR RULES**

### **11.1 Commit Message Format**

```
type(scope): short description

Types: feat | fix | refactor | style | test | docs | chore | revert
Scope: the package or feature name (e.g. feat_home, core_theme, supabase)

Examples:
feat(feat_contributions): add group statement download as CSV
fix(core_theme): correct GlassCard border radius on Android 
refactor(feat_gamification): extract XPProgressArc to shared widget
chore(melos): add build_club_ios script
```

### **11.2 PR Checklist**

Every PR must confirm:

* \[ \] `flutter analyze` passes on all affected packages  
* \[ \] All new code has tests (§9.1)  
* \[ \] No locked files modified without approval issue linked (§1.1)  
* \[ \] No hardcoded content (§2.4)  
* \[ \] No empty state violations (§2.3)  
* \[ \] No images added without approval (§2.5)  
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
  ✅ Read design.md, blueprint.md, design_mandate.md before touching UI
  ✅ Use ColorTokens.*, TypographyTokens.*, GlassCard, ClubConfig tokens
  ✅ Hide sections when data is empty (SizedBox.shrink)
  ✅ Delete old code when replacing it
  ✅ Use Riverpod for all state, GoRouter for all navigation
  ✅ Validate MOMO and text inputs before writing to Supabase
  ✅ Keep dart analyze green at all times
✅ Use supabase edge fuctions for image generations each ui that requires images must have respctive supabase edge fuction with gemini nano banane2 for image generation, gemini model: 3.1 pro


NEVER:
  🚫 Touch home_screen.dart without owner approval
  🚫 Ask for MOMO number during onboarding
  🚫 Show empty section cards when data is absent
  🚫 Hardcode club names, colors (hex values), or content
  🚫 Use white (#FFFFFF) as a club accent/primary color (auto-dropped by ColorTokens.init)
  🚫 Generate or embed images without approval
  🚫 Add packages without approval
  🚫 Use service_role key in Flutter
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
| March 2026 | 1.1.0 | Dynamic club color system: ColorTokens.init(), white-drop rule, removed hardcoded #C8102E refs | IKANISA Ltd. |

---

*This document is the authoritative source of truth for all AI agent and developer behavior in this repository. When in doubt, stop and ask — do not guess.*

