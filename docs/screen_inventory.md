# AFRICLUB — Complete Screen Inventory

> **65 screens** · 13 categories · 15 feature modules · Dark glassmorphic mobile UI
> Generated: 2026-03-30 · Updated: 2026-03-30 · Pilot: Rayon Sports FC

---

## Design System Token (shared across all prompts)

```
Dark glassmorphic mobile UI, deep navy (#0A0F2C) background gradient,
frosted glass cards (white 6% opacity, blur, 0.5pt white border),
primary red (#C8102E) CTAs, gold (#D4A017) accents,
Legacy visual notes remain below for screen-by-screen product inventory.
Canonical Flutter design-system guidance now lives in `packages/core/core_theme/README.md`.
minimum 15sp body text, 375×812pt mobile frame, dark mode only,
football-first aesthetic, Rwanda Rayon Sports FC branding,
club crest top-left where applicable, no light backgrounds.
```

---

## Status Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Implemented (screen file exists) |
| ⚠️ | Partial (file exists, missing features) |
| ❌ | Not implemented |

---

## 1 · Onboarding & Authentication (5 screens)

| # | Screen | Tag | Module | File | Status | DB Tables |
|---|--------|-----|--------|------|--------|-----------|
| 1.1 | Splash Screen | first launch | `feat_onboarding` | `splash_screen.dart` | ✅ | — |
| 1.2 | Onboarding — Slide 1 | first launch | `feat_onboarding` | `onboarding_screen.dart` | ✅ | — |
| 1.3 | Onboarding — Slide 2 | first launch | `feat_onboarding` | `onboarding_screen.dart` | ✅ | — |
| 1.4 | Onboarding — Slide 3 | first launch | `feat_onboarding` | `onboarding_screen.dart` | ✅ | — |
| 1.5 | Profile Setup | onboarding | `feat_onboarding` | `profile_setup_screen.dart` | ✅ | `users` |

### Stitch Prompts

<details><summary>1.1 Splash Screen</summary>

```
Mobile splash screen for a football club app. Full-bleed dark stadium photograph at night, dramatic floodlights, deep blue-black atmosphere. Centered club crest (Rayon Sports FC red-and-black shield) scaling up from 0 with a soft red glow pulse. App name "Rayon Sports" in Space Grotesk ExtraBold 56sp white below the crest, fading in. Thin red horizontal rule beneath the name. Loading progress bar at bottom (thin red line). No other UI elements.
```
</details>

<details><summary>1.2 Onboarding — Slide 1</summary>

```
Mobile onboarding screen 1 of 3. Full-bleed dark navy gradient background with a faint stadium silhouette texture. Top 60% shows a dramatic close-up photograph of fans in red stadium stands. Bottom 40%: frosted glass card. Large headline "Your club. Your app." in Space Grotesk ExtraBold 38sp white. Subtext in Manrope 16sp steel-gray: "The official Rayon Sports FC fan platform. Matches, contributions, and more." Pagination dots ● ○ ○ in red/gray. Large red claymorphic "Next" button (full width, 56pt height, 28pt radius). Skip text link top-right.
```
</details>

<details><summary>1.3 Onboarding — Slide 2</summary>

```
Mobile onboarding screen 2 of 3. Dark navy background. Top area shows three glassmorphic cards floating: one shows FET badge, one shows a ticket QR code, one shows a MOMO contribution circle. Headline: "Fan membership. Tickets. Contributions." in Space Grotesk 36sp white. Subtext: "Earn FET, buy match tickets, and contribute to club projects — all in one place." Pagination dots ○ ● ○. Red "Next" button.
```
</details>

<details><summary>1.4 Onboarding — Slide 3</summary>

```
Mobile onboarding screen 3 of 3. Dark navy. Large centered icon of a phone with a lock symbol. Headline: "You're anonymous by default." Subtext: "No name required. Just your MOMO number. Your public identity is a private 6-digit code only you know." Pagination dots ○ ○ ●. Large red claymorphic button "Get Started — it's free". Small gray fine print: "By continuing you agree to Terms of Use."
```
</details>

<details><summary>1.5 Profile Setup</summary>

```
Mobile profile setup screen. Dark navy background. Top: large progress bar "Step 1 of 1 — Link your MOMO". Center: frosted glass card. Headline "Your MOMO number" in Space Grotesk 32sp. Large phone number input field (dark glass surface, white text, red underline focus state, placeholder "+250 7XX XXX XXX"). Helper text: "This links your payments to your anonymous profile. Never shown publicly." Your alias: large JetBrains Mono 36sp gold "483 912" in a dark chip — "This is your public identity." Red full-width CTA "Confirm & Enter".
```
</details>

---

## 2A · Home Tab — Main (1 screen)

| # | Screen | Tag | Module | File | Status | DB Tables |
|---|--------|-----|--------|------|--------|-----------|
| 2.1 | Home Screen | home · bottom nav | `feat_home` | `home_screen.dart` | ✅ | `matches`, `app_ui_config`, `contribution_groups`, `gamification_events` |

<details><summary>2.1 Home Screen</summary>

