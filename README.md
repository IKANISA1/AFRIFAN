# AFRICLUB PLATFORM

**White-Label African Football Super-App**  
*Multi-Tenant · One Repo · 50+ Club Apps*

AFRICLUB Platform is a white-label, multi-tenant African football fan super-app built on a single Flutter monorepo and one Supabase backend project. Instead of building isolated apps per club, AFRICLUB provides each club with a fully personalised app — unique branding, crest, colors, MOMO codes, and club identity — while sharing 100% of the underlying architecture, codebase, features, and infrastructure.

## Architecture & Tenancy

1. **One Full-Stack Monorepo (Melos)**: Contains core networking, routing, design system, and feature packages.
2. **One Backend (Supabase)**: Single database and Auth project handles all 50+ clubs.
3. **Multi-Tenant via `club_id`**: Every row in the database belongs to a club. Users are automatically assigned a `club_id` claim in their JWT at login, and Postgres Row Level Security (RLS) policies completely isolate data between clubs.
4. **App Delivery (Flutter Flavors)**: 50+ distinct production apps are built via Flutter dart-define compile-time arguments.

## Dynamic Design System (ColorTokens)

The entire custom UI uses a dual-layer architectural design system:
- **Platform Constants**: The core layout logic, typography scales (Barlow Condensed, Inter), glass card parameters (12px blur, 0.06 fill), and deep space stadium navy (`#0C112E`) background are constant across all clubs.
- **Club-Specific Dynamic Colors**: The "Club Red" era is over. The UI is completely dynamic based on `african_football_clubs` Supabase data. Primary, Secondary, and Accent colors are fetched at startup via `ClubConfig.colors` and seeded into the singleton `ColorTokens.init()`. 

**The White-Drop Rule**
Because this is a Dark Mode Only UI designed to radiate "stadium pulse authority", white backgrounds and primary elements are banned. If a club's brand color has a luminance > 0.9 (white or near-white), `ColorTokens.init()` automatically drops it and replaces it with a dark mode safe default.

### Component Styling
Never hardcode colors in UI features. Always use the token getters:
- `ColorTokens.clubPrimary`: The main club brand color.
- `ColorTokens.clubSecondary`: Sub-brand color, used for base gradients.
- `ColorTokens.clubAccent`: High-energy highlight.
- `ColorTokens.heroGradient()`: Generates a 135-degree sweep from secondary to primary.
- `ColorTokens.navActive`: Dynamically generated pastel of the primary color to guarantee active-tab contrast.

## Developer Rules

Before contributing, read:
1. `RULES.md` - Mandatory compliance guidelines.
2. `docs/design.md` - The Kinetic Football Authority aesthetics constraints.
3. `docs/blueprint.md` - Architectural ADAs and module boundaries.
4. `1supabase.md` - The multi-tenant database infrastructure maps.

*Confidential & Proprietary — IKANISA Ltd.*
