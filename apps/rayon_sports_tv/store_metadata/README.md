# Gikundiro TV store-delivery package

This directory is the source-controlled preparation pack for the Android TV
listing. It records verified code facts, draft answers, artwork requirements,
reviewer guidance, portal-only values, and accountable approvals. Internal
testing is the recorded pre-production stage; it must not be represented as
public submission, review approval, staged production release, or publication.

Run the code-owned gate from this directory:

```sh
python3 ../../rayon_sports/store_metadata/validate_store_package.py --tv-only
```

The stronger `--release-ready` pre-upload mode is used by upload lanes and
intentionally fails until artwork, pre-upload portal values, policy decisions,
and named approvals are complete. `--submission-ready` additionally requires
processed-artifact and portal-form evidence before promotion/submission. Do not
commit Play credentials, passwords, one-time codes,
identity evidence, private keys, real pairing codes, or device credentials.

The intended distribution is a public Google Play TV listing. Internal testing
is the current pre-production stage. Public-track promotion still requires the
named distribution, product, rights, audience, privacy, device, language, and
release-owner approvals plus authenticated portal evidence.

The prepared media set now satisfies the code-owned default listing inventory:
a 512x512 app icon, 1024x500 feature graphic, 1280x720 Android TV banner, and
two 1920x1080 genuine AVD screenshots. This inventory is not evidence that the
assets were uploaded, approved, or rendered from a Play-delivered build.

The current production content locale is Kinyarwanda with English fallback for
platform-provided text; there is no user-selectable TV locale. English and
French store translations must not be represented as proof of runtime language
selection. Kinyarwanda source copy is kept outside Fastlane because Play does
not currently accept that listing language.
