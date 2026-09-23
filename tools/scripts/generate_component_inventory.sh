#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${OUT_DIR:-$ROOT/output/component_inventory/current}"

cd "$ROOT"
flutter test \
  packages/core/core_theme/test/component_inventory_test.dart \
  --dart-define="COMPONENT_INVENTORY_OUT_DIR=$OUT_DIR"

printf 'Component inventory JSON: %s\n' "$OUT_DIR/universal-component-inventory.json"
printf 'Component inventory report: %s\n' "$OUT_DIR/universal-component-inventory.md"
