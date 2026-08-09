# Gikundiro TV Google Play Fastlane package

These lanes validate the TV package before upload and never bypass pending
artwork, policy, portal, or approval gates.

```sh
bundle exec fastlane android validate_metadata
bundle exec fastlane android internal
bundle exec fastlane android metadata
CONFIRM_PLAY_TV_PROMOTION=tv-alpha bundle exec fastlane android promote destination:alpha
```

Set `PLAY_STORE_TV_SERVICE_ACCOUNT_JSON_PATH` to a secret-managed local/CI file.
Do not commit service-account JSON, signing material, passwords, one-time codes,
reviewer credentials, pairing codes, or device credentials. `internal` creates a
draft; it does not establish approval or publication. Promotion to production
uses the stronger `--submission-ready` gate.
