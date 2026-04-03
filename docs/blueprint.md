

**AFRICLUB PLATFORM**

**White-Label African Football Super-App**

*─── Multi-Tenant · One Repo · 50+ Club Apps ───*

IKANISA Ltd.  ·  Full-Stack Architecture Blueprint  ·  March 2026

*Confidential & Proprietary — IKANISA Ltd.*

Flutter  ·  Supabase  ·  Melos Monorepo  ·  Flutter Flavors  ·  Multi-Tenant RLS  ·  Gemini AI  ·  MOMO USSD  ·  FCM

# **1\. EXECUTIVE SUMMARY**

AFRICLUB Platform is a white-label, multi-tenant African football fan super-app built on a single Flutter monorepo and one Supabase backend project. Instead of building isolated apps per club, AFRICLUB provides each club with a fully personalised app — unique branding, crest, colors, MOMO codes, and club identity — while sharing 100% of the underlying architecture, codebase, features, and infrastructure.

The platform targets a minimum of 50 African football clubs across 50 countries at launch. Each club becomes an independent Flutter Flavor within one monorepo, and a distinct tenant (club\_id) within one Supabase project. Adding a new club app takes under 4 hours of configuration — no new code, no new backend, no new database.

### **1.1  The Core Problem Being Solved**

| The Old Way (One App Per Club) | The AFRICLUB Way (One Platform, Many Apps) |
| :---- | :---- |
| New Git repository per club | One monorepo — all clubs in one place |
| New Supabase project per club | One Supabase project — club\_id discriminates all data |
| Duplicate code for every feature fix | Fix once → all 50+ clubs get the update instantly |
| Separate CI/CD pipeline per club | One CI/CD pipeline builds all club flavors in parallel |
| Design changes must be replicated manually | Design token system — change one value, all clubs update |
| No cross-club analytics possible | Platform-level analytics across all clubs from one source |
| Months to onboard a new club | Hours to onboard a new club (config-only) |
| 50 projects \= 50× infrastructure cost | 50 clubs \= marginal Supabase row cost only |

### **1.2  Platform Scale Targets**

| Metric | Year 1 | Year 2 | Year 3 |
| :---- | :---- | :---- | :---- |
| Active club apps | 50 | 150 | 300+ |
| Total registered users | 500K | 3M | 10M+ |
| Countries covered | 20 | 40 | 54 (all Africa) |
| MOMO transactions routed/month | 50K | 500K | 5M+ |
| Supabase projects | 1 (primary) \+ 1 (DR) | Same | Same |
| Flutter monorepo packages | \~25 | \~35 | \~45 |
| App store listings | 50 | 150 | 300+ |

# **2\. ARCHITECTURE DECISION RECORD (ADR)**

Three fundamental architecture decisions govern the entire platform. These were evaluated against scale, cost, development velocity, and African market constraints.

## **2.1  ADR-001: Single Supabase Project (Multi-Tenant) vs. One Project Per Club**

| Option | Pros | Cons | Decision |
| :---- | :---- | :---- | :---- |
| One Supabase project per club | Perfect data isolation, easy to delete a club | 50+ projects \= 50× management, no cross-club analytics, costly | REJECTED |
| One shared Supabase project (multi-tenant) | Single source of truth, one migration for all, cross-club analytics, cost-efficient | RLS policies more complex, requires club\_id on every table | CHOSEN |

***★  Decision: Single Supabase project with club\_id as the tenant discriminator on every application table. Row Level Security (RLS) enforces club isolation at the database level. club\_id is stored as a custom JWT claim — it is available in every SQL policy without extra DB lookups.***

## **2.2  ADR-002: Flutter Flavors vs. Separate Flutter Projects**

| Option | Pros | Cons | Decision |
| :---- | :---- | :---- | :---- |
| Separate Flutter project per club | Total isolation, easy to archive | 50× code maintenance, duplicate bug fixes, no shared hot reload | REJECTED |
| Flutter Flavors in one monorepo | One codebase, all clubs compile from same source, flavors inject per-club config at build time | Flavor config overhead at setup, larger monorepo | CHOSEN |

***★  Decision: Flutter Flavors (dart-define-from-file) inject club-specific tokens (colors, crest path, app name, MOMO codes, Supabase anon key) at compile time. Each flavor produces an independent APK/IPA that feels 100% unique to that club.***

## **2.3  ADR-003: Monorepo Tool — Melos**

| Option | Decision |
| :---- | :---- |
| Melos (Invertase) | CHOSEN — industry standard, used by FlutterFire, supports Dart Workspaces, parallel script execution, diff-based CI, automatic versioning |
| Manual workspaces | REJECTED — no orchestration, tedious for 50+ apps |
| Nx / Turborepo | REJECTED — not Dart-native, extra complexity |

# **3\. FLUTTER MONOREPO STRUCTURE (MELOS)**

The monorepo uses a three-tier package structure: apps/ (per-club Flutter apps), packages/core/ (shared business logic & UI), and packages/clubs/ (per-club config packages).

## **3.1  Top-Level Directory Structure**