```
Mobile football club homescreen. Dark navy gradient. Scrollable feed. TOP ZONE: full-width glassmorphic hero card — Rayon Sports crest left, opponent crest right, match countdown "2d 14h" in Space Grotesk 40sp gold, "NEXT MATCH" chip, status PRE-MATCH mint. ZONE 2: horizontal quick actions rail — 6 claymorphic icon chips (red pill-shaped): Tickets · Shop · Contribute · Games · Membership · Fan Clubs. ZONE 3: admin banner carousel with dots. ZONE 4: "My Active Circles" horizontal scroll — 2 partial glass cards with progress rings. ZONE 5: Gamification teaser — alias "483912" FET arc, "Bronze · 2,340 FET", mini leaderboard. ZONE 6: Club news feed — 2 image-first cards. Bottom: 3-tab nav bar (Home active red, BioPay, Settings).
```
</details>

---

## 2B · Tickets (5 screens)

| # | Screen | Tag | Module | File | Status | DB Tables |
|---|--------|-----|--------|------|--------|-----------|
| 2.2a | Match List | tickets | `feat_ticketing` | `match_list_screen.dart` | ✅ | `matches` |
| 2.2b | Match Detail / Buy Ticket | tickets | `feat_ticketing` | `match_detail_screen.dart` | ✅ | `matches`, `tickets` |
| 2.2c | Seat Map | tickets | `feat_ticketing` | `interactive_seat_map_screen.dart` | ✅ | `tickets` |
| 2.2d | My Tickets | tickets | `feat_ticketing` | `my_tickets_screen.dart` | ✅ | `tickets` |
| 2.2e | E-Ticket / QR | tickets | `feat_ticketing` | `e_ticket_qr_screen.dart` | ✅ | `tickets` |

<details><summary>2.2a Match List</summary>

```
Mobile match fixtures list screen. Dark navy. Header: back arrow, "Tickets" Space Grotesk 28sp center, filter icon. Tabs: UPCOMING · PAST (red underline). List of glassmorphic match cards: home crest | home team | date | away team | away crest, venue below, price chip gold bottom-right, AVAILABLE/SOLD OUT status chip. Red FAB "Buy Ticket" bottom-right.
```
</details>

<details><summary>2.2b Match Detail / Buy Ticket</summary>

```
Mobile match ticket purchase screen. Dark navy. Large glassmorphic hero: Rayon Sports vs APR FC crests, date "Sat 5 Apr 2026", time "16:00", stadium name. Zone selector cards: 4 options (VIP Gold, Tribune Red, East Stand, Standing) with prices, selected = red border glow. Quantity stepper. Bottom: total price Space Grotesk 32sp gold, "Pay via MOMO" red full-width button.
```
</details>

<details><summary>2.2c Seat Map</summary>

```
Mobile stadium seat map. Dark navy. Top: match header. Center: top-down SVG stadium diagram — pitch dark green center, seating zones color-coded: gold VIP available, red Tribune available, gray unavailable, white outline selected seat. Selected seat: floating glass chip shows seat code. Bottom: selected info + "Confirm Selection" red button. Zone legend bottom.
```
</details>

<details><summary>2.2d My Tickets</summary>

```
Mobile "My Tickets" screen. Dark navy. Header "My Tickets". Tabs: UPCOMING · PAST. Per-ticket glassmorphic card: crest, match name, date, zone, seat code. Large QR icon right (blurred — "tap to open"). Status chip: VALID mint or USED gray. Red outline on valid tickets.
```
</details>

<details><summary>2.2e E-Ticket / QR</summary>

```
Mobile full-screen e-ticket. Very dark background. Center: large white QR code on dark glass card 400pt square. Above: crest + match name Space Grotesk 24sp. Below QR: seat code "C-14" JetBrains Mono 22sp gold, date/time, zone. Animated scanning line across QR. Bottom: NFC icon "Tap to share via NFC".
```
</details>

---

## 2C · Club Shop (3 screens)

| # | Screen | Tag | Module | File | Status | DB Tables |
|---|--------|-----|--------|------|--------|-----------|
| 2.3a | Shop Home | shop | `feat_shop` | `shop_screen.dart` | ✅ | `shop_products` |
| 2.3b | Product Detail | shop | `feat_shop` | `product_detail_screen.dart` | ✅ | `shop_products` |
| 2.3c | Cart Screen | shop | `feat_shop` | `cart_screen.dart` | ✅ | `shop_products` |

<details><summary>2.3a Shop Home</summary>

```
Mobile club merchandise shop. Dark navy. Header "Club Shop" + cart icon with badge. Hero banner: new season kit. Category chips scroll: ALL · KITS · SCARVES · CAPS · ACCESSORIES. Product grid 2-column: glassmorphic cards, photo top, name, price gold, "Add" red button. Featured full-width banner card.
```
</details>

<details><summary>2.3b Product Detail</summary>

```
Mobile product detail — Rayon Sports football kit. Dark navy. Large product image full-width (dots for swipe). Product name Space Grotesk 28sp, price gold, rating stars, category chip. Size selector: S M L XL glass pills (selected = red). Color circles. Description expandable. "Add to Cart" red full-width button. "Pay with MOMO" secondary glass outline button.
```
</details>

<details><summary>2.3c Cart Screen</summary>

```
Mobile shopping cart. Dark navy. Header "Your Cart" + count. Cart items: thumbnail left, name + size + quantity stepper right, price right, remove button. Order summary: subtotal, delivery, total Space Grotesk gold. Delivery address glass input. "Checkout via MOMO" red full-width button.
```
</details>

