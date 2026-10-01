# Rayon Sports / Gikundiro

Reference Flutter supporter app for the AFRICLUB workspace. Shared behavior
lives in `packages/core` and `packages/features`; club identity is provided by
`packages/clubs/club_rayon_sports` and runtime configuration.

Resolve dependencies from the repository root:

```bash
flutter pub get
```

Then run from this directory with your ignored local configuration:

```bash
flutter run --dart-define-from-file=assets/flavors/production.local.json
flutter build appbundle --dart-define-from-file=assets/flavors/production.local.json
```

See [flavor setup](../../docs/flutter_flavor_setup.md), the
[release checklist](../../docs/rayon_sports_release_checklist.md), and
[store metadata](store_metadata/README.md). The [web application](web/README.md)
contains the public site, membership access and admin PWA.

[Architecture](../../docs/blueprint.md) governs product ownership;
The selected `revolut-design` skill is the sole presentation authority;
[DESIGN.md](../../DESIGN.md) records product mappings only.
