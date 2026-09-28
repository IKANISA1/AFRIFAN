# AFRICLUB — Implementation 08
## 28 September 2026

**Implemented and locally tested: reliable delivery of existing allocation events to a private operational inbox, bounded retry/dead-letter control, explicit review-principal replay, queue health and a typed private operations client. Not deployed; not a full AFRICLUB release.**

## Source and scope

The exact Implementation 07 package was verified against all 527 internal checksums. Its 394-file source candidate is the baseline. This delivery adds **22 files and modifies 3 files: 25 changed source/document paths**. The new scoped source contains **416 files**, with **391 unchanged exact-hash prerequisites**. All **18 existing SQL files are unchanged**. Two additive migrations are included: one in the existing allocation lineage, and one for a separate operations inbox database. Neither was applied to hosted resources.

This is not a fresh full-repository export, protected Git merge, completed product migration, or production approval. Older attached register/service-worker snippets were not used to downgrade Implementation 07. Your original Drive code files were not overwritten. The local Git commit identifies the scoped baseline only.

## Implemented workflow

The prior source had claim/acknowledge logic and explicitly lacked a consumer. The new `cloudflare/allocation-delivery` module now provides a concrete consumer: one immutable operational inbox record for each accepted source event. Source event validation is tied to the existing allocation, order, ledger and retained receipt. The outbound projection has only version/consumer/event/club/order/user identifiers, kind, allocation-recorded/business-target flags and time.

**Delivery does not confirm settlement, execute refunds, activate membership, fulfill contributions, award rewards or send a phone notification.** A contribution allocation remains explicitly unfulfilled. The recipient stores the operational event and its deduplication identity atomically; exact retries return the retained receipt, and conflicting payloads cannot replace it. These identifiers remain private operational data even though phone numbers, payment amounts, raw SMS, provider references and credentials are excluded.

### Source ownership and reliable retry

Only never-attempted pending legacy events can be adopted. An SQL guard makes legacy claiming and new enrollment mutually exclusive. Previously attempted, expired or delivered legacy records are left untouched; no previous outcome is presumed failed. Managed events use the new delivery journal, not a fabricated update to the old delivered column. Stop/drain/review the old executable before enabling this pipeline.

Each claim, acknowledgement, retry, lease expiry, dead-letter decision and redrive has an immutable command. The current authorization, per-club policy, expected revision and lease are checked at SQL mutation time. The command and resulting job head commit or roll back together. Crashes and lease expiration consume the configured attempt budget rather than retrying forever. Exponential retry is capped at one hour and at the explicitly reviewed maximum, no more than ten attempts. Consumer identity and maximum-attempt policy are frozen after adoption.

A failed or timed-out sink response can follow a successful remote commit. The same original event/consumer identity is used on retry, so that committed record is recovered rather than duplicated. A failure to acknowledge at the source does not erase the sink record. Summary counters distinguish stored receipts, recorded retry/dead commands and unknown acknowledgements; a recorded retry can exhaust its budget, so the current state is inspected separately.

### Private operations and scheduling

Separate private entrypoints expose delivery, review, inbox ingestion, inbox reading and the runner. The review API has bounded state-filtered pagination, capped queue-health counts and explicit same-event redrive. A strictly compiled TypeScript client validates responses and retains the caller-supplied request ID and expected revision across deliberate retries. Reads and constructors never write. Redrive requires a different approved service principal from the last claimant; this is **not proof of a named human approval or completed Access UI**.

The runner attempts at most one event per configured club and no more than five clubs per invocation. One club failure does not silently suppress later configured clubs. It has source/sink bindings only, with no database, provider or review capability. Default HTTP handlers return 404. All template switches remain false, public routes/previews are disabled, and no actual Cron schedule was installed.

`health` emits no user/event identifiers, caps per-state counts at 1,000 and signals truncation. It is not an atomic cross-query snapshot. Page sizes and iteration counts are bounded; scanned-row costs, fairness over real traffic and game-day capacity still require measurement. The operational inbox reader exposes private identifiers and must only be bound to a separately authorized operator adapter. No new frontend route or browser experience was installed here.

## Verification actually executed