---

## 2D · Gamification (5 screens)

| # | Screen | Tag | Module | File | Status | DB Tables |
|---|--------|-----|--------|------|--------|-----------|
| 2.4a | Gamification Hub | games | `feat_gamification` | `fet_dashboard_screen.dart` | ✅ | `gamification_events`, `users` |
| 2.4b | Challenges Screen | games | `feat_gamification` | `challenges_screen.dart` | ✅ | `gamification_events` |
| 2.4c | Leaderboard | games | `feat_gamification` | `leaderboard_screen.dart` | ✅ | `gamification_events`, `users` |
| 2.4d | Badges Screen | games | `feat_gamification` | `badges_screen.dart` | ✅ | `badges`, `user_badges` |
| 2.4e | Streak Calendar | games | `feat_gamification` | `streak_calendar_screen.dart` | ✅ | `gamification_events` |

<details><summary>2.4a Gamification Hub</summary>

```
Mobile gamification screen. Dark navy. Large header: stadium arc, alias "483912" JetBrains Mono, rank "#47 of 12,400 fans". FET arc progress circle red arc 2340/5000 FET. Tier badge: BRONZE chip. Quick nav: FET HISTORY · CHALLENGES · LEADERBOARD · BADGES · STREAKS. Featured challenge card. Recent activity feed.
```
</details>

<details><summary>2.4b Challenges Screen</summary>

```
Mobile challenges screen. Dark navy. Header "Challenges". Tabs: DAILY · WEEKLY · SEASONAL. Challenge cards glassmorphic: icon, title, FET reward gold, progress bar red fill, time remaining chip orange. Countdown clock on daily. COMPLETED state: green check, dimmed, red "Claim FET" button.
```
</details>

<details><summary>2.4c Leaderboard</summary>

```
Mobile fan leaderboard. Dark navy. Top 3 podium: #2 silver glass left, #1 gold glass center red glow largest, #3 bronze right. Each: alias JetBrains Mono, FET Space Grotesk. Below: scrollable list — rank | alias | tier badge | FET. Current user row highlighted red tint. "Your rank: #47" sticky bottom bar.
```
</details>

<details><summary>2.4d Badges Screen</summary>

```
Mobile badges collection. Dark navy. Header "Your Badges". Stats "8/34 earned". 4-column grid: earned = full color claymorphic circular badge gold glow; locked = dark gray lock overlay. Tap to expand: name, description, date, share button. Red section "RECENT UNLOCKS".
```
</details>

<details><summary>2.4e Streak Calendar</summary>

```
Mobile activity streak screen. Dark navy. Large "14 days" Space Grotesk 56sp gold. GitHub-style heatmap calendar 7-column: cells dark navy to bright red by activity. Streak goal arc. "Current: 14 · Best: 21". FET milestone markers: 7-day · 30-day · 60-day.
```
</details>

---

## 2E · Contributions (8 screens)

| # | Screen | Tag | Module | File | Status | DB Tables |
|---|--------|-----|--------|------|--------|-----------|
| 2.5a | Contributions Hub | contribute | `feat_contributions` | `contributions_hub_screen.dart` | ✅ | `contribution_groups` |
| 2.5b | Club Projects List | contribute | `feat_contributions` | `club_projects_screen.dart` | ✅ | `contribution_groups` |
| 2.5c | My Circles | contribute | `feat_contributions` | `groups_screen.dart` | ✅ | `contribution_groups` |
| 2.5d | Group Detail | contribute | `feat_contributions` | `group_detail_screen.dart` | ✅ | `contribution_groups`, `transactions` |
| 2.5e | Create Group | contribute | `feat_contributions` | `create_group_screen.dart` | ✅ | `contribution_groups` |
| 2.5f | Group Chat | contribute | `feat_contributions` | `group_chat_screen.dart` | ✅ | `group_messages` |
| 2.5g | Group Settings | contribute · creator | `feat_contributions` | `group_settings_screen.dart` | ✅ | `contribution_groups` |
| 2.5h | Statement Download | contribute | `feat_contributions` | `statement_download_screen.dart` | ✅ | `transactions` |

<details><summary>2.5a Contributions Hub</summary>

```
Mobile contributions hub. Dark navy. Header "Contribute". Three large category cards: 1) CLUB PROJECTS red glass, crest, progress, "Support the Club" CTA. 2) MY CIRCLES teal glass, count. 3) COMMUNITY purple glass. "Start a Circle" red FAB.
```
</details>

<details><summary>2.5b Club Projects List</summary>

```
Mobile club contribution projects list. Dark navy. Each project card glassmorphic: title Space Grotesk 22sp, 2-line description, goal progress bar red "FRw 2.4M / FRw 5M", contributor count, days remaining chip, "Contribute" red button. Admin-created gold badge.
```
</details>

<details><summary>2.5c My Circles</summary>

```
Mobile "My Circles" contribution groups. Dark navy. Header + create button. Cards: group name bold, type chip, privacy icon, small progress ring, member count, last activity. Empty state: illustration + red CTA.
```
</details>

<details><summary>2.5d Group Detail</summary>

```
Mobile contribution group detail. Dark navy. Header: group name + PRIVATE chip. Hero: large progress ring red arc, amount raised 40sp gold, target. "Contribute Now" red full-width + amount entry. Tabs: LEDGER · CHAT · SETTINGS. LEDGER: transaction rows alias JetBrains Mono | gold amount | timestamp. New row slides in from top.
```
</details>

