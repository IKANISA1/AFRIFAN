# Isolated iOS QA build

The `qa` scheme exists only for local physical-device and simulator QA. It is
not a store or production scheme.

- Bundle identifier: `rw.ikanisa.rayonSports.qa.codex`
- Display name: `Gikundiro QA`
- Build configuration: `Debug-qa`
- Entitlements: `Runner/RunnerQA.entitlements` (empty by design)
- Production bundle identifier: `rw.ikanisa.rayonSports` (unchanged)

Build the isolated unsigned device bundle without installing it:

```sh
flutter build ios --debug --flavor qa --no-codesign
```

The build must report `Building rw.ikanisa.rayonSports.qa.codex`. Before any
physical install, inspect the built `Runner.app/Info.plist` and confirm the QA
bundle identifier and `Gikundiro QA` display name. Signing, provisioning and
physical installation remain separately controlled actions. Never install the
production bundle identifier as part of this QA workflow.

The QA configuration intentionally omits production push, App Attest and
associated-domain entitlements. Its Firebase configuration is not a separate
registered Firebase iOS application; integration tests use synthetic startup
options and must not be represented as authenticated production behavior.
