# AfriClub Platform: nkana

This is an individual club application generated from the AFRICLUB monorepo architecture. 

## Multi-Tenant Architecture

This application acts as a "flavor" or "tenant" of the greater platform:
- **No Duplicate Business Logic**: All features (Ticketing, Contributions, Gamification, Shop) live in `packages/features/`.
- **Dynamic UI Tokens**: Colors and branding are not hardcoded. At bootstrap, the app retrieves its club name and semantic colors from `ClubConfig`, initializes `ColorTokens` under `DESIGN.md`, and renders the generated brand mark from those runtime tokens.
- **The White-Drop Rule**: To follow `DESIGN.md`, any club colors that are white or near-white are automatically dropped and replaced with system defaults so dark surfaces retain readable contrast.

## Building and Running

Because this app relies on the monorepo structure and dynamic configuration, do not run it like a standalone Flutter project.

To build or run this specific club's app, use the Melos commands from the root directory:

```bash
# Build the APK for this club
CLUB=nkana melos build_club
```

All backend data is scoped via the Supabase `club_id` column enforcing Row Level Security (RLS). You cannot read another club's data from this application.

For more details on the architecture, please refer to the root `README.md` and `docs/blueprint.md`.