<details><summary>2.5e Create Group</summary>

```
Mobile create contribution circle form. Dark navy. Header "New Circle". Fields: Group Name, Description, Target Amount FRw, Deadline, Privacy pills (PUBLIC · MEMBERS · PRIVATE), MOMO input. Allow Chat toggle. Live preview card. "Create Circle" red button.
```
</details>

<details><summary>2.5f Group Chat</summary>

```
Mobile group chat inside contribution circle. Dark navy. Chat bubbles: sent right dark red glass, received left dark navy glass. Alias chip JetBrains Mono gold above each bubble. Transaction notification: full-width mint green bar "483912 contributed FRw 5,000". Text input bar bottom: glass, red send circle, emoji left.
```
</details>

<details><summary>2.5g Group Settings</summary>

```
Mobile group settings creator-only. Dark navy. Fields: Name, Privacy pills, Target, Deadline, MOMO masked editable. Danger zone red-border card: "Close Circle" orange, "Delete Circle" red. Download Statement button PDF/CSV. "Save Changes" red button.
```
</details>

<details><summary>2.5h Statement Download</summary>

```
Mobile statement download screen. Dark navy. Date range FROM / TO glass inputs. Sort: By Date · By Amount · By Alias pills. Format: PDF card | CSV card (selected = red border). Preview mini-table 5 rows. "Download" red button. Privacy note: "Shows alias IDs only."
```
</details>

---

## 2F · Membership (2 screens)

| # | Screen | Tag | Module | File | Status | DB Tables |
|---|--------|-----|--------|------|--------|-----------|
| 2.6a | Membership Screen | membership | `feat_membership` | `membership_screen.dart` | ✅ | `users`, `gamification_events` |
| 2.6b | Tier Detail | membership | `feat_membership` | `tier_detail_screen.dart` | ✅ | `users` |

<details><summary>2.6a Membership Screen</summary>

```
Mobile fan membership screen. Dark navy. Top: digital membership card glassmorphic horizontal: crest left, BRONZE SUPPORTER bronze gradient, alias "483912" JetBrains Mono center, barcode stripe bottom. Below: tier cards — FAN gray, BRONZE bronze glass, SILVER silver glass, GOLD gold glass, LEGEND red glass. Current tier glows. Each: FET range, perks, progress.
```
</details>

<details><summary>2.6b Tier Detail</summary>

```
Mobile tier detail. Dark navy. Header "GOLD FAITHFUL" gold Space Grotesk 36sp. Large tier badge glassmorphic circular trophy. FET range "15,000–40,000 FET". Perks with checkmarks: 15% shop discount · VIP events · Priority support · Early tickets. Progress to next tier bar. "How to earn FET faster" collapsible.
```
</details>

---

## 2G · Fan Clubs (3 screens)

| # | Screen | Tag | Module | File | Status | DB Tables |
|---|--------|-----|--------|------|--------|-----------|
| 2.7a | Fan Clubs List | fan clubs | `feat_fan_clubs` | `fan_clubs_list_screen.dart` | ✅ | `fan_clubs` |
| 2.7b | Fan Club Detail | fan clubs | `feat_fan_clubs` | `fan_club_detail_screen.dart` | ✅ | `fan_clubs` |
| 2.7c | Create Fan Club | fan clubs | `feat_fan_clubs` | `create_fan_club_screen.dart` | ✅ | `fan_clubs` |

<details><summary>2.7a Fan Clubs List</summary>

```
Mobile fan clubs directory. Dark navy. Header "Fan Clubs". Search glass bar. Featured banner card full-width. Club list glass rows: logo, name, location, member count, OFFICIAL badge, JOIN/JOINED button. Filter chips: ALL · KIGALI · INTERNATIONAL · OFFICIAL.
```
</details>

<details><summary>2.7b Fan Club Detail</summary>

```
Mobile fan club detail. Dark navy. Header photo. Club name Space Grotesk 30sp + OFFICIAL chip. Stats: Members · Founded · Location. About expandable. Activities feed. Members 6 alias avatars. Upcoming events card. JOIN red large or JOINED green outline. Share button.
```
</details>

<details><summary>2.7c Create Fan Club</summary>

```
Mobile create fan club form. Dark navy. Header "Start a Fan Club". Fields: Club Name, Location, Description, Photo upload dashed glass, Public/Private toggle, Regions multi-select. Gold info card: "Fan clubs reviewed by admin." Submit red button.
```
</details>

---

## 2H · Live & News (2 screens)

| # | Screen | Tag | Module | File | Status | DB Tables |
|---|--------|-----|--------|------|--------|-----------|
| 2.8a | Live Match Screen | live | `feat_live` | `live_match_screen.dart` | ✅ | `matches` |
| 2.8b | News Article | news | `feat_live` | `news_article_screen.dart` | ✅ | `app_ui_config` |

<details><summary>2.8a Live Match Screen</summary>

```
Mobile live match center. Dark navy subtle red pulse. "LIVE" mint chip pulsing dot. Both team crests large. Score "2 — 1" Space Grotesk 64sp white, mint underline winner. Clock "67'" gold. Commentary feed: timestamped GOAL · YELLOW CARD · SUBSTITUTION events. Stats: possession bar, shots, corners. Share button.
```
</details>

