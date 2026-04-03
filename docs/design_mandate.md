### **The Design Mandate**

The refactoring is governed by five non-negotiable design mandates:

* FOOTBALL-FIRST — Every pixel must feel like the pitch. Motion, color, typography and tone must radiate sport, power, and belonging.

* RADICAL MINIMALISM — One action per screen. No noise. No redundancy. The UI reveals itself progressively as users need it.

* GLASSMORPHIC AUTHORITY — Frosted glass panels over deep gradients using **dynamic club colors** (`ColorTokens.clubPrimary` / `ColorTokens.clubSecondary`). Soft depth with maximum authority. Supports Light, Dark, and System modes.

* CLAYMORPHIC INTERACTION — Rounded, soft 3D touch-feel for buttons, cards, avatars and gamification elements. Tactile without being childish.

* ANONYMOUS-FIRST PRIVACY — Users are anonymous by default. No real name ever displayed publicly. A 6-digit numeric alias governs all social visibility.

## **What We Are (Design Rules)**

* ADAPTIVE UI — Seamlessly adapts to System, Light, and Dark modes while retaining the physical stadium energy.

* DYNAMIC CLUB COLORS — Every club has its own brand palette injected via `ColorTokens.init(ClubConfig.colors)` at startup. **No hardcoded color hex values** in any feature widget. The `white-drop rule` automatically filters out white/near-white club colors and replaces them with design system defaults.

* ONE PRIMARY ACTION PER SCREEN — No screen has more than one hero CTA. Complexity hides behind progressive disclosure.

* GLASS OVER GRADIENT — Glass surfaces always float over a rich gradient (`ColorTokens.heroGradient()`) or blurred background. Never glass-on-white.

* MAXIMUM FONT SIZE — Body text minimum 15sp. Hero text minimum 32sp. No squinting.

* HERO SECTION HEIGHT — Hero section images, content, and container must take exactly 1/4 of the height of the home screen.

* HAPTIC ON EVERY TAP — HapticFeedback.lightImpact for all button presses. Heavier for achievements and contributions.

* ALIAS EVERYWHERE — The numeric 6-digit alias replaces name in 100% of public UI surfaces.

* REAL-TIME BY DEFAULT — Contribution ledgers, group chats, and scores use Supabase Realtime. Pull-to-refresh is a fallback only.

## **Dynamic Color Token Architecture**

| Token | Description | Source |
|-------|-------------|--------|
| `ColorTokens.clubPrimary` | Club's main brand color | `ClubConfig.colors.primary` → `african_football_clubs.primary_color_hex` |
| `ColorTokens.clubSecondary` | Secondary / gradient base | `ClubConfig.colors.secondary` → `african_football_clubs.secondary_color_hex` |
| `ColorTokens.clubAccent` | Highlight / emphasis | `ClubConfig.colors.accent` → `african_football_clubs.accent_color_hex` |
| `ColorTokens.navActive` | Auto-derived pastel tint | HSL lightened from `clubPrimary` |
| `ColorTokens.heroGradient()` | Signature gradient | `clubSecondary → clubPrimary` at 135° |

**Legacy aliases** (`clubRed`, `deepNavy`, `trophyGold`) resolve to `clubPrimary`, `clubSecondary`, `clubAccent` respectively.

## **What We Are NOT (Anti-Patterns to Eliminate)**

* NO emoji as navigation icons — Use proper semantic icons from the design system.

* NO raw `#000000` — Pure black breaks the tint. All dynamic background tokens must strictly be used.

* NO hardcoded hex colors — Use `ColorTokens.*` getters exclusively. Never `Color(0xFF...)` in feature code.

* NO white as a club accent color — The white-drop rule (`luminance > 0.9`) auto-filters this.

* NO text walls — Descriptions max 2 lines.

* NO full-screen loading spinners — Skeleton shimmer states only.

* NO multiple CTAs competing on same screen

* NO modal stacking — Maximum one modal/sheet at a time.

* NO real name collection — Profile setup asks only for MOMO number

All screen design must reference the Home screen UI/UX design and the [Design.md](Design.md) file.