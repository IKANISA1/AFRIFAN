# Design System Documentation: Kinetic Football Authority

## 1. Overview & Creative North Star
**Creative North Star: "The Stadium Pulse"**
This design system is engineered to capture the high-stakes atmospheric tension of a stadium tunnel before kickoff. It moves away from generic "app-like" layouts toward a cinematic, editorial experience that feels heavy, intentional, and athletic.

The aesthetic is driven by **Kinetic Energy**. We break the traditional grid through radical typography scales and a "Glass-on-Pulse" layering strategy. By combining the technical precision of Glassmorphism with the tactile, physical feedback of Claymorphism, we create a UI that feels like a premium sports instrument rather than a static interface.

## 2. Color & Atmospheric Depth

### 2.1 Dynamic Club Color System

**Colors are NOT hardcoded.** Every club in the AfriClub platform has its own brand colors stored in the Supabase `african_football_clubs` table and injected at app startup via `ColorTokens.init(ClubConfig.colors)`.

**Architecture:**
- **Platform constants** (background, surface, glass, semantic) are identical across all 50+ clubs and remain compile-time `const`.
- **Club-specific tokens** (`clubPrimary`, `clubSecondary`, `clubAccent`, `navActive`, `heroGradient`) are initialized ONCE at startup from `ClubColors` via `ColorTokens.init()`.

**Color token mapping:**

| Token | Resolves to | Example (Rayon Sports) | Example (Simba SC) |
|-------|-------------|------------------------|---------------------|
| `ColorTokens.clubPrimary` | Club's main brand color | `#0038A8` (Blue) | `#CC0000` (Red) |
| `ColorTokens.clubSecondary` | Club's secondary / gradient base | `#001F5C` (Deep Blue) | Design default |
| `ColorTokens.clubAccent` | Highlight / trophy / emphasis | `#D4A017` (Gold) | `#FFD700` (Gold) |
| `ColorTokens.navActive` | Auto-derived pastel of primary | Light blue tint | Light red tint |
| `ColorTokens.heroGradient()` | secondary → primary at 135° | Deep Blue → Blue | Default → Red |

**Legacy aliases** (`clubRed`, `deepNavy`, `trophyGold`) delegate to the dynamic getters above. All existing widget code continues to work without changes.

**White-drop rule:** If any club color is white or near-white (luminance > 0.9), it is automatically replaced with the design system default for that slot. White colors break the dark-mode UI and are never used as accent/UI colors.

### 2.2 Surface Hierarchy (Platform Constants)

The palette is rooted in the deep shadows of a midnight stadium, punctuated by high-velocity club-specific accents.

* **The "No-Line" Rule:** Direct structural lines are prohibited. To separate sections, use background shifts. A section utilizing `surface-container-low` should sit adjacent to the base `surface` to define boundaries.
* **Surface Hierarchy:** Depth is achieved through "Nesting."
  * Base Layer: `background` (`#0C112E`).
  * Secondary Content: `surface-container-low`.
  * Interactive Elements: `surface-container-high`.
* **The Glass Mandate:** Cards must utilize Glassmorphism to maintain the "Kinetic" feel.
  * **BackdropFilter Blur:** 12px.
  * **Fill:** White at 0.06 opacity.
  * **Border:** White at 0.15 opacity (The "Ghost Border").
* **Signature Textures:** Use linear gradients for hero backgrounds transitioning from `ColorTokens.clubSecondary` to `ColorTokens.clubPrimary` at a 135-degree angle to simulate movement. **Never hardcode hex values — always use the dynamic token getters.**
* **Hero Section Sizing:** Hero section images, content, and container must take exactly 1/4 of the height of the home screen.

### 2.3 Initialization Flow

```dart
// In every app's bootstrap.dart:
Future<void> bootstrap(ClubConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  // ...orientation lock...

  // ── MUST happen before any widget code ──
  ColorTokens.init(config.colors);

  // ...supabase init, etc...
  runApp(AfriClubApp(config: config, modules: modules));
}
```

### 2.4 Club Color Data Source (Supabase)

All club colors are stored in `african_football_clubs`:

| Column | Type | Example |
|--------|------|---------|
| `primary_color_hex` | `TEXT` | `#0038A8` |
| `secondary_color_hex` | `TEXT` | `#001F5C` |
| `accent_color_hex` | `TEXT` | `#D4A017` |

