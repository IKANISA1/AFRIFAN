#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

client_service_role_hits="$(
  git grep -n -i -E 'service_role|SUPABASE_SERVICE_ROLE_KEY' -- \
    ':(glob)apps/**/*.dart' \
    ':(glob)packages/**/*.dart' \
    ':(exclude,glob)apps/**/test/**' \
    ':(exclude,glob)apps/**/integration_test/**' \
    ':(exclude,glob)packages/**/test/**' \
    ':(exclude,glob)packages/**/integration_test/**' \
    || true
)"
if [ -n "$client_service_role_hits" ]; then
  echo "Forbidden service-role reference found in production Flutter client source:" >&2
  echo "$client_service_role_hits" >&2
  exit 1
fi

high_confidence_secret_hits="$(
  git grep -n -E \
    '(sb_secret_|sk_live_|rk_live_)[A-Za-z0-9_-]{16,}|AKIA[A-Z0-9]{16}' -- \
    . \
    ':(exclude)tools/scripts/validate_source_secrets.sh' \
    || true
)"
if [ -n "$high_confidence_secret_hits" ]; then
  echo "High-confidence secret token found in tracked source:" >&2
  echo "$high_confidence_secret_hits" >&2
  exit 1
fi

tracked_signing_files="$(
  git ls-files \
    'apps/*/android/*.jks' \
    'apps/*/android/*.keystore' \
    'apps/*/android/keystore.properties' \
    'apps/*/android/key.properties' \
    'apps/*/android/app/*.jks' \
    'apps/*/android/app/*.keystore'
)"
if [ -n "$tracked_signing_files" ]; then
  echo "Android signing material must not be committed:" >&2
  echo "$tracked_signing_files" >&2
  exit 1
fi

tracked_release_secrets="$(
  git ls-files \
    'apps/*/android/fastlane/*service-account*.json' \
    'apps/*/android/fastlane/*.p8' \
    'apps/*/ios/**/*.p8' \
    'apps/*/ios/**/*.mobileprovision'
)"
if [ -n "$tracked_release_secrets" ]; then
  echo "Mobile release credentials must not be committed:" >&2
  echo "$tracked_release_secrets" >&2
  exit 1
fi

tracked_dev_vars="$(
  git ls-files \
    'apps/**/web/.dev.vars' \
    '*/.dev.vars' \
    '.dev.vars' |
    grep -v '.example$' ||
    true
)"
if [ -n "$tracked_dev_vars" ]; then
  echo ".dev.vars files must not be committed:" >&2
  echo "$tracked_dev_vars" >&2
  exit 1
fi

echo "Source secret and signing-material scan passed."
