# Mobile release acceptance

AFRICLUB binds the selected `revolut-design` skill and its `MOBILE-DESIGN-100` rule through `docs/governance/design-exceptions.json`. The executable validator is `tools/scripts/validate_mobile_design_release.mjs`. It checks evidence for one club and one platform; it does not create reviews or acceptance records.

Current status: the implementation is being verified with temporary engineering fixtures. The product case inventory is draft, references have unverified state scope, and the reviewer and acceptance registries are empty. No club has passed mobile design acceptance.

## Commands and scope

Use the pinned Node version in `.nvmrc`. The selected skill package must be readable through its registered root or `REVOLUT_DESIGN_ROOT`.

```bash
node tools/scripts/validate_mobile_design_release.mjs \
  --app rayon_sports --platform android \
  --acceptance-id <reviewed-record-id> \
  --output <report.json>

bash tools/scripts/run_rayon_release_gate.sh \
  <reviewed-android-record-id> <reviewed-ios-record-id>
```

The validator exits nonzero for missing, stale, partial or unverifiable evidence. There is no waiver or skip mode. Optional `--artifact` and `--route-directory` select existing inputs and do not change the acceptance obligation. The Rayon wrapper validates both platforms before engineering commands, runs those commands, then revalidates the reviewed bytes. `run_rayon_engineering_checks.sh` can prepare and check a candidate while reviews are pending; its result is engineering evidence only. Artifact builders and release dry runs produce candidates for inspection and do not grant acceptance.

Use the single-platform validator for each of the four configured clubs. A pass for Rayon cannot approve another club's artifact. Web, member, admin/PWA, venue, deployment, providers, signing, stores and public availability retain separate results.

## Governed inputs

| Existing register | Acceptance fields |
| --- | --- |
| `design-exceptions.json` | Authority/rule/adapter hashes and `mobile_acceptance.contract`. |
| `route-state-evidence.json` | `mobile_release_inventory`: discovered routes and aliases, overlay dispositions, states, app/platform contexts, viewport profiles, coverage audit and original owner requirements. |
| `native-reference-map.json` | `reference_catalog`: stable IDs, original hashes/private locations, capture metadata, intended families, explicit state scope and limitations. |
| `evidence-bundles.json` | Existing bundles plus `mobile_reviewers` and `mobile_release_acceptances`. |

`generate_route_inventory.sh` records native source fingerprints before discovery and seals the actual route JSON only if source remains unchanged. The acceptance gate checks the seal against the selected club's current source. Native source fingerprints include tracked and untracked implementation inputs, ignored generated Dart/assets, native resources, known generated native configuration and plugin registration files. These records expose hashes, not Firebase configuration or Dart define values. External build tools and the executed command require separate build provenance. Source links include target bytes; unsupported directory links block verification.

The case generator requires every discovered mobile and internal-admin route/alias, and accounts for discovered dialogs, sheets, menus and pickers. Its call-site scan cannot establish all semantic product states or custom handoffs: the twelve-dimension source-backed coverage audit must also be complete. Each family defines applicable contexts and state coverage. Every standard material state must be tested or have an explicit `inapplicable_states` decision with a product reason, current source evidence of unavailability, named reviewer and timestamp. This is an applicability decision reviewed with the inventory, not an execution skip. Unsupported platform flows still require evidence for their redirect or unavailable behavior.

Keep the inventory draft while any roles, membership/ownership conditions, permissions, geographies, payment rails, supported themes, widths, orientations, keyboard states, text scales or reduced-motion variants remain unknown. The initial viewport profiles are planning values, not a claim about supported devices. Do not replace missing coverage with a fixed final case count.

## Evidence payload

An acceptance record has `id`, `app`, `platform`, an immutable `payload` and three `reviews`. The payload binds source, contract, reference registry, generated cases, version/build and artifact hashes. It contains:

- A production release artifact, its package identity and registered build proof. The proof identifies the source/artifact/version/build, production flavor and release profile, actual tools, command, completion time and hashed execution log. Record sensitive command inputs by file hash or safe argument names; never publish credentials.
- Installation on a physical device, a separate package readback, and registered install/readback command evidence. Directory artifacts hash every contained file; links may resolve only within the artifact. Package conversion, such as an AAB-derived APK, needs a registered proof tying the reviewed input to the delivered package, conversion tool/log and matching device readback. Merely copying the build to an output directory is not device evidence.
- Exactly the generated cases, each tied to that artifact: actual native PNG capture, a different comparison image, capture time, registered state-appropriate comparator, all ten stable visual criteria, four independent quality results and open findings. PNG chunks, checksums, pixel data and declared capture dimensions are validated. A valid image alone does not establish fidelity.
- Original owner requirement hashes, current implementation proof, baseline regeneration/comparison history, and empty material-finding, waiver and skip lists.

Captures must follow the recorded installation; criterion decisions must follow their captures; final reviews must follow the evidence they approve. Each visual criterion passes independently or has a reviewed product reason and source evidence for inapplicability. Usability, accessibility, performance and resilience must each pass without critical or high findings at platform and case level. Synthetic data, widget goldens, fixture builds, pending bundles and fabricated approvals cannot authorize production artifacts. Shared evidence may support cases only where its actual scope supports the linked claims.

Private comparator originals remain outside the checkout and are verified against the selected skill's registry. Native platform/theme matches are required for direct comparisons; component-pattern comparisons and adaptations need explicit rationale and stated source limitations. An index record, hash match or screenshot set does not grant visual acceptance.

## Review identity and signatures

Reviewer registration is a controlled input supplied or verified through the owner's designated review process. Each record contains `id`, allowed `roles`, `active`, `synthetic: false` and the reviewer's Ed25519 public key in SPKI PEM form. Do not invent production reviewers, substitute a new key for an existing reviewer, or generate owner approvals. Private keys stay with their holders and never enter the repository. Registry and validator changes require the repository's normal code review controls; cryptography does not verify a person's identity or the truth of their observations.

Implementer, independent visual reviewer and owner each sign a distinct record for the same immutable payload. The independent visual reviewer must differ from the implementer. A review contains `role`, `reviewer_id`, `reviewed_at`, `payload_sha256`, `synthetic: false` and base64 `signature`.

The protocol uses the validator's exported `canonical` function: object keys sorted recursively, array order retained, JSON primitives, no extra whitespace. Compute SHA-256 over UTF-8 canonical payload bytes. Sign the UTF-8 canonical object below using Ed25519, without a separate prehash:

```json
{
  "role": "independent_visual",
  "reviewer_id": "<registered-reviewer-id>",
  "reviewed_at": "<ISO-8601 timestamp with timezone>",
  "payload_sha256": "<64 lowercase hexadecimal characters>"
}
```

Payload, source, contract, reference, inventory or artifact changes invalidate existing acceptance. Regenerate current evidence and obtain the applicable reviews; never edit decisions or re-sign on someone else's behalf to preserve a passing result. The unit tests create fictional keys and evidence only under temporary directories and remove them after execution.