<details><summary>2.8b News Article</summary>

```
Mobile news article. Dark navy. Back arrow + "Club News". Hero image full-width. Category chip red. Title Space Grotesk 28sp. Author + date gray. Body Manrope 16sp. Related articles scroll bottom. Share button floating right.
```
</details>

---

## 3 · BioPay Tab (10 screens)

| # | Screen | Tag | Module | File | Status | DB Tables |
|---|--------|-----|--------|------|--------|-----------|
| 3.1 | BioPay Hub | biopay · bottom nav | `feat_biopay` | `biopay_screen.dart` | ✅ | `face_registrations` |
| 3.2 | BioPay Manage | biopay · manage | `feat_biopay` | `biopay_manage_screen.dart` | ✅ | `face_registrations` |
| 3.3 | QR Receive Screen | biopay · qr | `feat_biopay` | `biopay_qr_screen.dart` | ✅ | `users` |
| 3.4 | QR Pay Scan | biopay · qr · scan | `feat_biopay` | `biopay_qr_scan_screen.dart` | ✅ | `users` |
| 3.5 | NFC Receive & Pay | biopay · nfc | `feat_biopay` | `biopay_nfc_screen.dart` | ✅ | `users` |
| 3.6 | Face ID Registration | biopay · setup | `feat_biopay` | `biopay_register_screen.dart` | ✅ | `face_registrations` |
| 3.7 | Face Capture / Face Match | biopay · scan | `feat_biopay` | `biopay_scan_screen.dart` | ✅ | `face_registrations` |
| 3.8 | Payment Review | biopay · review | `feat_biopay` | `biopay_payment_review_screen.dart` | ✅ | `biopay_payment_intents` |
| 3.9 | Payment Result | biopay · result | `feat_biopay` | `biopay_result_screen.dart` | ✅ | `biopay_payment_intents` |
| 3.10 | Recovery / Help | biopay · recovery | `feat_biopay` | `biopay_recovery_screen.dart` | ✅ | — |

<details><summary>3.1 BioPay Hub</summary>

```
Mobile BioPay hub. Dark navy. Header "BioPay" tagline "Pay or Receive". Two grouped sections: RECEIVE and PAY. Receive cards route to Face ID management, QR receive, and NFC receive. Pay cards route to face match, QR scan, and NFC scan. If MOMO is not linked, show a prominent "Link Mobile Money" card before any BioPay action.
```
</details>

<details><summary>3.2 BioPay Manage</summary>

```
Mobile BioPay management screen. Dark navy gradient. Header "BioPay Manage". Primary glass card shows alias, masked payment route, consent version, and privacy summary. Actions: Re-enroll, Revoke. Shortcut cards: Pay by Face, QR Receive, QR Pay, NFC Receive & Pay.
```
</details>

<details><summary>3.3 QR Receive Screen</summary>

```
Mobile BioPay QR receive screen. Very dark background. Center: large signed QR on dark glass card with countdown ring. Alias shown prominently in numeric styling. Payment route is masked, never raw. Optional amount can be set before share. Primary actions: Share QR, Save to Photos, Scan to Pay.
```
</details>

<details><summary>3.4 QR Pay Scan</summary>

```
Mobile BioPay QR scanner. Full-screen camera with framed scan target. Footer glass card explains that BioPay verifies the signed QR payload before continuing. Successful scans route into a dedicated review screen instead of opening the dialer immediately.
```
</details>

<details><summary>3.5 NFC Receive & Pay</summary>

```
Mobile BioPay NFC screen. Dark navy. Shared receive/pay task surface. Receive card can activate Android phone tap or write a signed NFC request with an optional amount. Scan card reads another BioPay request and routes into review before payment handoff. Recovery CTA appears when NFC is disabled or host card emulation is unavailable.
```
</details>

<details><summary>3.6 Face ID Registration</summary>

```
Mobile face ID enrollment. Dark navy. Step indicator ① POSITION ② ANGLES ③ CONFIRM red highlight. Camera preview dark rectangle, face oval guide red dashed. Instructions: look straight, good lighting, remove glasses. Liveness "Blink when ready". Progress 0/5 angles. Large red circle capture button. Privacy: "No photos stored."
```
</details>

<details><summary>3.7 Face Capture / Face Match</summary>

```
Mobile face scan shell. Dark navy. Full camera preview with biometric oval overlay, floating status chip, liveness guidance, privacy badge, and capture progress. Enrollment collects five stable samples; pay mode routes successful matches into a review screen with amount entry before opening the dialer.
```
</details>

<details><summary>3.8 Payment Review</summary>

```
Mobile review screen used by face, QR, and NFC flows. Dark navy gradient. Large alias treatment, masked payment route, flow label, optional match confidence, and amount entry for face-pay. Primary CTA opens the payment dialer only after explicit confirmation.
```
</details>

<details><summary>3.9 Payment Result</summary>

```
Mobile BioPay result screen. Dark navy. State card with success/error/blocked messaging, alias summary, masked route, optional amount, and explicit next actions such as returning to BioPay or retrying the flow.
```
</details>

<details><summary>3.10 Recovery / Help</summary>

