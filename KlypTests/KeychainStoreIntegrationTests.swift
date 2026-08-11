import Foundation
import Security
import XCTest

@testable import Klyp

final class KeychainStoreIntegrationTests: XCTestCase {
  private var serviceIdentifier = ""
  private var store = KeychainStore(serviceIdentifier: "com.example.Klyp.tests.placeholder")
  private var additionalServiceIdentifiers: [String] = []

  override func setUp() async throws {
    try await super.setUp()
    serviceIdentifier = "com.example.Klyp.tests.\(UUID().uuidString)"
    XCTAssertTrue(serviceIdentifier.hasPrefix("com.example.Klyp.tests."))
    XCTAssertNotEqual(serviceIdentifier, AppConstants.keychainServiceIdentifier)
    store = KeychainStore(serviceIdentifier: serviceIdentifier)
  }

  override func tearDown() async throws {
    try await store.deleteAllItems()

    for serviceIdentifier in additionalServiceIdentifiers {
      try await KeychainStore(serviceIdentifier: serviceIdentifier).deleteAllItems()
    }

    additionalServiceIdentifiers = []
    try await super.tearDown()
  }

  func testAddReadAndListWithoutPasswords() async throws {
    let item = try await store.addItem(
      title: "GitHub — личный",
      password: "test-password"
    )

    let password = try await store.readPassword(id: item.id)
    let list = try await store.listItems()

    XCTAssertEqual(password, "test-password")
    XCTAssertEqual(list.items, [item])
    XCTAssertEqual(list.skippedCorruptedItems, 0)
    XCTAssertFalse(
      Mirror(reflecting: list.items[0]).children
        .compactMap(\.label)
        .contains("password")
    )
  }

  func testUpdateTitleAndPasswordPreservesAccessibilityClass() async throws {
    let item = try await store.addItem(title: "Старое", password: "old")
    let before = try attributes(for: item.id, serviceIdentifier: serviceIdentifier)

    try await store.updateItem(id: item.id, title: "Новое", password: "new")

    let after = try attributes(for: item.id, serviceIdentifier: serviceIdentifier)
    let password = try await store.readPassword(id: item.id)
    let list = try await store.listItems()

    XCTAssertEqual(password, "new")
    XCTAssertEqual(list.items, [PasswordItemSummary(id: item.id, title: "Новое")])
    XCTAssertEqual(
      before[kSecAttrAccessible as String] as? String,
      kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
    )
    XCTAssertEqual(
      after[kSecAttrAccessible as String] as? String,
      before[kSecAttrAccessible as String] as? String
    )
    XCTAssertEqual(
      after[kSecAttrGeneric as String] as? Data,
      before[kSecAttrGeneric as String] as? Data
    )
  }

  func testNewItemsAreListedInInsertionOrder() async throws {
    let first = try await store.addItem(title: "Z", password: "1")
    let second = try await store.addItem(title: "A", password: "2")
    let third = try await store.addItem(title: "M", password: "3")

    let list = try await store.listItems()

    XCTAssertEqual(list.items.map(\.id), [first.id, second.id, third.id])
  }

  func testLegacyItemsWithoutStoredOrderUseCreationDate() async throws {
    let firstID = UUID()
    let secondID = UUID()
    XCTAssertEqual(
      addRawItem(
        serviceIdentifier: serviceIdentifier,
        account: firstID.uuidString,
        label: "Первый",
        data: Data("one".utf8)
      ),
      errSecSuccess
    )
    try await ContinuousClock().sleep(for: .milliseconds(1_100))
    XCTAssertEqual(
      addRawItem(
        serviceIdentifier: serviceIdentifier,
        account: secondID.uuidString,
        label: "Второй",
        data: Data("two".utf8)
      ),
      errSecSuccess
    )

    let list = try await store.listItems()

    XCTAssertEqual(list.items.map(\.id), [firstID, secondID])
  }

  func testManualOrderPersistsWithoutChangingPasswords() async throws {
    let first = try await store.addItem(title: "A", password: "first")
    let second = try await store.addItem(title: "B", password: "second")
    let third = try await store.addItem(title: "C", password: "third")

    try await store.setItemOrder(
      of: third.id,
      orderedItemIDs: [third.id, first.id, second.id]
    )

    let list = try await store.listItems()
    let firstPassword = try await store.readPassword(id: first.id)
    let secondPassword = try await store.readPassword(id: second.id)
    let thirdPassword = try await store.readPassword(id: third.id)
    XCTAssertEqual(list.items.map(\.id), [third.id, first.id, second.id])
    XCTAssertEqual(firstPassword, "first")
    XCTAssertEqual(secondPassword, "second")
    XCTAssertEqual(thirdPassword, "third")

    let newItem = try await store.addItem(title: "D", password: "new")
    let listAfterAdd = try await store.listItems()
    XCTAssertEqual(
      listAfterAdd.items.map(\.id),
      [third.id, first.id, second.id, newItem.id]
    )
  }

  func testDeleteAndItemNotFound() async throws {
    let item = try await store.addItem(title: "Удалить", password: "test")

    try await store.deleteItem(id: item.id)

    do {
      _ = try await store.readPassword(id: item.id)
      XCTFail("Ожидалась ошибка itemNotFound")
    } catch {
      XCTAssertEqual(error as? KeychainStoreError, .itemNotFound)
    }
  }

