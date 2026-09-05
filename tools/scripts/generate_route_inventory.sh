#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${OUT_DIR:-$ROOT/output/route_inventory/current}"

cd "$ROOT"
flutter test \
  packages/app_registry/test/route_inventory_generation_test.dart \
  --dart-define="ROUTE_INVENTORY_OUT_DIR=$OUT_DIR"

printf 'Route inventory JSON: %s\n' "$OUT_DIR/route-inventory.json"
printf 'Route inventory report: %s\n' "$OUT_DIR/route-inventory.md"