| Completed group | Passing tests |
|---|---:|
| Scoped Node regression bank, including new source/sink/client/concurrency tests | 2,201 |
| Python source/security/migration/dependency suites | 236 |
| Installer safety and current-bundle dry-run/apply/repeat/rollback/conflict runs | 39 |
| Freshly compiled portable Kotlin recovery tests | 69 |
| Freshly compiled portable Swift recovery tests | 68 |
| **Unique passing tests** | **2,613** |

**83 new tests were authored and executed: 81 Node plus two Python inventory checks.** Five new race tests use independent SQLite connections in worker threads for competing source leases, legacy/new ownership, identical and conflicting recipient writes, and competing redrives. Tests exercise actual allocation classes, SQL triggers and a separately persisted recipient, not only source-string matching. They include lost source/sink responses, late remote commits after timeout, stale reviewer revisions, wrong leases, SQL-trigger rollback, revoked permissions, malformed receipts, retry ceilings and contribution non-fulfillment.

All counted final suites passed. Repeated targeted runs and the strict verifier's repeated Python/native runs are excluded from totals. Installer tests completed as 17, 16 and six-case groups. Another **266 JavaScript/Python/JSON syntax or parse checks** passed, as did strict TypeScript client compilation, disabled-template checks and source-only migration-lineage checks. A limited sensitive-source scan read all 416 scoped files and flagged no findings; it does not prove absence of all secrets or inspect the whole Drive/Git history.

## Unpassed gates and limitations

The strict complete verifier returns **blocked** for the unchanged Node pin requirement (22.23.2 versus executed 22.16.0) and absent Dart/Flutter. Python is 3.13.5, TypeScript 5.8.3. Portable Kotlin/Swift tests are not Android/iOS host, Keystore/Keychain, signing or physical-device acceptance.

No whole Next.js/Flutter build, rendered browser QA, workerd/real D1/RPC/Access test, provider message or payment, independent security review, production-shaped load, backup/cutover drill or store submission was executed. No browser-navigation policy was bypassed. This increment did not modify UI source or claim screenshots.

The source coordinator validates sink receipts and is a privileged, narrowly bound service. Its acknowledgement is not independently authenticated settlement evidence. Identity/source/sink databases are separate: permission revocation can occur after a last read and before an external effect, and no universal cross-database revocation fence or transaction is claimed. Actual service bindings, independent Access authorization, source/sink resource separation, retention/erasure, monitoring/alerts and named operational ownership remain requirements.

The conflicting version-0003 financial handoff histories remain separate; this additive delivery work does not reconcile hosted migration history. Root metadata still showed anyone/writer with link discovery disabled. Sharing and credentials were not changed. Cloudflare plugin discovery returned no matching connector. No unrelated repository or infrastructure was selected.

## Task status

The register now has **37 In progress and 93 Open; zero release-accepted or Closed**. Only PAY-09 moved from Open to In progress. Eight records received scoped progress notes: PAY-09, OPS-04, OPS-02, OPS-08, ARC-05, ARC-09, QAT-04 and REP-07. All original priorities, dependencies, owner roles and acceptance requirements remain intact. The full register and dependency plan are included; no named human ownership or release approval is invented.

## Delivery and use

Implementation 07's previously pending **code archive** was uploaded to the same AFRICLUB folder during this turn, then downloaded again with a matching SHA-256. Its historical report retains its original status; the new delivery receipt distinguishes that earlier status from this catch-up upload. Implementation 08 is packaged for upload with the current report/register/plan and actual evidence; the final upload receipt is separate from the ZIP so it can record completed readback.

Start with `CODEX_HANDOFF.md`. Use the exact reviewed Implementation 07 baseline and the guarded dry run. `files/` contains all 25 changed paths; `source/` is the 416-file scoped test candidate, not the full monorepo; `before/` holds the three modified originals; `reference_only/` retains the competing financial migration outside installable source. The installer checks hashes, refuses unknown edits, backs up changes, supports no-op repeat and exact rollback, and never executes SQL or provisions services. Individual file replacement is atomic; a whole multi-file patch is not a transaction for concurrent editors.