africlub/                              ← git root├── melos.yaml                         ← Melos workspace config├── pubspec.yaml                       ← Dart workspace root├── analysis\_options.yaml              ← Shared lint rules├── build.yaml                         ← Shared build\_runner config├── .github/│   └── workflows/│       ├── ci.yaml                    ← Run tests on all changed pkgs│       ├── build\_all.yaml             ← Build all flavors│       └── deploy\_club.yaml           ← Deploy single club to store│├── apps/│   ├── rayon\_sports/                  ← Rayon Sports FC (Rwanda)│   ├── gor\_mahia/                     ← Gor Mahia FC (Kenya)│   ├── al\_ahly/                       ← Al Ahly SC (Egypt)│   ├── kaizer\_chiefs/                 ← Kaizer Chiefs (South Africa)│   ├── tp\_mazembe/                    ← TP Mazembe (DR Congo)│   └── \[48+ more club apps\]│├── packages/│   ├── core/│   │   ├── core\_auth/                 ← Supabase auth (anonymous)│   │   ├── core\_network/              ← Supabase client factory│   │   ├── core\_theme/                ← Design token system│   │   ├── core\_router/               ← GoRouter config│   │   ├── core\_di/                   ← GetIt \+ Injectable│   │   └── core\_utils/                ← Formatters, alias, MOMO utils│   ││   ├── features/│   │   ├── feat\_home/                 ← CMS-driven home screen│   │   ├── feat\_membership/           ← Fan tiers & digital cards│   │   ├── feat\_fan\_clubs/            ← Supporter club management│   │   ├── feat\_ticketing/            ← Match tickets \+ seat map│   │   ├── feat\_shop/                 ← Club merchandise│   │   ├── feat\_gamification/         ← XP, badges, leaderboards│   │   ├── feat\_contributions/        ← Contribution circles│   │   ├── feat\_sms\_ledger/           ← MOMO SMS → Gemini parser│   │   ├── feat\_biopay/               ← QR, NFC, Face ID payments│   │   ├── feat\_chat/                 ← Group chat (Realtime)│   │   └── feat\_admin/                ← Admin CMS panel│   ││   └── clubs/│       ├── club\_rayon\_sports/         ← ClubConfig for Rayon Sports│       ├── club\_gor\_mahia/            ← ClubConfig for Gor Mahia│       └── \[one package per club\]│└── tools/    ├── scripts/    │   ├── new\_club.sh                ← Scaffold new club in \< 5 min    │   └── build\_flavor.sh            ← Build one club APK \+ IPA    └── templates/        ├── club\_app\_template/         ← Cookiecutter app template        └── club\_config\_template/      ← Cookiecutter config pkg template

## **3.2  A Single Club App (apps/rayon\_sports/)**

Each club app is thin. It contains only flavor-specific assets and entry points. All business logic lives in shared packages.

apps/rayon\_sports/├── pubspec.yaml               ← depends on packages/clubs/club\_rayon\_sports├── android/│   └── app/│       ├── build.gradle       ← applicationId: rw.ikanisa.rayonsports│       └── src/│           └── main/res/      ← Club-specific launcher icons, splash├── ios/│   ├── Runner.xcodeproj/      ← Bundle ID: rw.ikanisa.rayonsports│   └── Runner/Assets.xcassets/← Club-specific app icons├── assets/│   ├── crest/                 ← rayon\_crest.png (various sizes)│   ├── splash/                ← splash\_background.png│   └── flavors/│       └── rayon\_sports.json  ← dart-define compile-time config└── lib/    ├── main\_production.dart   ← Production entry point    ├── main\_staging.dart      ← Staging entry point    └── bootstrap.dart         ← App bootstrap (injects ClubConfig)

## **3.3  Club Configuration Package (packages/clubs/club\_rayon\_sports/)**

The club config package is the only code that changes per club. It is a pure Dart package with zero Flutter dependencies.

// packages/clubs/club\_rayon\_sports/lib/club\_rayon\_sports.dartclass RayonSportsConfig implements ClubConfig {  @override  String get clubId        \=\> 'rayon\_sports\_rw';      // Supabase tenant ID  @override  String get clubName      \=\> 'Rayon Sports FC';  @override  String get appName       \=\> 'Rayon Sports';  @override  String get country       \=\> 'Rwanda';  @override  String get countryCode   \=\> 'RW';  @override  String get language      \=\> 'rw';                   // Kinyarwanda default  @override  String get momoPrefix    \=\> '\*182\*';                 // MTN Rwanda USSD prefix  @override  String get currency      \=\> 'RWF';  @override  String get currencySymbol=\> 'FRw';  @override  ClubColors get colors    \=\> const ClubColors(    primary:   Color(0xFFC8102E),   // Rayon Red    secondary: Color(0xFF0A0F2C),   // Deep Navy    accent:    Color(0xFFD4A017),   // Trophy Gold    gradient:  \[Color(0xFF8B0000), Color(0xFF0A0F2C)\],  );  @override  String get crestAsset    \=\> 'assets/crest/rayon\_crest.png';  @override  String get supabaseUrl   \=\> const String.fromEnvironment('SUPABASE\_URL');  @override  String get supabaseAnonKey \=\> const String.fromEnvironment('SUPABASE\_ANON\_KEY');  @override  List\<String\> get supportedLanguages \=\> \['rw', 'fr', 'en'\];  @override  bool get hasBiopay       \=\> true;  @override  bool get hasFanClubs     \=\> true;  @override  bool get hasShop         \=\> true;  @override  MomoConfig get momo      \=\> const MomoConfig(    ussdTemplate:  '\*182\*8\*1\*{amount}\*{momo}\#',    senderName:    'MTN MoMo',    countryCode:   'RW',  );}

## **3.4  melos.yaml — Workspace Configuration**