```
Mobile BioPay recovery screen. Dark navy. Guidance for camera, device-auth, NFC, or feature-level failures. Includes action steps and return buttons instead of leaving users on dead-end error states.
```
</details>

---

## 4 · Settings Tab (6 screens)

| # | Screen | Tag | Module | File | Status | DB Tables |
|---|--------|-----|--------|------|--------|-----------|
| 4.1 | Settings Home | settings · bottom nav | `feat_settings` | `settings_screen.dart` | ✅ | `users` |
| 4.2 | Edit Profile | settings | `feat_settings` | `edit_profile_screen.dart` | ✅ | `users` |
| 4.3 | Notifications | settings | `feat_settings` | `notification_preferences_screen.dart` | ✅ | `users` |
| 4.4 | Language & Region | settings | `feat_settings` | `language_region_screen.dart` | ✅ | `users` |
| 4.5 | Privacy Settings | settings | `feat_settings` | `privacy_settings_screen.dart` | ✅ | `users` |
| 4.6 | About Screen | settings | `feat_settings` | `about_screen.dart` | ✅ | — |

<details><summary>4.1 Settings Home</summary>

```
Mobile settings screen. Dark navy. Header "Settings". Profile summary glassmorphic: alias "483912" JetBrains Mono gold large, BRONZE tier badge, MOMO linked chip. Grouped settings glass cards: ACCOUNT (Edit Profile, MOMO, Notifications, Language), BIOPAY (Face ID, NFC, QR), PRIVACY (Alias, Visibility, Data), SUPPORT (Help, Bug, Rate), ABOUT (Version, Terms, Privacy). Bottom nav Settings active.
```
</details>

<details><summary>4.2 Edit Profile</summary>

```
Mobile edit profile. Dark navy. Avatar: circular glass frame, silhouette, "+ Photo" red chip. Fields: Nickname input optional, MOMO masked tap-to-update, Language selector. Read-only: Alias "483912" lock icon "Permanent". "Save Changes" red button. "Delete Account" red text link bottom.
```
</details>

<details><summary>4.3 Notifications</summary>

```
Mobile notification preferences. Dark navy. Toggles list glass: MATCH ALERTS ON, CONTRIBUTION ON, FET MILESTONES ON, TEAM NEWS OFF, CHALLENGES ON, GROUP MESSAGES OFF. Master "Allow All" toggle top. Save button. Each row: icon, label, subtitle, toggle.
```
</details>

<details><summary>4.4 Language & Region</summary>

```
Mobile language settings. Dark navy. Currency "FRw" non-editable note. Language list glass rows: Kinyarwanda (selected red check), Français, English. Save button. Note about content language.
```
</details>

<details><summary>4.5 Privacy Settings</summary>

```
Mobile privacy settings. Dark navy. Group visibility pills: PUBLIC / MEMBERS ONLY / PRIVATE. Activity status toggle. Analytics opt-out toggle + gold info chip. "Your Data": View My Data, Download My Data glass buttons. Security: Biometric login toggle. Active sessions. "Sign Out All Devices" red outlined button.
```
</details>

<details><summary>4.6 About Screen</summary>

```
Mobile about screen. Dark navy. Large crest + "Rayon Sports FC" Space Grotesk 32sp. App version gray. "Powered by AFRICLUB" gold chip. Links: Terms · Privacy · Licenses. "Support via WhatsApp" green + "Email Support" buttons. Rate App 5 gold stars. Build info fine print.
```
</details>

---

## 5 · Admin Screens (5 screens)

| # | Screen | Tag | Module | File | Status | DB Tables |
|---|--------|-----|--------|------|--------|-----------|
| 5.1 | Admin Dashboard | admin · role-gated | `feat_admin` | `admin_dashboard_screen.dart` | ✅ | `users`, `contribution_groups`, `transactions`, `tickets` |
| 5.2 | CMS Manager | admin | `feat_admin` | `cms_content_manager_screen.dart` | ✅ | `app_ui_config` |
| 5.3 | Match Manager | admin | `feat_admin` | `match_manager_screen.dart` | ✅ | `matches`, `tickets` |
| 5.4 | Contributions Monitor | admin | `feat_admin` | `contributions_monitor_screen.dart` | ✅ | `contribution_groups`, `transactions` |
| 5.5 | Push Notifications | admin | `feat_admin` | `push_notifications_screen.dart` | ✅ | — (FCM) |

<details><summary>5.1 Admin Dashboard</summary>

```
Mobile admin dashboard. Dark navy. Header "Club Admin — Rayon Sports" + logout. Stats row 4 glassmorphic cards: Total Users · Active Circles · Transactions Today · Tickets Sold — numbers Space Grotesk gold. Quick actions: Manage CMS · Create Match · Send Notification · Reports. Recent activity feed.
```
</details>

<details><summary>5.2 CMS Manager</summary>

```
Mobile CMS content manager. Dark navy. Tabs: BANNERS · NEWS · PROMOTIONS. Content items: preview thumbnail, title, status chip (LIVE/SCHEDULED/DRAFT), edit button, drag handle. "Add Content" red FAB.
```
</details>

<details><summary>5.3 Match Manager</summary>

```
Mobile match management admin. Dark navy. Header "Matches". Fixture cards: date, home vs away, venue, status chip. Ticket sales progress bar. "Edit" + "Open/Close Tickets" buttons. Create match form: date, teams, venue, zone prices.
```
</details>

