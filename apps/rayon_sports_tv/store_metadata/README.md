# Gikundiro TV store-delivery package

This directory is the source-controlled preparation pack for the Android TV
listing. It records verified code facts, draft answers, artwork requirements,
reviewer guidance, portal-only values, and accountable approvals. It does not
claim that an AAB was uploaded, reviewed, approved, or released.

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

The current packaging decision is managed/private distribution. A public TV
release is a separate accountable decision because it changes audience,
discoverability, content-rights, and moderation exposure.

The current production content locale is Kinyarwanda with English fallback for
platform-provided text; there is no user-selectable TV locale. English and
French store translations must not be represented as proof of runtime language
selection. Kinyarwanda source copy is kept outside Fastlane because Play does
not currently accept that listing language.
