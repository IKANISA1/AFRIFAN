# AFRICLUB — Batch 10 native checkout and explicit payment handoff

27 September 2026 (Africa/Kigali). Authoritative workspace:
`1izZgoOKfEONHZTyHkE0MzBW9Eeo4-VeH` / `/Google Drive/AFRICLUB`.

## 1. Delivered state and boundary

**Twenty-one source changes are saved individually at the intended Google Drive
paths: twenty additions and one in-place gateway README update.** The README keeps
ID `1ZMOX3aVmWujKCYV_YahrkQ5NPbFXuY7h`. Its current original was checked immediately
before replacement and the before-source archive was uploaded and hash-verified.
All 21 saved source files were downloaded and matched the tested local SHA-256
values. A reconstruction using those bytes reports zero outstanding source changes.

**825 targeted tests passed:** 792 Node tests and 33 inherited installer/rollback
regressions. This total includes 123 new tests. The downloaded source independently
passed the same 792 Node tests; that repeat is not double-counted.

**Dart, Flutter and physical-device verification did not run.** The SDK was absent,
and an attempted official SDK download was unavailable in this environment. The
native verifier records `blocked`, `dartExecuted:false` and exits 2. No source scan,
TypeScript test or fixture count is represented as a passed Dart test. The package's
overall verification status remains `native_blocked`, not release-ready.

No app route, dependency manifest, backend runtime, database migration or production
flag was changed. No OS-protected storage implementation, real dialer call, provider
message, payment, live membership action, identity import, deployment, billing change
or Supabase retirement occurred. The new client, coordinators and dialer bridge are
opt-in and disabled by default. Existing consumer flows remain unchanged.

## 2. Current-source reconciliation

At the start of this continuation, Drive already contained a completed Batch 9
`supporter-membership-api` source package, including its tests, contracts and delivery
records. The current client and README were freshly read and matched the downloaded
Batch 9 archive. That archive's 153 checksummed files were validated before reuse.
The gateway is therefore a **pre-existing dependency**, not an achievement invented
for this batch. No duplicate authenticated gateway was created.

Current gateway behavior is retained: identity comes from the private verifier,
checkout arguments cannot choose the payer or arbitrary price/receiver, current
instructions are distinct from historical checkout/receipt facts, and unknown
writes retain the original request key. Its cross-database revocation limitation
remains. Old cumulative v1-v4 packages must not downgrade newer Drive sources.

The feature package's existing pubspec was also retrieved. Dart >=3.10.0 <4.0.0,
Flutter >=3.38.0 and the existing url_launcher dependency remain unchanged. Other
context is preserved from the checksum-verified Batch 9 subset; this is not a
fresh whole-monorepo export or complete source audit.

## 3. Implemented TypeScript handoff

`payment-handoff.ts` adds a controller over the existing gateway read client. It
cannot prepare a checkout, allocate payment, activate membership or refresh tokens.

| Step | Implemented behavior |
| --- | --- |
| Review | Resolves current session, checks a prior handoff, reads the owned order, and returns the exact tier/amount/currency/country/provider/recipient/USSD for UI display. No dialer invocation. |
| Explicit confirmation | Requires the current review ID and an explicit acknowledgement. Consumes the in-memory review; re-reads and compares every instruction field, tier and expiry; rechecks the same session. |
| Freshness | Uses a monotonic 30-second review window and a 15-second expiry buffer adjusted for elapsed request/storage time. No claim that the carrier shares the server transaction. |
| Durable reservation | A user/club-scoped record is atomically persisted and read back before one platform call. Process/isolate-safe locking is an injected requirement, not an in-memory production fallback. |
| Result | Distinguishes reserved, opened, not_opened and unknown. Platform-opened is never paymentVerified. Timeout or failed final storage does not authorize another attempt. |
| Recovery | Reads the stored marker and owned server state only; never launches, retries, cancels, refreshes, clears uncertainty or prepares a new order automatically. |
| Lifecycle | invalidateReview clears only the in-memory quote. The UI must call it on background, logout, account changes and route exit. Concurrent invalidation is checked before platform invocation. |

A prior reserved/opened/unknown attempt blocks another handoff until its order is
reported allocated. **Expiry, cancellation and configuration change do not establish
that the payment was never sent.** A separately governed late-payment/exception
workflow is still absent. A crash before platform launch may intentionally strand
an unsent reservation; this is the availability cost of avoiding an unsafe repeat.

The acknowledgement boolean is not proof of real human review. No confirmation UI
was rendered or wired in this batch. A platform adapter must not report not_opened
for an uncertain already-started operation. A timeout cannot cancel a carrier action
already in progress. Manual payments outside the app remain outside local control.

## 4. Native source authored, not compiled

A separate `package:feat_membership/native_membership.dart` entrypoint contains:
strict typed response models; a native bearer HTTP adapter; a bounded dart:io
transport; an original-key checkout recovery coordinator; and a matching explicit
payment-handoff controller. Existing `feat_membership.dart` is not edited.

The transport uses normal TLS trust, one HttpClient per operation, no redirects,
no transparent decompression, bounded response bytes and cancellation/close on
its timeout. It introduces no certificate override or browser-cookie fallback.
The optional `native_membership_flutter.dart` bridge uses the existing url_launcher
package to request an external tel URI on Android/iOS, disabled by default. It does
not directly send a payment or request SMS/call permissions in a manifest. Carrier,
SIM, installed-dialer and iOS restrictions require real device testing.