name: africlubrepository: https://github.com/ikanisa/africlubpackages:  \- apps/\*\*  \- packages/core/\*\*  \- packages/features/\*\*  \- packages/clubs/\*\*command:  bootstrap:    hooks:      post: dart run build\_runner build \-dscripts:  \# Run tests only on packages changed since main  test\_changed:    run: melos exec \--diff=origin/main...HEAD \-- flutter test    packageFilters:      dirExists: test  \# Analyze all packages  analyze:    run: melos exec \-- flutter analyze \--fatal-infos  \# Format all packages  format:    run: melos exec \-- dart format .  \# Build a specific club flavor (pass CLUB=rayon\_sports)  build\_club:    run: |      cd apps/$CLUB      flutter build apk \--flavor production        \--dart-define-from-file=assets/flavors/production.json    description: Build APK for a specific club. Usage: CLUB=rayon\_sports melos build\_club  \# Build ALL club APKs in parallel (CI)  build\_all\_android:    run: melos exec \--scope="apps/\*\*" \--concurrency=10 \--      flutter build apk \--flavor production        \--dart-define-from-file=assets/flavors/production.json  \# Scaffold a new club (interactive)  new\_club:    run: bash tools/scripts/new\_club.sh    description: Scaffold a new club app \+ config package from template

## **3.5  Adding a New Club — The new\_club.sh Script**

A new club is added in under 4 hours with the scaffold script. No custom code is written. Only configuration values are provided.

| Step | Action | Time |
| :---- | :---- | :---- |
| 1 | Run: melos new\_club → prompted for club name, country, colors, MOMO prefix | 5 min |
| 2 | Script creates apps/{club\_slug}/ from cookiecutter template | 1 min |
| 3 | Script creates packages/clubs/club\_{slug}/ from config template | 1 min |
| 4 | Developer drops crest PNG, splash PNG, and launcher icons into assets/ | 30 min |
| 5 | Developer fills in ClubConfig values (colors, MOMO, languages, feature flags) | 30 min |
| 6 | Insert club row into Supabase clubs table (one SQL INSERT) | 5 min |
| 7 | CI/CD pipeline triggered → builds Android \+ iOS artifacts | 45 min |
| 8 | Submit to Google Play / App Store under club's developer account | 30 min |
| Total | From zero to submitted club app | \< 4 hours |

# **4\. SUPABASE MULTI-TENANT ARCHITECTURE**

One Supabase project serves all clubs. Every row in every application table belongs to exactly one club, enforced by club\_id. The club\_id is injected into the user's JWT as a custom claim during anonymous sign-in so it is available to RLS policies without extra database lookups.

## **4.1  Tenant Isolation Strategy**

| Layer | Isolation Mechanism | Details |
| :---- | :---- | :---- |
| Authentication | Custom JWT claim: club\_id | Injected at sign-in by Auth Hook. Users from Rayon Sports get club\_id \= 'rayon\_sports\_rw' in their JWT. |
| Database (RLS) | club\_id column on all tables | Every INSERT/SELECT/UPDATE/DELETE is filtered by club\_id \= (auth.jwt() \-\>\> 'club\_id')::text |
| Realtime | Channel prefix: {club\_id}:{channel} | Group chat and live updates are scoped to club-prefixed channels. Cross-club channel subscription is impossible. |
| Storage | Bucket path: /{club\_id}/... | All club media stored under /{club\_id}/ prefix. Storage RLS policies mirror DB RLS. |
| Edge Functions | club\_id in request body | All Edge Function calls include club\_id. Functions validate it against JWT claim before processing. |
| Analytics | club\_id filter on all queries | Admin dashboards default-filter to the authenticated admin's club\_id. |

## **4.2  The clubs Table (Master Tenant Registry)**

clubs (  id              TEXT PK,                  \-- 'rayon\_sports\_rw', 'gor\_mahia\_ke', etc.  name            TEXT NOT NULL,            \-- 'Rayon Sports FC'  country\_code    TEXT NOT NULL,            \-- 'RW', 'KE', 'EG'  currency        TEXT DEFAULT 'USD',       \-- 'RWF', 'KES', 'EGP'  momo\_prefix     TEXT,                     \-- '\*182\*' (MTN Rwanda), '\*150\*' (MTN Kenya)  momo\_sender\_id  TEXT,                     \-- 'MTN MoMo' — SMS sender for parser  primary\_color   TEXT,                     \-- '\#C8102E'  secondary\_color TEXT,                     \-- '\#0A0F2C'  accent\_color    TEXT,                     \-- '\#D4A017'  crest\_url       TEXT,                     \-- CDN URL for club crest  is\_active       BOOL DEFAULT true,  features        JSONB DEFAULT '{}',       \-- { biopay: true, shop: true, fan\_clubs: true }  supabase\_url    TEXT,                     \-- Same for all clubs (one project)  created\_at      TIMESTAMPTZ DEFAULT now())

## **4.3  RLS Policy Pattern — Applied to All Tables**

Every application table follows the same RLS pattern. The club\_id column is indexed on every table for performance.

\-- Step 1: Enable RLS on every tableALTER TABLE contribution\_groups ENABLE ROW LEVEL SECURITY;-- Step 2: Create the reusable club check functionCREATE OR REPLACE FUNCTION auth.club\_id() RETURNS TEXT AS $$  SELECT (auth.jwt() \-\>\> 'club\_id')::TEXT;$$ LANGUAGE sql STABLE;-- Step 3: Standard club isolation policiesCREATE POLICY "club\_select" ON contribution\_groups  FOR SELECT USING (club\_id \= auth.club\_id());CREATE POLICY "club\_insert" ON contribution\_groups  FOR INSERT WITH CHECK (club\_id \= auth.club\_id());CREATE POLICY "club\_update" ON contribution\_groups  FOR UPDATE USING (club\_id \= auth.club\_id())  WITH CHECK (club\_id \= auth.club\_id());CREATE POLICY "club\_delete" ON contribution\_groups  FOR DELETE USING (club\_id \= auth.club\_id());-- Step 4: Create index for RLS performance (critical\!)CREATE INDEX idx\_contribution\_groups\_club\_id  ON contribution\_groups(club\_id);