<details><summary>5.4 Contributions Monitor</summary>

```
Mobile contributions monitor admin. Dark navy. Filter chips. Total raised Space Grotesk 40sp gold. Active groups list: name, creator alias, type, total FRw, contributors, last activity. Export report button.
```
</details>

<details><summary>5.5 Push Notifications</summary>

```
Mobile notification composer admin. Dark navy. Audience: ALL / BY TIER chips / BY GROUP. Title + message inputs with character count. Image upload. Preview phone notification card. Send Now or Schedule date/time. Send history list.
```
</details>

---

## 6 · Popups · Sheets · Modals (15 screens)

| # | Screen | Tag | Module | File | Status | DB Tables |
|---|--------|-----|--------|------|--------|-----------|
| 6.1 | MOMO Amount Entry | popup · contribute | `feat_contributions` | `contribution_overlays.dart` | ✅ | — |
| 6.2 | MOMO USSD Confirm | popup · payment | `feat_contributions` | `contribution_overlays.dart` | ✅ | — |
| 6.3 | Contribution Success | modal · success | `feat_contributions` | `contribution_overlays.dart` | ✅ | — |
| 6.4 | FET Level Up | modal · celebration | `feat_gamification` | `gamification_overlays.dart` | ✅ | — |
| 6.5 | Badge Earned | modal · celebration | `feat_gamification` | `gamification_overlays.dart` | ✅ | — |
| 6.6 | Group Invite Code | sheet · share | `feat_contributions` | `contribution_overlays.dart` | ✅ | `contribution_groups` |
| 6.7 | Ticket Purchase Confirm | sheet · tickets | `feat_ticketing` | `ticketing_overlays.dart` | ✅ | `tickets` |
| 6.8 | Delete Account Confirm | modal · danger | `feat_settings` | `settings_overlays.dart` | ✅ | `users` |
| 6.9 | SMS Permission Modal | modal · permission | `feat_contributions` | `contribution_overlays.dart` | ✅ | — |
| 6.10 | Face Liveness Prompt | overlay · biopay | `feat_biopay` | `biopay_overlays.dart` | ✅ | — |
| 6.11 | NFC Pairing Sheet | sheet · biopay | `feat_biopay` | `biopay_overlays.dart` | ✅ | — |
| 6.12 | Filter & Sort Sheet | sheet · global | `core_theme` | `afri_filter_sheet.dart` | ✅ | — |
| 6.13 | Notification Permission | modal · permission | `feat_settings` | `settings_overlays.dart` | ✅ | — |
| 6.14 | Sign Out Confirm | sheet · auth | `feat_settings` | `settings_overlays.dart` | ✅ | — |
| 6.15 | Group Privacy Settings | sheet · groups | `feat_contributions` | `contribution_overlays.dart` | ✅ | `contribution_groups` |

<details><summary>6.1 MOMO Amount Entry</summary>

```
Mobile MOMO amount entry bottom sheet 40% height. Dark navy, rounded top corners 28pt. Handle bar. Title "How much to contribute?" Space Grotesk 26sp. Amount display "FRw 0" 48sp gold updates as typed. Quick chips: +1,000 +2,000 +5,000 +10,000 red glass pills. "Launch MOMO Dialer" red button. Note: "You'll confirm in MTN MOMO app."
```
</details>

<details><summary>6.2 MOMO USSD Confirm</summary>

```
Mobile MOMO USSD confirmation sheet 35% height. Dark navy. Title "Launching MOMO". USSD code "*182*8*1*5000*0788123456#" JetBrains Mono 18sp dark chip. Amount FRw 5,000 gold 32sp. Group label. Phone icon illustration. "Dial Now" red | "Cancel" outlined buttons.
```
</details>

<details><summary>6.3 Contribution Success</summary>

```
Mobile contribution success modal. Dark navy center. Animated mint green circle + white checkmark bounce. "Contribution Sent!" Space Grotesk 36sp. Amount gold. Group name. "+50 FET earned" red claymorphic badge. "View Ledger" outlined + "Done" red buttons. Red/gold confetti particles.
```
</details>

<details><summary>6.4 FET Level Up</summary>

```
Mobile FET level-up celebration full-screen overlay. Dark navy red/gold radial burst. Center: tier badge bouncing in (SILVER ULTRAS silver gradient glow). "LEVEL UP!" Space Grotesk ExtraBold 52sp. New tier name. FET total gold. Perks unlocked list. "Awesome!" red large button.
```
</details>

<details><summary>6.5 Badge Earned</summary>

```
Mobile badge earned modal. Dark navy overlay. Circular claymorphic badge expanding with gold glow ring. Badge name Space Grotesk 30sp. Description. "New Badge Unlocked" label. "Share" outlined + "Keep Going" red buttons. Particles animation.
```
</details>

<details><summary>6.6 Group Invite Code</summary>

```
Mobile share group invite bottom sheet 50% height. Dark navy. Header "Invite to Circle". Invite code "RF-4829-XK" JetBrains Mono 36sp gold on dark glass card. QR code of invite link 200pt. Share row: WhatsApp green · Copy Link · More. "Code valid for 7 days" note.
```
</details>

<details><summary>6.7 Ticket Purchase Confirm</summary>

