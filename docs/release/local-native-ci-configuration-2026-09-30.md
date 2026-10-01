# Local native CI configuration — 2026-09-30

Configuration checks passed for five clubs and ten distinct targets. The checks validate the definitions and synthetic compile inputs; hosted execution, signing, devices/stores, provider operation and deployment require their own evidence.

| Club | Tenant ID | Android | iOS |
| --- | --- | --- | --- |
| as_vita | 6 | configured | configured |
| costa_do_sol | 1001 | configured | configured |
| nkana | 26 | configured | configured |
| rayon_sports | 24 | configured | configured |
| vitalo | 44 | configured | configured |

The matrix uses independent read-only checks, immutable action pins, the exact repository Flutter pin, Android debug builds and iOS simulator builds without signing. Release promotion depends on the ten-target gate. All five flavor scopes and their synthetic configurations were checked.

The current preview/deploy/upload package commands and both CI workflows call `build-opennext-isolated.mjs` before consuming the adapter artifact. The checker rejects raw adapter bypasses, duplicated conversion and wrong conversion order. The main CI workflow requires all four reviewed public-environment, installed-input, private-vars and network-guard regression inputs before conversion; omitted tests, ignored failures, conditional or late gates are rejected. This check does not execute the adapter or deploy.

Local contract tests: 20 passed. The companion JSON records current hashes for both workflows, the Flutter setup action/pin, scope, five production flavor sources, web package and adapter/public-environment/installed-input/provenance helpers, both network guards, private settings writer and reviewed regressions, and the verifier/tests.

Reproduce:

```sh
python3 tools/scripts/local_native_ci.py verify --report docs/release/local-native-ci-configuration-2026-09-30.json
python3 -m unittest discover -s tools/scripts -p test_local_native_ci.py
```

## Current SDK source rebind (2026-10-01)

The corrected direct test runner passed all20 CI contract regressions. Current configuration verification covers all ten native targets and five synthetic club configurations; all 24 configuration source bindings and eight runtime/vendor metadata bindings were read back and matched. The first invocation used an unsupported unittest import path and is retained as a rejected setup attempt. No hosted jobs or deployment actions were executed.

## Current native Performance privacy gate

Current source verification passed22CI contract tests and10native controls. All46configuration input hashes matched before and after the CLI check. The source gate is required before compilation and cannot be conditional, ignored, duplicated or delayed. Hosted jobs and native build acceptance require their own evidence.