## **4.4  JWT Auth Hook — Injecting club\_id**

The club\_id is injected into the user's JWT at sign-in using a Supabase Auth Hook (Database Hook). This makes club\_id available in every SQL RLS policy as auth.jwt() \-\>\> 'club\_id' without a database roundtrip.

\-- Supabase Auth Hook: custom\_access\_token-- Triggered every time a JWT is issued (sign-in, token refresh)CREATE OR REPLACE FUNCTION public.custom\_access\_token\_hook(event JSONB)RETURNS JSONB AS $$DECLARE  claims JSONB;  user\_club\_id TEXT;BEGIN  \-- Read club\_id from user metadata (set at anonymous sign-in by Flutter app)  user\_club\_id := event \-\> 'claims' \-\> 'app\_metadata' \-\>\> 'club\_id';    \-- Add club\_id to JWT claims  claims := event \-\> 'claims';  claims := jsonb\_set(claims, '{club\_id}', to\_jsonb(user\_club\_id));    \-- Return the modified claims  RETURN jsonb\_set(event, '{claims}', claims);END;$$ LANGUAGE plpgsql;-- Flutter side: set club\_id in user metadata during anonymous sign-in// await supabase.auth.signInAnonymously(//   data: { 'club\_id': ClubConfig.instance.clubId }// );

## **4.5  Extended Multi-Tenant Schema — All Core Tables**

Every table below has club\_id TEXT NOT NULL as a mandatory column with an index. Only club-specific rows are shown — club-global tables (clubs, badges) are excluded from RLS.

| Table | club\_id? | Additional Tenant Notes |
| :---- | :---- | :---- |
| clubs | IS the tenant table | No club\_id — this IS the club registry |
| users | YES — club\_id | Same phone can register as a fan for multiple clubs (different users table rows) |
| contribution\_groups | YES — club\_id | A group is scoped to exactly one club |
| transactions | YES — club\_id (via group) | Inherited from group; also stored directly for fast queries |
| tickets | YES — club\_id | A Rayon Sports ticket cannot be seen from Gor Mahia's app |
| matches | YES — club\_id | Each club manages its own fixture list |
| gamification\_events | YES — club\_id | XP earned in Rayon Sports does not count on Gor Mahia |
| user\_badges | YES — club\_id | Badges are per-club; a Legend in Rwanda is not a Legend in Kenya |
| group\_messages | YES — club\_id | Chat rooms are fully club-isolated |
| fan\_clubs | YES — club\_id | Supporter clubs belong to one football club |
| shop\_products | YES — club\_id | Each club has its own merchandise catalog |
| app\_ui\_config | YES — club\_id | CMS content is 100% club-specific |
| face\_registrations | YES — club\_id | BioPay Face ID is per-club instance |
| badges (catalog) | NO — global | Badge definitions are platform-wide; user\_badges is per-club |

## **4.6  Supabase Realtime — Multi-Tenant Channel Design**

// Flutter: Subscribe to a club-specific Realtime channel// Channel name format: {club\_id}:{feature}:{resource\_id}// Group ledger updates (contribution circle)final channel \= supabase.channel('rayon\_sports\_rw:ledger:group-uuid-123');channel.onPostgresChanges(  event: PostgresChangeEvent.insert,  schema: 'public',  table: 'transactions',  filter: PostgresChangeFilter(    type: PostgresChangeFilterType.eq,    column: 'group\_id',    value: 'group-uuid-123',  ),  callback: (payload) \=\> \_onNewTransaction(payload),).subscribe();// Live match scorefinal scoreChannel \= supabase.channel('rayon\_sports\_rw:score:match-uuid-456');// Group chatfinal chatChannel \= supabase.channel('rayon\_sports\_rw:chat:group-uuid-789');// RLS on Realtime: channel topic is validated server-side// Users can only subscribe to channels matching their club\_id JWT claim

# **5\. FLUTTER FLAVOR SYSTEM — PER-CLUB BUILD PIPELINE**

Flutter Flavors combined with dart-define-from-file enable each club to be a fully branded, independent app from a single codebase. Each flavor is a build variant, not a different codebase.

## **5.1  How Flavors Work for Club Apps**

| Build Dimension | Value Injected Per Club | Mechanism |
| :---- | :---- | :---- |
| App Name | Rayon Sports / Gor Mahia / Al Ahly | dart-define-from-file JSON |
| Package ID (Android) | rw.ikanisa.rayonsports | build.gradle productFlavor |
| Bundle ID (iOS) | rw.ikanisa.rayonsports | Xcode scheme |
| Primary Color | \#C8102E (red) / \#006B3F (green) / etc. | ClubConfig at bootstrap |
| Club Crest | rayon\_crest.png / gor\_mahia\_crest.png | assets/ in each app folder |
| Launcher Icon | Club-specific icon | Per-app Android/iOS assets |
| Splash Screen | Club stadium photo / gradient | Per-app assets |
| Supabase URL | Same URL — one project | dart-define (same for all) |
| Club ID (tenant) | rayon\_sports\_rw / gor\_mahia\_ke | dart-define-from-file |
| MOMO Prefix | \*182\* / \*150\* / \*126\* | ClubConfig MomoConfig |
| Default Language | rw / sw / ar | ClubConfig |
| Feature Flags | biopay: true/false, shop: true | ClubConfig JSONB |

