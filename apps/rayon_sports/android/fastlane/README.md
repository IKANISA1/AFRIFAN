# Gikundiro Google Play Fastlane package

The lanes keep authentication outside the repository and validate the controlled
store package before any upload. Validation alone does not mean Google has
accepted the app.

```sh
bundle exec fastlane android validate_metadata
bundle exec fastlane android internal
bundle exec fastlane android metadata
```

`internal` uploads the exact release AAB, metadata, localized changelogs, and
artwork as a draft. `metadata` uploads approved listing material without an AAB.
Both use the stronger `--release-ready` gate and therefore fail while artwork,
portal values, classifications, or approvals are pending.

The production promotion lane uses `--submission-ready`, which additionally
requires processed-artifact, questionnaire, reviewer-access, and submission
evidence recorded in the portal-values file.

Promotion is intentionally explicit:

```sh
CONFIRM_PLAY_PROMOTION=closed bundle exec fastlane android closed
CONFIRM_PLAY_PROMOTION=production bundle exec fastlane android production
```

Set `PLAY_STORE_SERVICE_ACCOUNT_JSON_PATH` to a local or CI secret-managed JSON
file. Never commit the service-account JSON, passwords, one-time codes, signing
keys, or reviewer credentials. Portal questionnaires and reviewer access remain
authenticated-console work governed by the package checklists.
