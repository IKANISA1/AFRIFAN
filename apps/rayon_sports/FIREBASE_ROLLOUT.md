# Rayon Sports Firebase Runtime Rollout

This runbook covers the remaining non-code rollout for the Rayon Sports Flutter app after the repo-side Firebase wiring was completed.

## Scope

The app now initializes Firebase from checked-in config and uses Firebase for:

- App Check client attestation in [app_check_service.dart](/Volumes/PRO-G40/AFRICLUB/packages/core/core_network/lib/src/app_check_service.dart)
- FCM token registration and push handling in [push_notification_service.dart](/Volumes/PRO-G40/AFRICLUB/packages/core/core_network/lib/src/push_notification_service.dart)
- Supabase Edge Function verification and sends in [app_check.ts](/Volumes/PRO-G40/AFRICLUB/supabase/functions/_shared/app_check.ts) and [fcm.ts](/Volumes/PRO-G40/AFRICLUB/supabase/functions/_shared/fcm.ts)

## Verified IDs

- Firebase project id: `gen-lang-client-0172279957`
- Firebase project number: `1074154147498`
- Android package: `rw.gikundiro.app`
- iOS bundle id: `rw.ikanisa.rayonSports`
- Supabase project ref: `mmpbzcdhfvplxplnfucy`

## 1. Create a dedicated runtime service account

Create a dedicated Firebase runtime service account in the Google Cloud project behind `gen-lang-client-0172279957`.

Recommended naming:

- `africlub-firebase-runtime@gen-lang-client-0172279957.iam.gserviceaccount.com`

Grant least-privilege roles:

- `roles/firebaseappcheck.tokenVerifier`
- `roles/firebasecloudmessaging.admin`

Why:

- Firebase App Check token verification requires `firebaseappcheck.appCheckTokens.verify`, which is included in `roles/firebaseappcheck.tokenVerifier`.
- FCM HTTP v1 sending requires the `Firebase Cloud Messaging API Admin` role.

Official references:

- Firebase App Check IAM roles: https://cloud.google.com/iam/docs/roles-permissions/firebaseappcheck
- FCM HTTP v1 auth and role guidance: https://firebase.google.com/docs/cloud-messaging/send/v1-api#authorize-http-v1-send-requests

## 2. Generate the local Supabase runtime env file

From the repo root:

```bash
bash tools/scripts/provision_firebase_runtime.sh \
  --service-account-file /absolute/path/to/firebase-service-account.json
```

This generates:

- `supabase/.env.firebase.local`

That file contains:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_SERVICE_ACCOUNT_JSON`

It is ignored by git.

## 3. Validate locally

```bash
FIREBASE_ENV_FILE=supabase/.env.firebase.local \
  bash tools/scripts/validate_biopay_firebase.sh rayon_sports
```

Expected result:

- Android/iOS Firebase config files are present and point to the same Firebase project
- The runtime service account JSON is valid

## 4. Push secrets to Supabase

If your Supabase CLI account has secrets permissions on project `mmpbzcdhfvplxplnfucy`:

```bash
bash tools/scripts/provision_firebase_runtime.sh \
  --service-account-file /absolute/path/to/firebase-service-account.json \
  --push-supabase
```

If that fails with a permissions error, use the Supabase dashboard or a privileged account to set:

- `FIREBASE_PROJECT_ID=gen-lang-client-0172279957`
- `FIREBASE_SERVICE_ACCOUNT_JSON=<minified JSON string>`

## 5. Enable Android App Check in Firebase Console

Open the Firebase console for `gen-lang-client-0172279957` and register the Android app for App Check with the Play Integrity provider.

Use:

- Android app: `rw.gikundiro.app`
- SHA-256 fingerprint of the signing certificate used for release distribution

Required actions:

1. In Google Play Console, open the app.
2. Open `Release` -> `App integrity`.
3. In the `Play Integrity API` section, link the same Google Cloud/Firebase project.
4. In Firebase Console -> `App Check`, register the Android app with `Play Integrity`.
5. Add the SHA-256 certificate fingerprint.
6. Keep enforcement off until a production app build is confirmed to mint valid App Check tokens.

Official reference:

- https://firebase.google.com/docs/app-check/android/play-integrity-provider

## 6. Enable Apple App Check in Firebase Console

Open Firebase Console -> `App Check` and register the iOS app:

- iOS app: `rw.ikanisa.rayonSports`
- Provider: `App Attest`

Rollout approach:

1. Register the iOS app with `App Attest`.
2. Keep enforcement off initially.
3. Verify a real device build can mint App Check tokens.
4. Enable enforcement only after successful smoke testing.

Official reference:

- App Check overview: https://firebase.google.com/docs/app-check

## 7. Upload APNs credentials for iOS FCM

Before iOS push delivery can work, upload an APNs authentication key in Firebase Console:

1. Firebase Console -> `Project settings`
2. `Cloud Messaging` tab
3. Under `APNs authentication key`, upload the `.p8` key
4. Supply the Apple Key ID and Team ID

Repo-side prerequisites already completed:

- `GoogleService-Info.plist` added to the Runner target
- `remote-notification` background mode enabled
- iOS deployment target raised to `15.5`

Apple-side prerequisites still required:

- Xcode target capability: `Push Notifications`
- Signing/provisioning profile with push enabled

Official reference:

- https://firebase.google.com/docs/cloud-messaging/flutter/get-started
- https://firebase.google.com/docs/cloud-messaging/ios/first-message

## 8. Smoke test after rollout

### Android

1. Install a release-capable build on a physical device.
2. Sign in.
3. Trigger a BioPay flow that calls a protected Supabase Edge Function.
4. Confirm requests include `X-Firebase-AppCheck` and are accepted.

### iOS

1. Install a physical-device build.
2. Sign in and grant notifications.
3. Confirm the app writes a token into `user_fcm_tokens`.
4. Trigger a server-side notification and verify delivery.

## 9. Enforcement sequence

Do not enable enforcement on day one.

Recommended order:

1. Android App Check registration complete
2. iOS App Check registration complete
3. Service account secrets present in Supabase
4. Physical-device smoke tests pass
5. Enable App Check enforcement for the relevant backend resources
6. Monitor failed requests before expanding enforcement further