```
Mobile ticket purchase confirmation sheet 55% height. Dark navy. Summary: match, zone, seat "C-14", quantity. Price: ticket FRw 3,000 + fee FRw 200, Total FRw 3,200 Space Grotesk 32sp gold. MOMO masked. "Confirm & Launch MOMO" red full-width. "Back" text link. Fine print.
```
</details>

<details><summary>6.8 Delete Account Confirm</summary>

```
Mobile delete account danger confirmation. Dark navy center modal. Large red warning triangle. "Delete your account?" Space Grotesk 26sp. Consequences body text. Safety gate: type "DELETE" input. "Cancel" gray full-width | "Delete Permanently" red full-width stacked.
```
</details>

<details><summary>6.9 SMS Permission Modal</summary>

```
Mobile SMS permission explanation. Dark navy. Phone + SMS badge icon. "Read your MOMO messages?" 26sp. Explanation: only MTN MoMo SMS read, never shared. "Allow SMS reading" toggle OFF default. "Enable" red | "Not Now" gray buttons.
```
</details>

<details><summary>6.10 Face Liveness Prompt</summary>

```
Mobile face liveness overlay on camera. Dark navy semi-transparent over camera preview. Blinking eye animation. "Please blink to confirm you're present" Space Grotesk 24sp. Countdown 3…2…1 gold. Progress bar. "Need help?" link.
```
</details>

<details><summary>6.11 NFC Pairing Sheet</summary>

```
Mobile NFC pairing in-progress sheet 40% height. Dark navy. Animated concentric mint rings from phone graphic. "Waiting for tap…" Space Grotesk 28sp. "Hold phones back-to-back." "Cancel" outlined. Countdown "30s" gold.
```
</details>

<details><summary>6.12 Filter & Sort Sheet</summary>

```
Mobile filter and sort bottom sheet 60% height. Dark navy. Header "Filter & Sort" + Reset. Sort radio pills: Newest · Oldest · Amount High · Amount Low. Date range FROM / TO glass inputs. Type filter multi-select chips. Amount range slider red thumb. "Apply Filters" red full-width. Active filters as removable red chips.
```
</details>

<details><summary>6.13 Notification Permission</summary>

```
Mobile notification permission request. Dark navy center card. Bell icon red badge. "Stay in the game" title. Benefits checklist 3 items. "Enable Notifications" red large. "Maybe Later" gray text link.
```
</details>

<details><summary>6.14 Sign Out Confirm</summary>

```
Mobile sign out confirmation sheet 35% height. Dark navy. "Sign out?" Space Grotesk 24sp. Note: "Your profile and FET are saved." "Sign Out" red outlined full-width | "Stay" red filled full-width stacked.
```
</details>

<details><summary>6.15 Group Privacy Settings</summary>

```
Mobile group privacy settings sheet 50% height. Dark navy. Header "Circle Privacy". Three option cards: PUBLIC globe "Anyone can join"; FRIENDS people "Invitees only"; PRIVATE lock "Invite code + approval". Selected = red border glow. "Save" red button.
```
</details>

---

## Summary

| Category | Count | Implemented | Partial | Missing |
|----------|-------|-------------|---------|--------|
| 1 · Onboarding | 5 | 5 | 0 | 0 |
| 2A · Home | 1 | 1 | 0 | 0 |
| 2B · Tickets | 5 | 5 | 0 | 0 |
| 2C · Shop | 3 | 3 | 0 | 0 |
| 2D · Gamification | 5 | 5 | 0 | 0 |
| 2E · Contributions | 8 | 8 | 0 | 0 |
| 2F · Membership | 2 | 2 | 0 | 0 |
| 2G · Fan Clubs | 3 | 3 | 0 | 0 |
| 2H · Live & News | 2 | 2 | 0 | 0 |
| 3 · BioPay | 5 | 5 | 0 | 0 |
| 4 · Settings | 6 | 6 | 0 | 0 |
| 5 · Admin | 5 | 5 | 0 | 0 |
| 6 · Popups & Modals | 15 | 15 | 0 | 0 |
| **TOTAL** | **65** | **65** | **0** | **0** |

> **All 65 screens are fully implemented.** ✅

### Recent Fixes Applied

| # | Screen | Fix |
|---|--------|-----|
| 6.6 | Group Invite Code | Enhanced with WhatsApp share, Copy, SMS share actions + 7-day validity note |
| 6.12 | Filter & Sort Sheet | Already existed in `core_theme/afri_filter_sheet.dart` — was miscategorized as missing |

### Feature Modules → Screen Count

| Module | Screens | Overlays | Total |
|--------|---------|----------|-------|
| `feat_onboarding` | 3 | 0 | 3 |
| `feat_home` | 1 | 0 | 1 |
| `feat_ticketing` | 5 | 1 | 6 |
| `feat_shop` | 3 | 0 | 3 |
| `feat_gamification` | 5 | 2 | 7 |
| `feat_contributions` | 8 | 6 | 14 |
| `feat_membership` | 2 | 0 | 2 |
| `feat_fan_clubs` | 3 | 0 | 3 |
| `feat_live` | 2 | 0 | 2 |
| `feat_biopay` | 5 | 2 | 7 |
| `feat_settings` | 6 | 4 | 10 |
| `feat_admin` | 5 | 0 | 5 |
| `core_theme` | 0 | 1 | 1 |
