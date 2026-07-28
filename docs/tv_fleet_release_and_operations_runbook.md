# Native TV Fleet Release and Operations Runbook

Owner: TV Fleet Operations  
Release owner: Android Release Manager  
Technical escalation: Backend/Mobile On-call  
Review cadence: every TV release and quarterly

## Distribution and signing

- Distribute through a managed Play private channel or approved MDM, never an ad-hoc debug APK.
- Release builds require external `TV_ANDROID_*` signing inputs or an untracked `keystore.properties`; the repository intentionally has no release-key fallback.
- CI stores the upload key as protected secrets. Record the upload/app-signing certificate SHA-256 fingerprints in the restricted release register and verify every AAB before upload.
- Use Play App Signing where available. Document key rotation/recovery owners and test recovery annually.

## Provisioning

1. Create an 8–32 character random one-time pairing code in the authenticated admin games console.
2. Enter it on the TV within 15 minutes. The app exchanges it once for a 256-bit credential stored in Android encrypted storage.
3. Confirm admin shows the device ID/last-seen state and the TV shows the correct runtime venue—not a compile-time venue.
4. Never put device IDs, pairing codes, or credentials in build arguments, screenshots, tickets, analytics, or logs.

## Fleet controls

- Revoke a device immediately when lost, replaced, reassigned, or suspected compromised. A revoked TV returns to pairing.
- Rotate by revoking the old credential and issuing a new one-time pairing code.
- Review last-seen inventory before matchday; investigate devices stale for more than 24 hours.
- The display refreshes every 20 seconds, refreshes on app resume, backs off to 80 seconds on failures, shows last-updated/connection state, and provides a focused remote retry action.

## Acceptance matrix

- 720p, 1080p, and 4K landscape; overscan-safe area; long venue/session names; expired code; no campaign/session.
- Cold start, background/resume, network loss/recovery, backend error, revoked credential, and pairing expiry.
- D-pad focus traversal and retry activation with no touch input.
- No identity, phone/email, balances, orders, device credential, or pairing code in diagnostics.
- Soak for four hours to check memory, thermal behavior, burn-in risk, stale display, crash, and ANR.

## Monitoring and incident response

- Monitor crash-free sessions, ANR rate, pairing failures, credential rejection, refresh latency/error rate, and stale-device count without personal data.
- SEV-1 credential compromise: revoke immediately, disable device, preserve audit event, rotate code, and notify security owner within 10 minutes.
- Backend outage: keep last known screen-safe state visibly marked disconnected, use retry/backoff, and do not invent a valid join code.

Production launch requires a signed AAB fingerprint, managed-track install proof, representative-device screenshots, remote-control checklist, crash/ANR dashboard link, and named owner sign-off.

