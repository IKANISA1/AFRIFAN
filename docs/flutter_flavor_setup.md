# Flutter Flavor Setup

AFRICLUB release builds now fail fast unless these runtime defines are present:

- `CLUB_ID`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `APP_DEEP_LINK_SCHEME`

The recommended workflow is to start from an example flavor file instead of
editing a tracked production config directly.

## Rayon Sports example

1. Copy `apps/rayon_sports/assets/flavors/production.example.json`
2. Save it as an untracked local file, for example:
   `apps/rayon_sports/assets/flavors/production.local.json`
3. Fill in the real backend values for your environment
4. Build or run with:

```bash
cd apps/rayon_sports
flutter run \
  --dart-define-from-file=assets/flavors/production.local.json

flutter build appbundle \
  --dart-define-from-file=assets/flavors/production.local.json
```

For another registered club, use its directory under `apps/` and the same
local-config workflow. The root `pubspec.yaml` lists the supported apps; do not
regenerate existing club shells with scaffolding scripts.

## Notes

- `apps/*/assets/flavors/*.local.json` is ignored by git for local use.
- `APP_WEBSITE_URL` powers verified `https://...` app links.
- `APP_DEEP_LINK_SCHEME` powers custom-scheme links such as
  `gikundiro://predict`.
- Tracked `production.json` / `staging.json` files are sanitized templates.
  Real backend values should be injected into `.local.json` files or CI
  generated overrides.
- If `CLUB_ID`, `SUPABASE_URL`, or `SUPABASE_ANON_KEY` are missing, app
  bootstrap now throws immediately instead of silently using baked-in
  fallbacks.
