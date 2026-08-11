#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodebuild >/dev/null 2>&1 || ! xcodebuild -version >/dev/null 2>&1; then
  echo "Ошибка: требуется полный Xcode, выбранный через xcode-select или DEVELOPER_DIR." >&2
  exit 1
fi

xcodebuild \
  -project Klyp.xcodeproj \
  -scheme Klyp \
  -configuration Debug \
  -destination 'platform=macOS' \
  clean build

xcodebuild \
  -project Klyp.xcodeproj \
  -scheme Klyp \
  -destination 'platform=macOS' \
  test
