# AfriClub Platform: nkana

This is an individual club application generated from the AFRICLUB monorepo architecture. 

## Multi-Tenant Architecture

This application acts as a "flavor" or "tenant" of the greater platform:
- **No Duplicate Business Logic**: All features (Ticketing, Contributions, Gamification, Shop) live in `packages/features/`.
- **Dynamic Design System**: Colors and branding are not hardcoded. At bootstrap, the app retrieves its specific branding (Primary, Secondary, Accent colors, Crest) from `ClubConfig`, and initializes the `ColorTokens` system.
- **The White-Drop Rule**: To adhere to the Revolut-Borrowed (dark-mode only) design language, any club colors that are white or near-white are automatically dropped and replaced with system defaults. This ensures that the glassmorphism and deep gradients render perfectly.

## Building and Running

Because this app relies on the monorepo structure and dynamic configuration, do not run it like a standalone Flutter project.

To build or run this specific club's app, use the Melos commands from the root directory:

```bash
# Build the APK for this club
CLUB=nkana melos build_club
```

All backend data is scoped via the Supabase `club_id` column enforcing Row Level Security (RLS). You cannot read another club's data from this application.

For more details on the architecture, please refer to the root `README.md` and `docs/blueprint.md`.