  func testDeleteAllIsScopedToServiceIdentifier() async throws {
    let otherService = "com.example.Klyp.tests.other.\(UUID().uuidString)"
    additionalServiceIdentifiers.append(otherService)
    let otherStore = KeychainStore(serviceIdentifier: otherService)

    _ = try await store.addItem(title: "Klyp", password: "one")
    let otherItem = try await otherStore.addItem(title: "Other", password: "two")

    try await store.deleteAllItems()

    let localItems = try await store.listItems().items
    let otherPassword = try await otherStore.readPassword(id: otherItem.id)
    XCTAssertTrue(localItems.isEmpty)
    XCTAssertEqual(otherPassword, "two")
  }

  func testDuplicateItemIsTyped() async throws {
    let id = UUID()
    _ = try await store.addItem(id: id, title: "Первый", password: "one")

    do {
      _ = try await store.addItem(id: id, title: "Второй", password: "two")
      XCTFail("Ожидалась duplicateItem")
    } catch {
      XCTAssertEqual(error as? KeychainStoreError, .duplicateItem)
    }
  }

  func testUnicodeAndSignificantWhitespaceRoundTrip() async throws {
    let password = "  P@ss/\"\\[]{}:=+🙂  "
    let item = try await store.addItem(
      title: "Сервер Δ / 测试",
      password: password
    )

    let readPassword = try await store.readPassword(id: item.id)
    let title = try await store.listItems().items.first?.title
    XCTAssertEqual(readPassword, password)
    XCTAssertEqual(title, "Сервер Δ / 测试")
  }

  func testItemIsNotSynchronizableAndUsesDataProtectionKeychain() async throws {
    let item = try await store.addItem(title: "Локальный", password: "test")

    let localStatus = copyMatchingStatus(
      serviceIdentifier: serviceIdentifier,
      id: item.id,
      synchronizable: false
    )
    let synchronizableStatus = copyMatchingStatus(
      serviceIdentifier: serviceIdentifier,
      id: item.id,
      synchronizable: true
    )

    XCTAssertEqual(localStatus, errSecSuccess)
    XCTAssertEqual(synchronizableStatus, errSecItemNotFound)
  }

  func testCorruptedAccountIsSkippedWhileValidRecordRemains() async throws {
    let valid = try await store.addItem(title: "Корректный", password: "test")
    let status = addRawItem(
      serviceIdentifier: serviceIdentifier,
      account: "not-a-uuid",
      label: "Повреждённый",
      data: Data("bad".utf8)
    )
    XCTAssertEqual(status, errSecSuccess)

    let list = try await store.listItems()

    XCTAssertEqual(list.items, [valid])
    XCTAssertEqual(list.skippedCorruptedItems, 1)
  }

  func testInvalidUTF8PasswordReturnsTypedError() async throws {
    let id = UUID()
    let status = addRawItem(
      serviceIdentifier: serviceIdentifier,
      account: id.uuidString,
      label: "Некорректный UTF-8",
      data: Data([0xFF, 0xFE])
    )
    XCTAssertEqual(status, errSecSuccess)

    do {
      _ = try await store.readPassword(id: id)
      XCTFail("Ожидалась invalidUTF8")
    } catch {
      XCTAssertEqual(error as? KeychainStoreError, .invalidUTF8)
    }
  }

  func testDeleteMissingItemReturnsTypedError() async {
    do {
      try await store.deleteItem(id: UUID())
      XCTFail("Ожидалась itemNotFound")
    } catch {
      XCTAssertEqual(error as? KeychainStoreError, .itemNotFound)
    }
  }

  private func attributes(
    for id: UUID,
    serviceIdentifier: String
  ) throws -> [String: Any] {
    var query = KeychainQueryFactory.updateQuery(
      serviceIdentifier: serviceIdentifier,
      id: id
    )
    query[kSecReturnAttributes] = true
    query[kSecMatchLimit] = kSecMatchLimitOne

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess, let attributes = result as? [String: Any] else {
      throw KeychainStoreError.operationFailed(status: status)
    }
    return attributes
  }

  private func copyMatchingStatus(
    serviceIdentifier: String,
    id: UUID,
    synchronizable: Bool
  ) -> OSStatus {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecUseDataProtectionKeychain: true,
      kSecAttrSynchronizable: synchronizable,
      kSecAttrService: serviceIdentifier,
      kSecAttrAccount: id.uuidString,
      kSecMatchLimit: kSecMatchLimitOne,
      kSecReturnAttributes: true,
    ]

    var result: CFTypeRef?
    return SecItemCopyMatching(query as CFDictionary, &result)
  }

  private func addRawItem(
    serviceIdentifier: String,
    account: String,
    label: String,
    data: Data
  ) -> OSStatus {
    let attributes: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecUseDataProtectionKeychain: true,
      kSecAttrSynchronizable: false,
      kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
      kSecAttrService: serviceIdentifier,
      kSecAttrAccount: account,
      kSecAttrLabel: label,
      kSecValueData: data,
    ]

    return SecItemAdd(attributes as CFDictionary, nil)
  }
}
