# Dependency evidence gaps closed — 2026-10-01

**All 22 license evidence gaps and all 282 missing plugin JARs are resolved. The current inventory has zero unresolved fields.**

The 22 entries were missing dependency license evidence. The 282 outputs were Android plugin compile/runtime JARs for profile/release variants, not 282 application binaries.

| Club | Built and verified plugin JARs |
| --- | ---: |
| as_vita | 56 |
| costa_do_sol | 56 |
| nkana | 56 |
| rayon_sports | 58 |
| vitalo | 56 |

## Verification

- All 282 JARs exist, pass ZIP integrity checks, contain compiled classes and match their recorded SHA256 hashes. All frozen Gradle resolution inputs remained unchanged. Five grouped plugin-only builds used the shared cache; application release builds: zero.
- All 22 exact component license relationships pass admission. All 41 original license findings remain recorded and are recovered.
- All 8,664 inventory evidence items were rehashed. The updated SBOM equals the inventory-derived document and passes the cached CycloneDX 1.6 schema with zero errors.
- Seven focused admission regressions pass, including wrong version, altered evidence, unsupported release provenance and incomplete output coverage rejection.
- All 2,265 selected component identities, 7,199 edges and 137,849 edge occurrences remain unchanged.

## License evidence

13 CDN component records use exact upstream npm MIT declarations and archive license texts; the transformed CDN bodies remain independently locked. One JSR release uses its checksum-bound MIT package declaration. Five Zipflinger versions use their exact official Google Maven POM Apache-2.0 declarations and selected JAR hashes. Netty covers all 23 licensed Java source files and 27 compiled classes. buffers 0.1.1 exactly matches the six-file licensed Debian upstream distribution. TensorFlow uses explicit immutable publisher package Apache-2.0 grants with coverage for all 301 compiled classes; the exact binary release Git commit and a reproducible build are not asserted.

Legal approval is not claimed. No dependency versions were upgraded. Previous candidate/archive receipts remain historical snapshots.

## Files and rationale

[The JSON report](local-dependency-gaps-closure-2026-10-01.json) lists every added/updated file, SHA256 hash, byte size and reason. [Publisher manifest](dependency-license-evidence-2026-10-01/manifest.json), [all plugin build receipts](dependency-license-evidence-2026-10-01/plugin-output-builds.json), and [license recovery](local-dependency-inventory-2026-09-30.license-recovery.md) retain the detailed relationships.

## Repeatable local application

```sh
python3 tools/scripts/dependency_gap_closure.py \
  --inventory docs/release/local-dependency-inventory-2026-09-30.json \
  --plugin-outputs docs/release/dependency-license-evidence-2026-10-01/plugin-output-builds.json
```

Fresh dependency generation can apply the saved publisher manifest with `--publisher-license-manifest docs/release/dependency-license-evidence-2026-10-01/manifest.json`. Missing or changed outputs and publisher evidence are rejected; no waiver is applied.