## **5.2  dart-define-from-file JSON (per club)**

// apps/rayon\_sports/assets/flavors/production.json{  "CLUB\_ID":          "rayon\_sports\_rw",  "CLUB\_NAME":        "Rayon Sports FC",  "APP\_NAME":         "Rayon Sports",  "COUNTRY\_CODE":     "RW",  "SUPABASE\_URL":     "https://xxxxxxxx.supabase.co",  "SUPABASE\_ANON\_KEY":"eyJhbGci...",  "FCM\_SENDER\_ID":    "123456789",  "SENTRY\_DSN":       "https://xxx@sentry.io/yyy",  "ENVIRONMENT":      "production"}// This file is committed. Secrets (anon key) are low-sensitivity.// Service role key NEVER appears here — it lives in GitHub Secrets only.

## **5.3  Android build.gradle — Flavor Configuration**

// apps/rayon\_sports/android/app/build.gradleandroid {    flavorDimensions \["club"\]    productFlavors {        production {            dimension "club"            applicationId "rw.ikanisa.rayonsports"            versionName "1.0.0"            resValue "string", "app\_name", "Rayon Sports"        }        staging {            dimension "club"            applicationId "rw.ikanisa.rayonsports.staging"            versionName "1.0.0-staging"            resValue "string", "app\_name", "Rayon Sports (Staging)"        }    }}// Build command for production APK:// flutter build apk \--flavor production//   \--dart-define-from-file=assets/flavors/production.json

## **5.4  Design Token System — ClubTheme**

The core\_theme package provides a ClubTheme class that consumes any ClubConfig and generates a complete Flutter ThemeData with all ROUGEBLACK design tokens adapted to the club's specific colors.

// packages/core/core\_theme/lib/club\_theme.dartclass ClubTheme {  static ThemeData from(ClubConfig config) {    return ThemeData(      brightness: Brightness.dark,          // ALWAYS dark mode      primaryColor: config.colors.primary,      colorScheme: ColorScheme.dark(        primary:    config.colors.primary,   // e.g. Rayon Red        secondary:  config.colors.accent,    // e.g. Trophy Gold        surface:    const Color(0xFF0A0F2C), // Fixed: deep navy        onPrimary:  Colors.white,        onSurface:  const Color(0xFFF7F9FC),      ),      // Glassmorphism card theme      cardTheme: CardTheme(        color: Colors.white.withOpacity(0.06),        elevation: 0,        shape: RoundedRectangleBorder(          borderRadius: BorderRadius.circular(20),          side: BorderSide(color: Colors.white.withOpacity(0.15)),        ),      ),      // Typography: Barlow Condensed for display, Inter for body      textTheme: \_buildTextTheme(config.colors.primary),    );  }}

# **6\. SHARED PACKAGE ARCHITECTURE**

Shared packages are the heart of the platform. A bug fixed in feat\_contributions is fixed for all 50+ clubs simultaneously. A new feature added to feat\_gamification ships to every club in the next build.

## **6.1  Package Dependency Graph**

                    \[apps/rayon\_sports\]                           |              ┌────────────┴────────────┐              |                         |   \[club\_rayon\_sports\]         \[feat\_home\]  \[feat\_ticketing\]              |                 \[feat\_gamification\]  ...              |                         |              └───────────┬─────────────┘                          |              ┌───────────┴───────────┐              |                       |         \[core\_theme\]           \[core\_network\]         \[core\_router\]          \[core\_auth\]         \[core\_di\]              \[core\_utils\]              |                       |              └───────────┬───────────┘                          |                  \[supabase\_flutter\]                  \[riverpod\]                  \[go\_router\]                  \[flutter\_animate\]

## **6.2  Core Package Responsibilities**

| Package | Exports | Key Responsibility |
| :---- | :---- | :---- |
| core\_auth | AuthRepository, AnonSignIn, UserSession | Anonymous Supabase auth, JWT refresh, club\_id injection into metadata |
| core\_network | SupabaseClientFactory, RealtimeService | One Supabase client per app, keyed to CLUB\_ID from dart-define |
| core\_theme | ClubTheme, ClubColors, AppTextStyles | Generate ThemeData from ClubConfig; all ROUGEBLACK tokens |
| core\_router | AppRouter, RouteNames | GoRouter config; all routes; deep link handlers |
| core\_di | ServiceLocator, injectable setup | GetIt \+ Injectable; all shared services registered here |
| core\_utils | AliasGenerator, MomoDialer, DateFormatter | 6-digit alias, MOMO USSD launcher, currency formatters |

## **6.3  Feature Package Interface**

Every feature package exports a single FeatureModule that registers its providers and routes. The club app bootstraps all feature modules — feature flags from ClubConfig determine which modules are active.

