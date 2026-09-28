# Native QA configuration and bundle validation

This is the native execution guide for QA-04 in [the full-stack QA plan](full_stack_qa_plan.md). Source configuration, resolved Xcode/Gradle settings, compiled artifacts, installed apps, physical-device performance, provider checks and store release acceptance require separate evidence.

All five club shells expose separate native identities. Costa do Sol's current
`mz.ikanisa.costadosol` identifiers are provisional local build identifiers;
approved release registration is pending.

| Platform | QA selection | Identity and behavior |
| --- | --- | --- |
| Android | Debug/profile with Gradle property `africlubDebugApplicationIdSuffix=.qa.codex` | Appends the suffix to that club's declared application ID; app version gains `-isolated-qa`. Explicit release requests and aggregate task graphs containing release tasks reject the suffix. |
| iOS | Shared `qa` scheme, `Debug-qa` | Uses that club's production bundle ID plus `.qa.codex`, a display name ending in `QA`, debug Flutter mode and empty QA entitlements. |
| iOS | Shared `qa` scheme, `Profile-qa` | Uses the same QA ID, profile Flutter mode and empty QA entitlements. The scheme's Profile action selects this configuration. |

The iOS QA targets set `SKIP_INSTALL=YES`; the QA scheme excludes archive builds and has no `Release-qa` configuration. The production scheme and application IDs remain unchanged. The nineteen CocoaPods shells now have their missing Flutter base configuration files and framework plist, with iOS 15.5 matching the repository release contract. Their Podfiles explicitly map both QA configurations. Rayon retains its Swift Package Manager integration.

Native identity separation does not select a test backend or disable provider SDKs. Before launching an app, use reviewed synthetic/local Dart defines with the correct club ID and controlled backend URL, inspect generated Flutter configuration for stale checkout or test-target paths, and verify that provider traffic is disabled or directed to an authorized test account. Do not use the production JSON for isolated backend QA. Firebase registration, push/App Check, privacy declarations and approved app icons remain separate per-club release prerequisites.

Run the source guards with:

```sh
node tools/scripts/validate_mobile_qa_isolation.mjs
node tools/scripts/validate_ios_qa_isolation.mjs
node --test tools/scripts/native_qa_isolation.test.mjs
```

They check configuration relationships and reject common isolation regressions. On macOS, resolve each configuration with `xcodebuild -showBuildSettings -json` before compilation. Retain only allowed public settings in QA evidence: full build settings can include encoded Dart defines containing provider values. Profile configuration is not proof of a profile artifact or physical-device performance.

## Android bundle inspector

The release entrypoints require Google bundletool 1.18.1 before starting build or signing work. Prepare the official JAR at a task-owned path and set `BUNDLETOOL_JAR`:

```sh
python3 tools/scripts/prepare_bundletool.py /absolute/task-owned/path/bundletool.jar
export BUNDLETOOL_JAR=/absolute/task-owned/path/bundletool.jar
node tools/scripts/android_release_contract.mjs toolchain
node --test tools/scripts/android_release_contract.test.mjs
```

Java must be available through `JAVA_HOME` or `PATH`. An existing reviewed Gradle classpath can instead be supplied as `BUNDLETOOL_CLASSPATH`; do not set both variables. A `bundletool` executable on `PATH` is also supported. All forms must report the pinned version.

The installer checks the official release against SHA-256 `675786493983787ffa11550bdb7c0715679a44e1643f3ff980a529e9c822595c`. It refuses an existing file with another digest. The [official bundletool source](https://github.com/google/bundletool/tree/1.18.1) and [Android command-line guide](https://developer.android.com/build/building-cmdline) document the bundle format and inspection tool.

The release contract checks Gradle sidecars, validates the actual AAB with bundletool, reads its embedded base manifest, compares package/version values and records a SHA-256 while checking that the file stays unchanged. A structural/identity pass does not certify signing, installed behavior or store acceptance. Its tests use small synthetic, codeless protobuf bundles; those files are not compiled club apps.

The all-club dry-run resolves the selected club's application ID instead of requiring Rayon's. Every club honors the dry-run signing environment before local keystore properties, so its ephemeral credentials take precedence. No production keystore file is modified by this configuration repair.
