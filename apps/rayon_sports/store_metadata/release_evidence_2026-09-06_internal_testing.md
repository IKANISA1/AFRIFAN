# Gikundiro 1.0.5 (8) internal-testing release evidence

## Candidate identity

- Source commit: `0e284032fd8b090e5265630d2e9d792451950b60`
- Android package: `rw.gikundiro.app`
- Version: `1.0.5` (`8`)
- Target SDK: `36`
- Signed AAB: `build/app/outputs/bundle/release/app-release.aab`
- AAB size: `150086195` bytes
- AAB SHA-256: `e20ce35509f6c36e2ba3181e4cbad7cdda1ae6532fc89d441d96b555aa609de4`
- Upload certificate: `18:0C:F8:B8:D4:F0:A5:A3:8D:51:D9:C9:E2:FF:51:23:FB:49:CD:CE:6D:93:BD:01:08:E1:D1:29:86:97:D5:10`

## Local validation

- The Android native-release validator passed the source permission check, launcher-icon check, merged-release-manifest check, AAB manifest check, and final AAB hash check.
- The Play metadata validator passed the English-only `en-US` package, copy limits, artwork, and Android package consistency checks.
- The bundle metadata embeds package `rw.gikundiro.app`, version name `1.0.5`, and version code `8`.

## Google Play result

- Console: <https://play.google.com/console/u/0/developers/8574763943591248082/app/4975567299527059359/tracks/4700902292187475822?tab=releases>
- Track: Internal testing
- Release name: `1.0.5 English-only update`
- Release notes locale: `en-US`
- Portal result observed on 2026-09-06: `Available to internal testers`, `1 version code`
- The previous draft bundle `4 (1.0.2)` was removed from the draft before publication.
- Production remains a separate release: `7 (1.0.4)` at 100% rollout as previously observed.

This evidence proves upload, Play processing, and publication to the internal-testing track. It does not prove production promotion, Google review approval, or public availability.
