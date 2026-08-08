#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REGISTRY="${EVIDENCE_BUNDLE_REGISTRY:-$ROOT/docs/governance/evidence-bundles.json}"
EVIDENCE_ROOT="${EVIDENCE_ROOT:-$ROOT/output/implementation_goal_20260724}"

jq -e '
  (.schema_version | type == "string") and
  (.manifest_name == "build-provenance.json") and
  (.bundles | type == "array" and length > 0) and
  ([.bundles[].id] | length == (unique | length)) and
  ([.bundles[].directory] | length == (unique | length)) and
  all(
    .bundles[];
    (.id | type == "string" and length > 0) and
    ((.admission_status // "admitted") == "admitted" or .admission_status == "pending") and
    (.directory | type == "string" and startswith("output/implementation_goal_20260724")) and
    ((.artifact_scope // "recursive") == "recursive" or .artifact_scope == "immediate") and
    (.task_ids | type == "array" and length > 0) and
    (.baseline_commit | test("^[0-9a-f]{40}$")) and
    (.dirty_state | type == "boolean") and
    (.app_version | type == "string" and length > 0) and
    (.build_number | type == "string" and length > 0) and
    (.flavor | type == "string" and length > 0) and
    (.platform | type == "string" and length > 0) and
    (.runtime_device | type == "string" and length > 0) and
    (.viewport_profiles | type == "array" and length > 0) and
    (.locale | type == "string" and length > 0) and
    (.themes | type == "array" and length > 0) and
    (.captured_at | fromdateiso8601 | type == "number") and
    (.data_source | type == "string" and length > 0)
  )
' "$REGISTRY" >/dev/null

registered_directories="$(
  jq -r \
    --arg root "${EVIDENCE_ROOT#"$ROOT/"}" \
    '.bundles[].directory | select(. != $root)' \
    "$REGISTRY" | sort
)"
actual_directories="$(
  find "$EVIDENCE_ROOT" -mindepth 1 -maxdepth 1 -type d -print |
    sed "s#^$ROOT/##" |
    sort
)"
if [ "$registered_directories" != "$actual_directories" ]; then
  printf 'Evidence bundle registry does not match current bundle directories.\n' >&2
  diff -u \
    <(printf '%s\n' "$registered_directories") \
    <(printf '%s\n' "$actual_directories") >&2 || true
  exit 1
fi

while IFS= read -r relative_directory; do
  manifest_path="$ROOT/$relative_directory/build-provenance.json"
  test -f "$manifest_path"
  artifact_scope="$(
    jq -r \
      --arg directory "$relative_directory" \
      '.bundles[] | select(.directory == $directory) | .artifact_scope // "recursive"' \
      "$REGISTRY"
  )"

  jq -e '
    (.schema_version == "1.0") and
    (.bundle_id | type == "string" and length > 0) and
    (.task_ids | type == "array" and length > 0) and
    (.bundle_directory | type == "string" and length > 0) and
    (.artifact_scope == "recursive" or .artifact_scope == "immediate") and
    (.provenance.baseline_commit | test("^[0-9a-f]{40}$")) and
    (.provenance.dirty_state | type == "boolean") and
    (.provenance.app_version | type == "string" and length > 0) and
    (.provenance.build_number | type == "string" and length > 0) and
    (.provenance.flavor | type == "string" and length > 0) and
    (.provenance.platform | type == "string" and length > 0) and
    (.provenance.runtime_device | type == "string" and length > 0) and
    (.provenance.viewport_profiles | type == "array" and length > 0) and
    (.provenance.locale | type == "string" and length > 0) and
    (.provenance.themes | type == "array" and length > 0) and
    (.provenance.captured_at | fromdateiso8601 | type == "number") and
    (.provenance.data_source | type == "string" and length > 0) and
    (.provenance.manifest_generated_at | fromdateiso8601 | type == "number") and
    (.artifacts | type == "array" and length > 0) and
    all(
      .artifacts[];
      (.path | type == "string" and length > 0) and
      (.sha256 | test("^[0-9a-f]{64}$")) and
      (.bytes | type == "number" and . >= 0)
    )
  ' "$manifest_path" >/dev/null

  while IFS=$'\t' read -r artifact_path expected_sha expected_bytes; do
    absolute_artifact="$ROOT/$artifact_path"
    test -f "$absolute_artifact"
    actual_sha="$(shasum -a 256 "$absolute_artifact" | awk '{print $1}')"
    actual_bytes="$(stat -f '%z' "$absolute_artifact")"
    if [ "$actual_sha" != "$expected_sha" ] ||
      [ "$actual_bytes" != "$expected_bytes" ]; then
      printf 'Evidence artifact mismatch: %s\n' "$artifact_path" >&2
      exit 1
    fi
  done < <(
    jq -r '.artifacts[] | [.path, .sha256, .bytes] | @tsv' "$manifest_path"
  )

  expected_artifacts="$(
    if [ "$artifact_scope" = "immediate" ]; then
      find "$ROOT/$relative_directory" -maxdepth 1 -type f \
        ! -name 'build-provenance.json' \
        -print
    else
      find "$ROOT/$relative_directory" -type f \
        ! -name 'build-provenance.json' \
        -print
    fi | sed "s#^$ROOT/##" | sort
  )"
  manifest_artifacts="$(
    jq -r '.artifacts[].path' "$manifest_path" | sort
  )"
  if [ "$expected_artifacts" != "$manifest_artifacts" ]; then
    printf 'Evidence artifact inventory mismatch: %s\n' "$relative_directory" >&2
    exit 1
  fi
done < <(
  jq -r \
    '.bundles[] | select((.admission_status // "admitted") == "admitted") | .directory' \
    "$REGISTRY"
)

printf 'Evidence provenance valid: %s admitted bundles; %s pending bundles\n' \
  "$(jq '[.bundles[] | select((.admission_status // "admitted") == "admitted")] | length' "$REGISTRY")" \
  "$(jq '[.bundles[] | select(.admission_status == "pending")] | length' "$REGISTRY")"
