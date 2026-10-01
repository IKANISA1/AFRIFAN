# Local dependency inventory — 2026-09-30

Active workspace dependencies and five native targets; historical Drive archives excluded.

**Exact inventory complete: true.**

This is local source/cache evidence. License approval, vulnerability clearance, deployed dependencies, and device/store acceptance are not assessed.

## Coverage

| Ecosystem | Unique components |
| --- | ---: |
| backend-import | 7 |
| cocoapods | 1 |
| dart | 177 |
| dart-local | 34 |
| deno-jsr | 3 |
| deno-npm | 46 |
| deno-remote | 98 |
| github-action | 7 |
| maven | 802 |
| npm | 1068 |
| python | 1 |
| sdk | 3 |
| swift | 18 |

Evidence items: 8290; dependency edges: 7199; components with license text: 1412; with license declarations: 1984.

Dart: one workspace lock and active package_config reconciled against cached pubspecs and hosted hash records. Npm: every lock location retained, including absent platform optional packages; available cached archives rehashed against SRI. iOS: both SwiftPM lock containers for each app, immutable commit manifests/license blobs, generated local plugin manifests, and four CocoaPods locks. Android: offline resolved component/artifact graphs for each supplied target; unresolved selectors are retained.

A pub cache hash record confirms the stored archive declaration, not a fresh archive rehash. Git commit identities and CocoaPods spec checksums are not binary archive hashes. Cached Maven and available npm archive bytes are rehashed. Swift binary checksums remain exact-revision manifest declarations unless archive bytes are available. Parent POM declarations and SDK distribution license texts retain their source relationship; they do not grant license approval.

## Version selection corrections

The backend now has a committed Deno v5 lock and explicit import map: Supabase npm 2.116.0, Supabase JSR functions 2.110.7, and Deno assert 1.0.19. These replace floating selectors with new reviewed exact selections; the repo contained no prior selected-version evidence. Exact HTTP imports retain their original declarations and transitive frozen hashes.

Android hydration retained every previously selected version. The public SDK runner selector `androidx.test:runner:1.2+` resolves to 1.2.0 from published Maven metadata. Initial and final observations, selected versions, immutable artifact origins, source bindings and stability comparisons are recorded in JSON. Collection does not compile or sign an app.

## Reproduce

Requires Python >=3.10, PyYAML==6.0.3, cached Dart/npm/Swift/Maven packages, and the pinned JDK/Gradle/Flutter environment. Generation and validation run locally. Optional hydration fetches public immutable artifacts/metadata; it does not execute an app or change dependency declarations.

```sh
python3 tools/scripts/local_dependency_inventory.py collect-android --output-dir output/dependency-inventory/initial --jdk /path/to/jdk
python3 tools/scripts/local_dependency_inventory.py hydrate-maven --android-resolutions output/dependency-inventory/initial --mirror output/dependency-inventory/maven-mirror
python3 tools/scripts/local_dependency_inventory.py collect-android --output-dir output/dependency-inventory/android --jdk /path/to/jdk --freeze-inputs output/dependency-inventory/initial --maven-mirror output/dependency-inventory/maven-mirror
python3 tools/scripts/local_dependency_inventory.py hydrate-actions --output-dir output/dependency-inventory/action-sources
python3 tools/scripts/local_dependency_inventory.py hydrate-jsr-licenses --output-dir output/dependency-inventory/jsr-licenses
python3 tools/scripts/local_dependency_inventory.py generate --android-resolutions output/dependency-inventory/android --action-sources output/dependency-inventory/action-sources --jsr-licenses output/dependency-inventory/jsr-licenses --output-prefix docs/release/local-dependency-inventory-2026-09-30
python3 tools/scripts/local_dependency_inventory.py validate --inventory docs/release/local-dependency-inventory-2026-09-30.json
# Release exactness gate; fails whenever any exactness-blocking field is unresolved:
python3 tools/scripts/local_dependency_inventory.py validate --inventory docs/release/local-dependency-inventory-2026-09-30.json --require-exact
python3 -m unittest discover -s tools/scripts -p test_local_dependency_inventory.py
```

