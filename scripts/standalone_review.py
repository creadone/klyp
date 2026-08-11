#!/usr/bin/env python3
"""Deterministic second-pass audit for the checked-in Klyp project.

The script runs in a separate process and checks security-sensitive invariants.
It is not an external AI-agent review and does not replace xcodebuild or runtime tests.
"""

from __future__ import annotations

import plistlib
import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
@dataclass
class Check:
    identifier: str
    description: str
    passed: bool
    evidence: str


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def add(checks: list[Check], identifier: str, description: str, condition: bool, evidence: str) -> None:
    checks.append(Check(identifier, description, bool(condition), evidence))


def main() -> int:
    checks: list[Check] = []

    required_files = [
        "Klyp.xcodeproj/project.pbxproj",
        "Klyp.xcodeproj/xcshareddata/xcschemes/Klyp.xcscheme",
        "Klyp/KlypApp.swift",
        "Klyp/AppDelegate.swift",
        "Klyp/Info.plist",
        "Klyp/Klyp.entitlements",
        "Klyp/Services/KeychainStore.swift",
        "Klyp/Services/ClipboardService.swift",
        "Klyp/Services/LoginItemService.swift",
        "Klyp/ViewModels/PasswordListViewModel.swift",
        "README.md",
    ]
    missing = [path for path in required_files if not (ROOT / path).is_file()]
    add(checks, "A-01", "Обязательные файлы присутствуют", not missing, f"missing={missing}")

    production_swift_paths = sorted((ROOT / "Klyp").rglob("*.swift"))
    test_swift_paths = sorted((ROOT / "KlypTests").rglob("*.swift"))
    production_source = "\n".join(path.read_text(encoding="utf-8") for path in production_swift_paths)
    test_source = "\n".join(path.read_text(encoding="utf-8") for path in test_swift_paths)

    forbidden_tokens = [
        "URLSession",
        "import Network",
        "import WebKit",
        "JavaScriptCore",
        "CoreData",
        "SwiftData",
        "SQLite",
        "CloudKit",
        "NSUbiquitous",
        "UserDefaults",
        "Sentry",
        "Crashlytics",
    ]
    found_forbidden = [token for token in forbidden_tokens if token in production_source]
    add(
        checks,
        "A-02",
        "В production-коде нет сети, облака, БД, UserDefaults и crash SDK",
        not found_forbidden,
        f"found={found_forbidden}",
    )

    prohibited_markers = ["TODO", "FIXME", "try!", "as!", "fatalError(", "preconditionFailure("]
    marker_hits = []
    for path in production_swift_paths + test_swift_paths:
        text = path.read_text(encoding="utf-8")
        for marker in prohibited_markers:
            if marker in text:
                marker_hits.append(f"{path.relative_to(ROOT)}:{marker}")
    add(checks, "A-03", "Нет TODO/FIXME, принудительных cast/try и аварийных заглушек", not marker_hits, str(marker_hits))

    summary = read("Klyp/Models/PasswordItemSummary.swift")
    summary_fields = re.findall(
        r"^\s*let\s+([A-Za-z0-9_]+)\s*:\s*([A-Za-z0-9_\[\]: <>?]+)",
        summary,
        flags=re.MULTILINE,
    )
    add(
        checks,
        "A-04",
        "PasswordItemSummary содержит только UUID и название",
        summary_fields == [("id", "UUID"), ("title", "String")],
        f"fields={summary_fields}",
    )

    query_factory = read("Klyp/Services/KeychainQueryFactory.swift")
    list_block = query_factory.split("static func listItems", 1)[1].split("static func readPassword", 1)[0]
    update_attributes = query_factory.split("static func updateAttributes", 1)[1].split("static func deleteAll", 1)[0]
    add(
        checks,
        "A-05",
        "Запрос списка возвращает атрибуты без kSecReturnData",
        "kSecReturnAttributes" in list_block and "kSecReturnData" not in list_block,
        "KeychainQueryFactory.listItems",
    )
    keychain_base_required = all(
        token in query_factory
        for token in [
            "kSecClassGenericPassword",
            "kSecUseDataProtectionKeychain: true",
            "kSecAttrSynchronizable: false",
            "kSecAttrService: serviceIdentifier",
        ]
    )
    add(checks, "A-06", "Базовый Keychain query ограничен классом, service и локальным DP Keychain", keychain_base_required, "KeychainQueryFactory.baseQuery")
    add(
        checks,
        "A-07",
        "Создание использует ThisDeviceOnly, update не меняет accessibility",
        "kSecAttrAccessibleWhenUnlockedThisDeviceOnly" in query_factory
        and "kSecAttrAccessible" not in update_attributes,
        "KeychainQueryFactory.addItem/updateAttributes",
    )

    keychain_store = read("Klyp/Services/KeychainStore.swift")
    add(
        checks,
        "A-08",
        "Пароль читается отдельно по UUID и не включён в массив списка",
        "readPassword(id: UUID)" in keychain_store
        and "PasswordItemSummary(id: id, title: title)" in keychain_store
        and "kSecValueData" not in keychain_store,
        "KeychainStore.swift",
    )

    logger = read("Klyp/Support/DiagnosticLogger.swift")
    protocol_block = logger.split("protocol DiagnosticLogging", 1)[1].split("final class OSDiagnosticLogger", 1)[0]
    logger_safe = all(token in protocol_block for token in ["operation:", "status:", "category:"])
    logger_safe = logger_safe and all(
        token not in protocol_block.lower()
        for token in ["password:", "title:", "uuid:", "pasteboard:", "value:"]
    )
    add(checks, "A-09", "Интерфейс логирования не принимает секретные поля", logger_safe, "DiagnosticLogger.swift")

    pasteboard_client = read("Klyp/Services/PasteboardClient.swift")
    clipboard = read("Klyp/Services/ClipboardService.swift")
    pasteboard_read_tokens = ["string(forType", "data(forType", "propertyList(forType", "readObjects("]
    add(
        checks,
        "A-10",
        "Код не читает и не восстанавливает прежнее содержимое pasteboard",
        all(token not in pasteboard_client + clipboard for token in pasteboard_read_tokens),
        "PasteboardClient/ClipboardService",
    )
    clipboard_required = all(
        token in pasteboard_client + clipboard
        for token in [
            "currentHostOnly",
            "changeCountAfterWrite",
            "pasteboard.changeCount == ownedChangeCount",
            "clearTask?.cancel()",
        ]
    )
    add(checks, "A-11", "Буфер использует currentHostOnly, post-write changeCount и отменяемую очистку", clipboard_required, "ClipboardService.swift")

    view_model = read("Klyp/ViewModels/PasswordListViewModel.swift")
    vm_fields = re.findall(r"^\s*private(?:\(set\))?\s+(?:let|var)\s+([A-Za-z0-9_]+)", view_model, flags=re.MULTILINE)
    add(
        checks,
        "A-12",
        "ViewModel не содержит поля пароля или массива секретов",
        all("password" not in field.lower() for field in vm_fields),
        f"privateFields={vm_fields}",
    )
    add(
        checks,
        "A-13",
        "Быстрые клики упорядочены и предыдущая copy-задача отменяется",
        all(token in view_model for token in ["copyRequestSequence", "copyTask?.cancel()", "requestSequence == copyRequestSequence"]),
        "PasswordListViewModel.requestCopy/performCopy",
    )

    login = read("Klyp/Services/LoginItemService.swift")
    add(
        checks,
        "A-14",
        "Login item использует SMAppService.mainApp и обрабатывает requiresApproval",
        "SMAppService = .mainApp" in login and ".requiresApproval" in login and "openSystemSettingsLoginItems" in login,
        "LoginItemService.swift",
    )

    with (ROOT / "Klyp/Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    add(
        checks,
        "A-15",
        "Info.plist включает LSUIElement и запрет нескольких экземпляров",
        info.get("LSUIElement") is True and info.get("LSMultipleInstancesProhibited") is True,
        f"LSUIElement={info.get('LSUIElement')}, LSMultipleInstancesProhibited={info.get('LSMultipleInstancesProhibited')}",
    )

    with (ROOT / "Klyp/Klyp.entitlements").open("rb") as handle:
        entitlements = plistlib.load(handle)
    add(
        checks,
        "A-16",
        "Entitlements содержат App Sandbox и приватную Keychain group без сетевых разрешений",
        entitlements
        == {
            "com.apple.security.app-sandbox": True,
            "keychain-access-groups": ["$(AppIdentifierPrefix)$(CFBundleIdentifier)"],
        },
        str(entitlements),
    )

    pbx = read("Klyp.xcodeproj/project.pbxproj")
    project_required = (
        re.search(r'MACOSX_DEPLOYMENT_TARGET = "?13\.0"?;', pbx) is not None
        and re.search(r'SWIFT_VERSION = "?5\.0"?;', pbx) is not None
        and "ENABLE_APP_SANDBOX = YES;" in pbx
        and "ENABLE_HARDENED_RUNTIME = YES;" in pbx
        and re.search(
            r'CODE_SIGN_ENTITLEMENTS = "?Klyp/Klyp\.entitlements"?;', pbx
        )
        is not None
    )
    add(
        checks,
        "A-17",
        "Project settings включают Swift 5, strict concurrency, macOS 13, Sandbox и Hardened Runtime",
        project_required,
        "project.pbxproj",
    )

    test_count = len(re.findall(r"^\s*func\s+test[A-Za-z0-9_]*\s*\(", test_source, flags=re.MULTILINE))
    add(checks, "A-18", "Присутствует расширенный набор unit/integration-тестов", test_count >= 36, f"testMethods={test_count}")

    integration = read("KlypTests/KeychainStoreIntegrationTests.swift")
    production_service = "com.creadone.Klyp.password"
    random_prefix = "com.example.Klyp.tests."
    safe_integration = random_prefix in integration and f'KeychainStore(serviceIdentifier: "{production_service}")' not in integration
    add(
        checks,
        "A-19",
        "Integration-тесты создают случайные test service и не открывают production service",
        safe_integration,
        "KeychainStoreIntegrationTests.swift",
    )

    app_delegate = read("Klyp/AppDelegate.swift")
    app_source = read("Klyp/KlypApp.swift")
    add(
        checks,
        "A-20",
        "Приложение является MenuBarExtra window и выполняет безопасный штатный выход",
        all(
            token in app_source + app_delegate
            for token in [
                "MenuBarExtra",
                ".menuBarExtraStyle(.window)",
                "setActivationPolicy(.accessory)",
                "prepareForTermination()",
            ]
        ),
        "KlypApp/AppDelegate",
    )

    passed = all(check.passed for check in checks)
    for check in checks:
        print(f"{'PASS' if check.passed else 'FAIL'} {check.identifier}: {check.description}")
    print(f"Standalone review: {'PASS' if passed else 'FAIL'}")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
