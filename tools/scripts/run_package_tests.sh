#!/usr/bin/env bash
set -euo pipefail

# Melos executes this script from each selected package after the Dart
# workspace has been resolved and bootstrapped once at the root. Running
# Flutter from a child makes that child the "primary pubspec" even though the
# Material assets are governed by the workspace root and core_theme. Execute
# the child's tests from the root so the authoritative primary manifest is
# stable and the same package graph is exercised everywhere.
package_dir="$PWD"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
test_target="$package_dir/test"
flavor_file="$package_dir/assets/flavors/production.json"
package_name="$(awk '$1 == "name:" { print $2; exit }' "$package_dir/pubspec.yaml")"

if [[ -z "$package_name" ]]; then
  printf 'Unable to resolve package name from %s\n' "$package_dir/pubspec.yaml" >&2
  exit 2
fi

has_coverage=false
for arg in "$@"; do
  if [[ "$arg" == "--coverage" || "$arg" == "--merge-coverage" || "$arg" == "--branch-coverage" ]]; then
    has_coverage=true
    break
  fi
done

cd "$repo_root"

if [[ -f "$flavor_file" ]]; then
  if [[ "$has_coverage" == true ]]; then
    exec flutter test --no-pub --concurrency=1 "$test_target" "$@" \
      "--coverage-path=$package_dir/coverage/lcov.info" \
      "--coverage-package=^$package_name\$" \
      --dart-define-from-file="$flavor_file"
  fi
  exec flutter test --no-pub --concurrency=1 "$test_target" "$@" \
    --dart-define-from-file="$flavor_file"
fi

if [[ "$has_coverage" == true ]]; then
  exec flutter test --no-pub --concurrency=1 "$test_target" "$@" \
    "--coverage-path=$package_dir/coverage/lcov.info" \
    "--coverage-package=^$package_name\$"
fi

exec flutter test --no-pub --concurrency=1 "$test_target" "$@"