Full validation rehashes every evidence file, Git blob, original Deno cache body and archive license member; confirms graph references and summary facts; and checks the companion SBOM for exact equality with the inventory-derived document. Portable CI source validation can use `--repository-only --require-exact`; it explicitly skips author-machine cache/ignored-output rehashing and prints that limitation.

## Remaining evidence fields

| Kind | Count | Blocks exactness |
| --- | ---: | --- |
| license-evidence-unavailable | 22 | false |
| native-project-artifact-not-built | 282 | false |

The small JSON indexes reference SHA256-bound TSV shards (at most 2 MiB each). Canonical JSON cells preserve every component, dependency edge, evidence item, unresolved field and Android configuration losslessly. Full validation verifies shard bytes, row ordinals/counts, unique keys and reconstructed table hashes before validating source evidence. The license TSV has one row per component, with exact version/source and evidence references.

Exactness concerns selected component versions, source identities and recorded integrity evidence. Missing license declarations/text and unbuilt local plugin outputs remain explicit non-exactness fields. Full target compilation, legal license approval, provider/device/store acceptance and fresh vulnerability clearance are separate work. Declared archive hashes are identified separately from fresh byte rehashes.

Local license recovery uses exact upstream npm name/version declarations for transformed CDN modules, and fresh SHA256 equality when a Maven JAR shares bytes with a cached license-declared coordinate. These relationships are explicit in `licenseAssociations`; they do not assert CDN/archive byte equality or license approval. Embedded-POM-only licenses retain a package-wide gap. Recovery performs no network requests and changes no selected versions.

## Added files and rationale

- Generator/validator: repeatable exact source, integrity, dependency-edge and license evidence reconciliation.
- Gradle collector: observes all five active targets and plugin configurations using actual offline resolution.
- Regression tests: reject duplicate input keys, integrity mismatches, unsafe paths/URLs, stale evidence, unresolved exactness, and graph corruption.
- Backend import map/lock: reproducible exact backend selections and transitive HTTP/JSR/npm integrity records.
- JSON, CycloneDX 1.6, license TSV and this report: reviewable inventory with explicit evidence coverage; none grants license approval.

Standards: [CycloneDX 1.6 JSON schema](https://raw.githubusercontent.com/CycloneDX/specification/1.6/schema/bom-1.6.schema.json), [Package URL specification](https://www.packageurl.org/docs/purl/introduction).

## Current source rebind, local font asset and GoTrue patch

The frozen local regeneration retains 2,265 selected package identities by name/version and adds exactly six direct test dependency edges: core_auth → http and test_support → go_router, http, supabase_flutter, core_l10n, feat_membership. Every earlier graph relationship is preserved after explicitly mapping the GoTrue source replacement. Edges changed from 7,193 to 7,199; edge occurrences changed from 137,843 to 137,849. Selected upstream versions were not changed.

GoTrue 2.27.2 now resolves through the declared third_party/gotrue_2_27_2 path override. This replaces its hosted source identity with authenticated local patched bytes. The complete regular-file manifest, root override, active package selection, original installed source and preserved license are bound separately. Patched bytes are not attributed to the upstream hosted archive or Flutter SDK; the local patch has no misleading registry package URL. Five-target Android observations use existing offline caches and preserve prior Maven selections. Any reused completed target is named with its original execution receipt and exact current native resolver-input proof; broader Dart manifest changes bind separately. Full validation checks all local evidence; portable validation excludes only its stated author-machine/cache/output scope and exact generated Pub/plugin inputs confirmed ignored by Git. Its complete exclusion receipt is hash-bound in the verification JSON.

The Inter variable WOFF2 and SIL Open Font License 1.1 in web/public/fonts remain byte-identical to the retained operator UI copies. Font SHA256 is 3100e775e8616cd2611beecfa23a4263d7037586789b43f035236a2e6fbd4c62. The retained source README declares @fontsource-variable/inter 5.3.0; this local asset is not an added npm selection. No upstream font archive revalidation or license approval is asserted.

All 41 original package-license findings and their finite recovery relationships remain retained: 22 package-license gaps and 282 unbuilt native output fields remain. Wrapper/font control hashes identify current source; build/converter outcomes require their separate receipts. The previous inventory checkpoint and the rejected concurrent-source generation are preserved in ignored local evidence. No production, provider, device/store or release acceptance is granted.