// packages/features/feat\_biopay/lib/feat\_biopay.dartclass BiPayModule extends FeatureModule {  @override  String get featureKey \=\> 'biopay';           // Must match ClubConfig.features key  @override  List\<RouteBase\> get routes \=\> \[    GoRoute(path: '/biopay', builder: (\_, \_\_) \=\> const BiPayHubScreen()),    GoRoute(path: '/biopay/qr',    builder: (\_, \_\_) \=\> const QRScreen()),    GoRoute(path: '/biopay/nfc',   builder: (\_, \_\_) \=\> const NFCScreen()),    GoRoute(path: '/biopay/faceid',builder: (\_, \_\_) \=\> const FaceIDScreen()),  \];  @override  List\<Override\> get providers \=\> \[    biPayRepositoryProvider.overrideWith((\_) \=\> BiPayRepositoryImpl()),    qrCodeProvider.overrideWith((\_) \=\> QRCodeServiceImpl()),  \];}// Bootstrap (bootstrap.dart in each club app):void bootstrap(ClubConfig config) {  final modules \= \[    HomeModule(),    MembershipModule(),    GamificationModule(),    ContributionsModule(),    if (config.features\['biopay'\] \== true)   BiPayModule(),    if (config.features\['shop'\] \== true)     ShopModule(),    if (config.features\['fan\_clubs'\] \== true) FanClubsModule(),  \];  runApp(AfriClubApp(config: config, modules: modules));}

# **7\. CI/CD PIPELINE — GITHUB ACTIONS**

The CI/CD pipeline is designed to scale to 50+ clubs without linear time increase. Affected-only builds and matrix job parallelism ensure that adding a new club does not slow down every CI run.

## **7.1  Pipeline Overview**

| Trigger | Workflow | What Runs | Est. Duration |
| :---- | :---- | :---- | :---- |
| PR to main | ci.yaml | Analyze \+ test only changed packages (melos \--diff) | 5–8 min |
| Merge to main | build\_all.yaml | Build all club APKs \+ IPAs in GitHub matrix (10 parallel) | 20–40 min |
| Tag: v\*.\*.\*-{club\_slug} | deploy\_club.yaml | Build \+ upload single club to Play Store / App Store | 15 min |
| Manual dispatch | build\_club.yaml | Build single club (input: CLUB\_SLUG) | 15 min |
| Supabase migration push | migrate.yaml | Apply DB migration to staging, then production | 3 min |

## **7.2  build\_all.yaml — Matrix Build for All 50+ Clubs**

name: Build All Club Appson:  push:    branches: \[main\]jobs:  build-matrix:    strategy:      matrix:        club:          \- rayon\_sports          \- gor\_mahia          \- al\_ahly          \- kaizer\_chiefs          \- tp\_mazembe          \# ... all 50+ clubs listed      max-parallel: 10            \# 10 clubs build simultaneously      fail-fast: false            \# One club failure doesn't stop others    runs-on: ubuntu-latest    steps:      \- uses: actions/checkout@v4      \- uses: subosito/flutter-action@v2        with:          flutter-version: '3.27.x'      \- name: Bootstrap Melos        run: dart pub global activate melos && melos bootstrap      \- name: Decode keystore (Android signing)        run: |          echo "KEYSTORE\_BASE64" | base64 \-d \> upload-keystore.jks          echo "storeFile=$PWD/upload-keystore.jks" \>\> key.properties          echo "keyAlias=GITHUB\_SECRET\_KEY\_ALIAS" \>\> key.properties          echo "storePassword=GITHUB\_SECRET\_STORE\_PASSWORD" \>\> key.properties          echo "keyPassword=GITHUB\_SECRET\_KEY\_PASSWORD" \>\> key.properties      \- name: Build CLUB\_SLUG APK        working-directory: apps/CLUB\_SLUG        run: |          flutter build apk \--flavor production            \--dart-define-from-file=assets/flavors/production.json        env:          SUPABASE\_URL:      GITHUB\_SECRET\_SUPABASE\_URL          SUPABASE\_ANON\_KEY: GITHUB\_SECRET\_SUPABASE\_ANON\_KEY      \- name: Upload artifact        uses: actions/upload-artifact@v4        with:          name: CLUB\_SLUG-apk          path: apps/CLUB\_SLUG/build/app/outputs/flutter-apk/\*.apk

## **7.3  Supabase Migration Strategy**

All clubs share one database schema. Migrations are applied once and affect all clubs. Migration files are kept in supabase/migrations/ and run via the Supabase CLI.

supabase/├── migrations/│   ├── 20260101000001\_initial\_schema.sql     ← Base schema \+ all tables│   ├── 20260115000002\_add\_face\_vector.sql     ← Add pgvector to face\_registrations│   ├── 20260201000003\_add\_group\_settings.sql  ← New group settings fields│   └── \[timestamped migration per feature\]├── seed/│   ├── clubs\_seed.sql                         ← All 50+ club rows│   └── badges\_seed.sql                        ← Global badge catalog└── functions/    ├── sms-parser/                            ← Gemini SMS parser    ├── face-match/                            ← pgvector face matching    └── custom-jwt-hook/                       ← club\_id JWT injection

# **8\. PLATFORM ADMIN — CROSS-CLUB CONTROL CENTER**

The Platform Admin is a Flutter Web app that provides IKANISA operators with visibility and control across ALL clubs, while each club's own admin sees only their club's data (enforced by RLS).

## **8.1  Admin Roles**

| Role | Scope | Can Do |
| :---- | :---- | :---- |
| Platform Super Admin | All clubs (bypasses RLS) | Onboard new clubs, view cross-club analytics, manage billing, platform feature flags |
| Club Admin | One club only (JWT club\_id locked) | Manage CMS, matches, contributions, fan clubs, notifications for their club only |
| Club Moderator | One club — limited actions | Approve fan clubs, moderate group chat, respond to support |

## **8.2  Platform-Level Analytics**

Because all clubs share one Supabase project, IKANISA can run cross-club analytics without data pipelines. Platform admins see aggregated metrics across all clubs in real time.

