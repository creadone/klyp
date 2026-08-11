#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "Ошибка: swiftc не найден." >&2
  exit 1
fi

if command -v swift-format >/dev/null 2>&1; then
  SWIFT_FORMAT=(swift-format)
elif command -v xcrun >/dev/null 2>&1 && xcrun --find swift-format >/dev/null 2>&1; then
  SWIFT_FORMAT=(xcrun swift-format)
else
  SWIFT_FORMAT=()
  echo "Предупреждение: swift-format не найден; проверка форматирования пропущена." >&2
fi

if ((${#SWIFT_FORMAT[@]})); then
  find Klyp KlypTests Verification -name '*.swift' -print0 \
    | xargs -0 "${SWIFT_FORMAT[@]}" lint --strict
fi

VERIFY_BUILD="$(mktemp -d "${TMPDIR:-/tmp}/klyp-verification.XXXXXX")"
trap 'rm -rf "$VERIFY_BUILD"' EXIT
mkdir -p "$VERIFY_BUILD/ModuleCache"

while IFS= read -r -d '' file; do
  swiftc -frontend -module-cache-path "$VERIFY_BUILD/ModuleCache" -parse "$file"
done < <(find Klyp KlypTests Verification -name '*.swift' -print0)

swiftc \
  -module-cache-path "$VERIFY_BUILD/ModuleCache" \
  -swift-version 5 \
  -strict-concurrency=complete \
  -warnings-as-errors \
  Klyp/Models/PasswordItemSummary.swift \
  Klyp/Models/KeychainItemList.swift \
  Klyp/Support/PasswordValidator.swift \
  Klyp/Support/PasswordItemSorter.swift \
  Verification/CoreLogicChecks.swift \
  -o Verification/core_logic_checks
./Verification/core_logic_checks
rm -f Verification/core_logic_checks

swiftc \
  -module-cache-path "$VERIFY_BUILD/ModuleCache" \
  -swift-version 5 \
  -strict-concurrency=complete \
  -warnings-as-errors \
  Klyp/Models/PasswordItemSummary.swift \
  Klyp/Support/Constants.swift \
  Klyp/Support/PasswordValidator.swift \
  Klyp/Support/AppError.swift \
  Verification/PasteboardHarnessStub.swift \
  Klyp/Services/ClipboardService.swift \
  Verification/ClipboardLogicChecks.swift \
  -o Verification/clipboard_logic_checks
./Verification/clipboard_logic_checks
rm -f Verification/clipboard_logic_checks

swiftc \
  -module-cache-path "$VERIFY_BUILD/ModuleCache" \
  -swift-version 5 \
  -parse-as-library \
  -emit-module \
  -emit-object \
  -module-name Combine \
  Verification/CombineHarness.swift \
  -emit-module-path "$VERIFY_BUILD/Combine.swiftmodule" \
  -o "$VERIFY_BUILD/Combine.o"

swiftc \
  -module-cache-path "$VERIFY_BUILD/ModuleCache" \
  -swift-version 5 \
  -strict-concurrency=complete \
  -warnings-as-errors \
  -I "$VERIFY_BUILD" \
  Klyp/Models/PasswordItemSummary.swift \
  Klyp/Models/KeychainItemList.swift \
  Klyp/Support/Constants.swift \
  Klyp/Support/PasswordValidator.swift \
  Klyp/Support/PasswordItemSorter.swift \
  Klyp/Support/AppError.swift \
  Klyp/Services/KeychainStoring.swift \
  Verification/ViewModelHarnessSupport.swift \
  Klyp/ViewModels/PasswordListViewModel.swift \
  Verification/ViewModelLogicChecks.swift \
  "$VERIFY_BUILD/Combine.o" \
  -o "$VERIFY_BUILD/viewmodel_logic_checks"
"$VERIFY_BUILD/viewmodel_logic_checks"

if command -v plutil >/dev/null 2>&1; then
  plutil -lint Klyp/Info.plist Klyp/Klyp.entitlements Klyp.xcodeproj/project.pbxproj
fi

python3 scripts/standalone_review.py
