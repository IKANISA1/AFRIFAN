#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REGISTRY="${EVIDENCE_BUNDLE_REGISTRY:-$ROOT/docs/governance/evidence-bundles.json}"
GENERATED_AT="${EVIDENCE_MANIFEST_GENERATED_AT:-$(date -u '+%Y-%m-%dT%H:%M:%SZ')}"

jq -e '
  (.schema_version | type == "string") and
  (.manifest_name == "build-provenance.json") and
  (.bundles | type == "array")
' "$REGISTRY" >/dev/null

if [ "$(jq '[.bundles[] | select((.admission_status // "admitted") == "admitted")] | length' "$REGISTRY")" -eq 0 ]; then
  printf 'No admitted evidence bundles; no provenance or completion is claimed.\n'
  exit 0
fi

while IFS= read -r bundle; do
  relative_directory="$(jq -r '.directory' <<<"$bundle")"
  artifact_scope="$(jq -r '.artifact_scope // "recursive"' <<<"$bundle")"
  bundle_directory="$ROOT/$relative_directory"
  manifest_path="$bundle_directory/build-provenance.json"
  test -d "$bundle_directory"

  artifacts='[]'
  while IFS= read -r -d '' artifact_path; do
    relative_artifact="${artifact_path#"$ROOT/"}"
    artifact_sha="$(shasum -a 256 "$artifact_path" | awk '{print $1}')"
    artifact_bytes="$(wc -c <"$artifact_path" | tr -d '[:space:]')"
    artifacts="$(
      jq -c \
        --arg path "$relative_artifact" \
        --arg sha256 "$artifact_sha" \
        --argjson bytes "$artifact_bytes" \
        '. + [{path:$path,sha256:$sha256,bytes:$bytes}]' \
        <<<"$artifacts"
    )"
  done < <(
    if [ "$artifact_scope" = "immediate" ]; then
      find "$bundle_directory" -maxdepth 1 -type f \
        ! -name 'build-provenance.json' \
        -print0
    else
      find "$bundle_directory" -type f \
        ! -name 'build-provenance.json' \
        -print0
    fi | sort -z
  )

  if [ "$(jq 'length' <<<"$artifacts")" -eq 0 ]; then
    printf 'Evidence bundle has no artifacts: %s\n' "$relative_directory" >&2
    exit 1
  fi

  jq -n \
    --arg generated_at "$GENERATED_AT" \
    --argjson bundle "$bundle" \
    --argjson artifacts "$artifacts" \
    '{
      schema_version: "1.0",
      bundle_id: $bundle.id,
      task_ids: $bundle.task_ids,
      bundle_directory: $bundle.directory,
      artifact_scope: ($bundle.artifact_scope // "recursive"),
      provenance: {
        baseline_commit: $bundle.baseline_commit,
        dirty_state: $bundle.dirty_state,
        app_version: $bundle.app_version,
        build_number: $bundle.build_number,
        flavor: $bundle.flavor,
        platform: $bundle.platform,
        runtime_device: $bundle.runtime_device,
        viewport_profiles: $bundle.viewport_profiles,
        locale: $bundle.locale,
        themes: $bundle.themes,
        captured_at: $bundle.captured_at,
        data_source: $bundle.data_source,
        manifest_generated_at: $generated_at
      },
      artifacts: $artifacts
    }' >"$manifest_path"

  printf 'Generated provenance: %s\n' "$manifest_path"
done < <(
  jq -c \
    '[.bundles[] | select((.admission_status // "admitted") == "admitted")]
    | sort_by((.artifact_scope // "recursive") == "immediate")[]' \
    "$REGISTRY"
)