| Metric | Query Scope | Use Case |
| :---- | :---- | :---- |
| Total active users across all clubs | SELECT COUNT(\*) FROM users | Platform health dashboard |
| Top 10 clubs by contribution volume this month | GROUP BY club\_id ORDER BY SUM(amount) | Identify highest-engagement clubs |
| BioPay adoption rate per club | is\_face\_enrolled / total users, grouped by club\_id | Feature adoption tracking |
| MOMO transaction volume per country | JOIN clubs ON club\_id GROUP BY country\_code | Regional expansion decisions |
| Gamification XP distribution | AVG(xp\_total) GROUP BY club\_id | Engagement benchmarking |

# **9\. UI/UX MULTI-CLUB DESIGN SYSTEM**

The ROUGEBLACK design system is the platform's visual DNA. It is structured in two layers: Platform Constants (identical across all clubs) and Club Tokens (unique per club). Every screen is built from platform constants first, then club tokens override only what changes.

## **9.1  Two-Layer Design Token Architecture**

| Token Layer | What It Defines | Who Sets It | Example |
| :---- | :---- | :---- | :---- |
| Platform Constants | Spacing, typography, motion, glass params, corner radii, shadow formula | IKANISA design system (immutable) | borderRadius: 20, blur: 12, bodyFont: Inter |
| Club Primary Tokens | Primary color, secondary color, accent color, gradient stops | Club config (ClubColors) | Rayon: \#C8102E / Gor Mahia: \#006B3F / Al Ahly: \#CC0000 |
| Club Asset Tokens | Crest image, splash image, launcher icon | Club assets/ folder | rayon\_crest.png vs gor\_mahia\_crest.png |
| Club Content Tokens | App name, country, language, currency symbol | ClubConfig fields | Rayon Sports · RWF · rw vs Al Ahly · EGP · ar |

## **9.2  Screen Composition — What Changes vs. What Is Shared**

| Screen Element | Platform Shared? | Club-Specific Override |
| :---- | :---- | :---- |
| Navigation bar icons \+ structure | YES — identical everywhere | None |
| Card glassmorphism style | YES — same blur, opacity, border-radius | None |
| Typography scale (Barlow \+ Inter) | YES — same font sizes, weights | None |
| Animation curves \+ durations | YES — same easing everywhere | None |
| Primary CTA button style | YES — same shape, height, haptics | Color (club primary color) |
| Home screen hero card | YES — same layout, same zones | Club crest, club colors, club match data |
| Gamification XP arc | YES — same component | Arc color \= club primary color |
| Leaderboard list item | YES — same layout | None |
| Membership tier badges | YES — same structure | Badge icon uses club crest, tier color \= club primary |
| Splash screen | YES — same animation timing | Background image \+ crest \= club assets |
| App icon | NO — unique per club | Mandatory: club crest \+ club colors |
| Match fixture card colors | YES — same layout | Club crest shown in match card |

## **9.3  African Market Adaptations**

| Adaptation | Implementation | Clubs Affected |
| :---- | :---- | :---- |
| MOMO USSD — MTN | \*182\* (Rwanda) / \*165\* (Uganda) / \*126\* (Ghana) | All MTN-market clubs |
| MOMO USSD — Airtel | \*185\* (Kenya/Tanzania/Malawi) | All Airtel-market clubs |
| MOMO USSD — Orange | \*144\* (Senegal/Mali/Burkina Faso) | All Orange-market clubs |
| RTL language support | Arabic (Egypt/Morocco): full RTL Flutter layout | North African clubs |
| Low-bandwidth mode | Image compression, skeleton-only initial load, offline queue | All clubs (Africa-wide) |
| SMS literacy fallback | Key actions available via USSD fallback codes | All clubs |
| Multi-currency display | ClubConfig.currency \+ ClubConfig.currencySymbol | All clubs — each sees local currency |
| Offline contribution queuing | Failed MOMO attempts queued, retried on reconnect | All clubs |

# **10\. CLUB ONBOARDING PLAYBOOK**

Onboarding a new African football club is a repeatable process that takes under 4 hours for developers and 1 week for App Store review. No custom code is written. The process is configuration and asset delivery only.

## **10.1  Onboarding Checklist**

