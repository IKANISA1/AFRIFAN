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

Evidence items: 8664; dependency edges: 7199; components with license text: 1427; with license declarations: 2006.

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

The small JSON indexes reference SHA256-bound TSV shards (at most 2 MiB each). Canonical JSON cells preserve every component, dependency edge, evidence item, unresolved field and Android configuration losslessly. Full validation verifies shard bytes, row ordinals/counts, unique keys and reconstructed table hashes before validating source evidence. The license TSV has one row per component, with exact version/source and evidence references.

Exactness concerns selected component versions, source identities and recorded integrity evidence. Missing license declarations/text and unbuilt local plugin outputs remain explicit non-exactness fields. Full target compilation, legal license approval, provider/device/store acceptance and fresh vulnerability clearance are separate work. Declared archive hashes are identified separately from fresh byte rehashes.

Local cache recovery and authenticated publisher recovery are recorded separately. License associations identify exact package declarations, byte-identical licensed distributions, or explicit publisher source grants with their stated provenance limits. CDN/archive byte equality and legal approval are not inferred. Publisher retrieval used the network; applying saved evidence performs no network requests and changes no selected versions. See `licenseRecovery.publisherEvidenceManifest` and `dependencyGapClosure` when present.

## Added files and rationale

- Generator/validator: repeatable exact source, integrity, dependency-edge and license evidence reconciliation.
- Gradle collector: observes all five active targets and plugin configurations using actual offline resolution.
- Regression tests: reject duplicate input keys, integrity mismatches, unsafe paths/URLs, stale evidence, unresolved exactness, and graph corruption.
- Backend import map/lock: reproducible exact backend selections and transitive HTTP/JSR/npm integrity records.
- JSON, CycloneDX 1.6, license TSV and this report: reviewable inventory with explicit evidence coverage; none grants license approval.

Standards: [CycloneDX 1.6 JSON schema](https://raw.githubusercontent.com/CycloneDX/specification/1.6/schema/bom-1.6.schema.json), [Package URL specification](https://www.packageurl.org/docs/purl/introduction).