**These Dart/Flutter source statements describe authored code, not executed proof.**
The files may need corrections after real analysis/compilation. No actual Keychain/
Keystore store, cross-process lock, lifecycle composition or accessible UI is supplied.
Those required ports must be implemented before any shipped app uses the library.
The in-memory test store and fake dialer are expressly test-only.

The new pure-Dart harness contains 57 shared wire cases and nine additional behavior
checks. None ran here. `verify_native_membership.py` performs no download or install;
when a suitable SDK exists it creates a temporary dependency-free package, invokes
the real analyzer and standalone harness, and still leaves the Flutter bridge and
OS/device acceptance unverified. Missing tools are a blocked gate, not skipped tests
counted as passes.

## 5. Executed evidence

| Executed group | Passed |
| --- | ---: |
| Preserved membership gateway/client/projection/security/configuration tests | 160 |
| New explicit-handoff unit tests | 61 |
| New handoff integration tests using actual current backend services | 5 |
| New shared-wire fixtures validated against the existing TypeScript client | 57 |
| Preserved payment-allocation and checkout tests | 432 |
| Preserved supporter identity/delivery/HTTP subset | 77 |
| Reused source installer/rollback regressions | 33 |
| **Total targeted passes** | **825** |

All executed final suites reported zero failed, cancelled, skipped or todo tests.
The TypeScript handoff/client compiles strictly. Seven changed JavaScript/JSON
syntax or parse checks and the existing disabled-configuration checks passed.
Python verifiers/installer executed as part of the run. These are not Dart analysis.

The five new integration cases exercise the current gateway, IdentityService,
MembershipCheckoutService and PaymentAllocationService with two real local SQLite
databases, genuine SQL/cryptography, synthetic identities and simulated service/
native transport/dialer ports. They cover no payment allocation on handoff alone,
changed offers, revoked sessions, already-allocated orders and restart uncertainty.
A separate explicit test allocation remains responsible for the membership effect.
No actual bank, provider or carrier was contacted.

The 57 shared fixtures contain synthetic responses generated from current services
plus malformed variants. Node validation proves that those fixtures agree with the
current TypeScript contract, **not that Dart has parsed them successfully**. Flutter
Web and browser-cookie flows are outside this native IO library.

Environment: Node 22.16.0, Python 3.13.5 and TypeScript 5.8.3 with local SQLite.
No workerd, real D1, physical handset, full Flutter/Next.js/pgTAP, signed binary,
accessibility or production performance acceptance was executed. Existing browser
policy restrictions were not bypassed. An initial combined verification command
hit the host timeout during installer tests; independent fixture slices then ran
in parallel and the complete final verification finished. Partial runs are not
added to the final counts.

## 6. Source recovery and delivery

The exact 21-file payload passed preflight, apply, after-hash checks, repeat apply
and rollback in three disposable source reconstructions:

| Starting state | Files changed | Result |
| --- | ---: | --- |
| Current scoped baseline | 21 | Every starting byte restored. |
| Alternating new entries already present | 10 | Previously present entries retained. |
| Entire payload already matching | 0 | No source mutation. |

The reconstruction populated with actual Drive source downloads reports all 21
already matching. Its 792 Node tests passed again. Those repetitions are not added
to the 825 total. Unknown prerequisite edits or conflicting additions stop the
installer. Individual writes are atomic; the entire multi-file application is not
one atomic filesystem transaction. Stop editors/builds and retain rollback journals.

The before-source backup has 81 scoped files, not the full repository or database.
The archive excludes real user/payment exports, provider secrets, SDKs, dependency
caches, databases, media originals and fonts. Synthetic test IDs are test-only.
Source hashes and exact Drive IDs are in the source readback register. Saving source
or SQL is never deployment or release approval.

## 7. Saved destinations and commands

Source additions: `cloudflare/supporter-membership-api/`,
`packages/features/feat_membership/`, and
`tools/scripts/verify_native_membership.py`, all below AFRICLUB.

Deliverables: `AFRICLUB/output/refactor-2026-09-27/batch10-native-payment-handoff/`.
The local date is 27 September in Kigali; some provider UTC audit timestamps remain
26 September. The one README update preserves its original file ID and parents.

```sh
python3 apply_patch.py --root "/path/to/AFRICLUB"
python3 apply_patch.py --root "/path/to/AFRICLUB" --apply
python3 verify_bundle.py --results "/tmp/africlub-batch10-verification"
```

A checkout matching the verified Drive source needs no changes. The verifier's exit
2 denotes the unresolved native SDK gate even when the Node/installer suites pass.
It is deliberately not presented as a completed release check.

## 8. Remaining work

Implement and verify OS-protected storage/locking, all five app compositions,
accessible review/confirmation and lifecycle transitions, actual platform/carrier
handoff, lost-phone/anonymous/account flows, late/unknown-payment operations,
cross-database revocation, pricing/receiver and historical-reference reconciliation,
real payment evidence, refunds, contribution rewards/referrals, shop/ticket commands,
observability, retention/erasure, backups and controlled single-writer cutover.
Prediction/FET approvals and Supabase retirement remain unresolved/unperformed.
The inherited remaining-actions register is preserved and updated only for this
scope; its older entries are not represented as newly audited production facts.