These are loaded into `ClubConfig.colors` at compile time and passed to `ColorTokens.init()`.

## 3. Typography: Radical Minimalism
Hierarchy is communicated through extreme scale. We prioritize "Barlow Condensed" for its athletic, high-density feel and "Inter" for technical clarity.

* Scale up to `display-lg` (3.5rem) for primary data points.
* **Titles (Barlow Condensed):**
  * Use **Bold 700** for screen headers.
  * Headlines should be "All Caps" to reinforce authority.
* **Body & Meta (Inter):**
  * **SemiBold 600** for sub-headers and button labels.
  * **Regular 400** for descriptions.
* **Anonymous Identity:** Never design for names. All layouts must be optimized for 6-digit numeric aliases (e.g., `882-941`). These should be treated with the same typographic weight as primary headlines.

## 4. Elevation & Tactile Depth
We move beyond flat design by utilizing **Claymorphic Interaction** for primary touchpoints and **Tonal Layering** for structure.

* **Claymorphic Tactility:** Buttons and badges must feel like physical objects.
  * **Primary Action:** `ColorTokens.clubPrimary` background (dynamic per club).
  * **Top-Left Inner Shadow:** `white` at 20% opacity, 2px blur, offset 2px.
  * **Bottom-Right Inner Shadow:** `black` at 30% opacity, 4px blur, offset 4px.
* **Ambient Shadows:** For floating glass cards, use a diffused shadow: `rgba(7, 11, 40, 0.8)` with a 40px blur. Avoid grey shadows; always tint shadows with the `surface_container_lowest` hue.
* **The Ghost Border:** For accessibility on glass cards, use the `outline_variant` token at 15% opacity. Never use 100% opaque borders.

## 5. Components

### Primary Buttons (Claymorphic)
* **Style:** High-radius (`full` 9999px), `ColorTokens.clubPrimary` fill (dynamic per club).
* **Animation:** On press, the dual inner shadows invert to simulate a physical "press-in."
* **Constraint:** Only one Primary Button per view to maintain Radical Minimalism.

### Glass Cards
* **Style:** `xl` (1.5rem) corner radius.
* **Structure:** No internal divider lines. Use `spacing-6` (2rem) to separate internal content blocks.
* **Visuals:** Must float over a dynamic gradient background (`ColorTokens.heroGradient()`) to maximize the blur effect.

### Interactive Lists
* **Style:** Transparent backgrounds with `surface-container-highest` backgrounds on the active state.
* **Dividers:** Strictly forbidden. Use a vertical `spacing-2` (0.7rem) gap between list items to create separation.

### Bottom Navigation
* **Mandate:** Icon-only by default.
* **Interaction:** On press, the icon scales up (1.2x), the `label-md` appears below it, and a haptic "pop" is triggered. Use `ColorTokens.navActive` (auto-derived pastel tint of club primary) for the active state icon.

### Numeric Aliases (Identity Badges)
* **Style:** Monospaced-style tracking for the 6-digit numbers.
* **Container:** Glassmorphic pill with `sm` (0.25rem) radius.

## 6. Do's and Don'ts

### Do:
* **Do** use `Barlow Condensed` at massive scales for numbers to create an "Editorial Sports" look.
* **Do** rely on `spacing-8` and `spacing-10` to create breathing room between high-contrast elements.
* **Do** ensure all "Primary Actions" use the dual-inner-shadow Claymorphic style.
* **Do** use the "Ghost Border" (low opacity) exclusively for container boundaries.
* **Do** use `ColorTokens.clubPrimary` / `.clubAccent` — never hardcode hex color values.
* **Do** call `ColorTokens.init(config.colors)` in bootstrap before any widget renders.

### Don't:
* **Don't** use 1px solid, high-contrast borders or dividers.
* **Don't** include labels in the bottom navigation's idle state.
* **Don't** use standard "Drop Shadows." All depth must be Tonal (background shift) or Claymorphic (inner shadows).
* **Do** use responsive themes that adapt to system, light, and dark modes smoothly.
* **Don't** hardcode any hex color value (e.g., `Color(0xFFC8102E)`) in feature widgets — always use `ColorTokens.*` getters.
* **Don't** use white (`#FFFFFF`) as any club accent color — the white-drop rule filters this automatically.