| \# | Item | Provider | Format | Required |
| :---- | :---- | :---- | :---- | :---- |
| 1 | Club full name | Club | Text | YES |
| 2 | Club slug (URL-safe ID) | IKANISA | snake\_case (e.g. gor\_mahia\_ke) | YES |
| 3 | Country ISO code | Club | 2-letter ISO (e.g. KE) | YES |
| 4 | Primary color | Club | Hex (e.g. \#006B3F) | YES |
| 5 | Secondary color | Club | Hex | YES |
| 6 | Accent / highlight color | Club | Hex | YES |
| 7 | Club crest | Club | PNG 512×512 transparent bg | YES |
| 8 | Launcher icon | Club / IKANISA | PNG 1024×1024 | YES |
| 9 | Splash image | Club / IKANISA | PNG 1080×1920 | YES |
| 10 | MOMO operator \+ USSD prefix | Club | MTN/Airtel/Orange \+ prefix string | YES |
| 11 | Club MOMO number (for contributions) | Club | Phone number | YES |
| 12 | Default app language | Club | ISO 639-1 (e.g. sw, ar, en, fr) | YES |
| 13 | Feature flags | IKANISA \+ Club | JSON: { shop, biopay, fan\_clubs, ... } | YES |
| 14 | Google Play developer account | Club | Existing or IKANISA creates | YES for Play |
| 15 | Apple developer account | Club | Existing or IKANISA creates | YES for iOS |

## **10.2  Developer Steps (4 Hours)**

1. Run: melos new\_club → enter club details when prompted

2. Drop crest, splash, and launcher icon assets into apps/{slug}/assets/

3. Fill in ClubConfig values in packages/clubs/club\_{slug}/

4. Run INSERT into clubs table in Supabase (one SQL row)

5. Commit and push → GitHub Actions starts building APK \+ IPA

6. Download artifacts from GitHub Actions → submit to stores

***★  The new\_club.sh script auto-generates: pubspec.yaml, build.gradle productFlavor, Xcode scheme, GoRouter registration, dart-define JSON template, and README. Developer only fills in actual values.***

# **11\. SECURITY AT SCALE**

| Threat | Risk | Mitigation |
| :---- | :---- | :---- |
| Cross-club data access | User A from Rayon Sports reads Gor Mahia transactions | RLS club\_id policy on every table. JWT claim club\_id cannot be changed by client. |
| club\_id forgery in client request | User manually sets club\_id in API request body | club\_id is read ONLY from JWT claim (auth.club\_id() function). App-body club\_id is ignored. |
| JWT claim tampering | User modifies JWT to change club\_id | Supabase signs JWTs with HMAC-SHA256. Tampered tokens are rejected at the DB gateway. |
| Anonymous auth abuse | Mass bot signups consuming Supabase quota | Rate limiting on Edge Functions \+ Supabase Auth rate limits. Device fingerprint stored in user metadata. |
| MOMO number exposure | Someone reads another user's MOMO from DB | MOMO stored encrypted (pgcrypto). Only masked display (07XX\*\*\*XXX) returned to client. |
| Admin panel access | Club admin accesses another club's CMS | Admin JWT has club\_id claim same as user JWT. RLS applies equally to admin role. Super admin uses separate service\_role \+ 2FA. |
| SMS parser abuse | Attacker sends forged MOMO SMS to parser endpoint | Parser validates: SMS sender ID matches club's momo\_sender\_id, SHA-256 dedup, group\_id must belong to authenticated user's club\_id. |
| Face data exposure | Biometric embeddings leaked from Storage | Face embeddings stored as 128-float vector only (no photos on server). Storage bucket is private. Embeddings encrypted at rest. |
| Supabase service\_role key exposure | Attacker gains admin DB access | Service role key ONLY in GitHub Secrets and Edge Functions environment. Never in any client code or dart-define JSON. |

# **12\. COST MODEL — SUPABASE AT SCALE**

Because all clubs share one Supabase project, the cost scales with rows and bandwidth — not with number of clubs. The marginal cost of adding a new club is essentially zero infrastructure cost.

| Cost Driver | Multi-Repo (50 projects) | AFRICLUB (1 project) | Saving |
| :---- | :---- | :---- | :---- |
| Supabase plan | 50 × Pro ($25) \= $1,250/mo | 1 × Pro ($25/mo) or Team ($599/mo) | $651–$1,225/mo |
| DB compute | 50 × small instance | 1 × large instance (shared) | \~60% less |
| Storage | 50 × 100GB \= 5TB | 1 × 500GB–1TB (shared) | \~70% less |
| Edge Functions | 50 × quota | 1 × larger quota (shared) | \~50% less |
| Backup / PITR | 50 × enabled | 1 × enabled | \~90% less |
| Monitoring | 50 × dashboards | 1 × unified dashboard | 100% ops savings |

***★  At Year 1 (50 clubs), AFRICLUB saves \~$13,000–15,000/year vs. one Supabase project per club, while providing better cross-club observability.***

# **13\. PLATFORM DEVELOPMENT ROADMAP**

| Phase | Duration | Deliverable | Club Count |
| :---- | :---- | :---- | :---- |
| Phase 0 — Monorepo Foundation | 4 weeks | Melos setup, core packages, ClubConfig interface, flavor system, CI/CD skeleton | 0 (infrastructure) |
| Phase 1 — Platform Core | 6 weeks | Supabase multi-tenant schema \+ RLS, Auth hook, all core features (auth, home, gamification, contributions) | 0 (building) |
| Phase 2 — Pilot Club (Rayon Sports) | 4 weeks | Full Rayon Sports app built, tested, submitted to stores. Validate entire pipeline end-to-end | 1 |
| Phase 3 — East Africa Cohort | 6 weeks | Onboard 9 clubs: Kenya, Uganda, Tanzania, Ethiopia, Mozambique, Zimbabwe, Zambia, Malawi, Burundi | 10 |
| Phase 4 — West Africa Cohort | 6 weeks | Onboard 10 clubs: Nigeria, Ghana, Senegal, Côte d'Ivoire, Cameroon, Mali, Guinea, Burkina Faso, Togo, Benin | 20 |
| Phase 5 — North & South Africa | 6 weeks | Onboard 15 clubs: Egypt, Morocco, Algeria, Tunisia, Libya / South Africa, Namibia, Botswana, Angola, Mozambique | 35 |
| Phase 6 — Remaining Countries | 4 weeks | Complete 50-club target. Central Africa \+ Indian Ocean islands | 50 |
| Phase 7 — Platform v2 | 8 weeks | Club-to-club challenges, pan-African leaderboard, federation partnerships, sponsorship module | 50+ |

***★  Total to 50 clubs: \~38 weeks (9.5 months) from monorepo foundation to 50th club submitted. Phases 3–6 run partially in parallel once CI/CD and monorepo are proven.***

**— END OF DOCUMENT —**