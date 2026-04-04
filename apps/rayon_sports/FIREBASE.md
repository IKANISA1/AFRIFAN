# Firebase Setup

Firebase project bound to this app:

- Project ID: `gen-lang-client-0172279957`
- Project number: `1074154147498`

Configured app registrations:

- Android package: `rw.gikundiro.app`
- iOS bundle ID: `rw.ikanisa.rayonSports`
- Web app ID: `1:1074154147498:web:bd48c4578e35ab4bdc4ad3`

Native build requirements applied in the repo:

- iOS deployment target: `15.5`
- Android package wired through `android/app/google-services.json`
- iOS `GoogleService-Info.plist` added to the Runner target resources
- Flutter bootstrap uses checked-in `lib/firebase_options.dart`

Repo-managed client config:

- Android: [android/app/google-services.json](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/android/app/google-services.json)
- iOS: [ios/Runner/GoogleService-Info.plist](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/ios/Runner/GoogleService-Info.plist)
- Flutter options: [lib/firebase_options.dart](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/lib/firebase_options.dart)
- Firebase CLI alias: [\.firebaserc](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/.firebaserc)

Server-side secrets still required for BioPay App Check and FCM delivery:

- `FIREBASE_PROJECT_ID=gen-lang-client-0172279957`
- `FIREBASE_SERVICE_ACCOUNT_JSON=<service account JSON>`

Validation command:

```bash
bash tools/scripts/validate_biopay_firebase.sh rayon_sports
```

Provisioning command for Supabase Edge Function runtime secrets:

```bash
bash tools/scripts/provision_firebase_runtime.sh \
  --service-account-file /absolute/path/to/firebase-service-account.json
```

Without `FIREBASE_SERVICE_ACCOUNT_JSON`, client initialization can work, but backend App Check verification and FCM HTTP v1 delivery cannot be fully validated.

Console-level setup that still must be done outside the repo:

- Enable Firebase App Check for Android using `Play Integrity`
- Enable Firebase App Check for Apple platforms using `App Attest`
- Upload APNs authentication key or certificate in Firebase Cloud Messaging for iOS push delivery
- Provide a service account JSON to the backend runtime for App Check verification and FCM server sends

Build verification completed from this repo:

- `flutter build apk --debug` succeeded
- `flutter build ios --release --no-codesign` succeeded

Known limitation during local verification:

- `flutter build ios --simulator --no-codesign` fails because the existing ML Kit dependency graph links device-only MLKit binaries for simulator builds. That is an ML Kit simulator constraint, not a Firebase integration issue.

Operational rollout details:

- [FIREBASE_ROLLOUT.md](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/FIREBASE_ROLLOUT.md)
