import Security
import XCTest

@testable import Klyp

final class KeychainQueryFactoryTests: XCTestCase {
  func testListQueryReturnsAttributesWithoutSecretData() {
    let service = "com.example.Klyp.tests.list"
    let query = KeychainQueryFactory.listItems(serviceIdentifier: service)

    XCTAssertEqual(query[kSecClass] as? String, kSecClassGenericPassword as String)
    XCTAssertEqual(query[kSecAttrService] as? String, service)
    XCTAssertEqual(query[kSecUseDataProtectionKeychain] as? Bool, true)
    XCTAssertEqual(query[kSecAttrSynchronizable] as? Bool, false)
    XCTAssertEqual(query[kSecReturnAttributes] as? Bool, true)
    XCTAssertNil(query[kSecReturnData])
    XCTAssertEqual(query[kSecMatchLimit] as? String, kSecMatchLimitAll as String)
  }

  func testReadQueryTargetsOnlyConcreteUUID() {
    let service = "com.example.Klyp.tests.read"
    let id = UUID()
    let query = KeychainQueryFactory.readPassword(
      serviceIdentifier: service,
      id: id
    )

    XCTAssertEqual(query[kSecAttrService] as? String, service)
    XCTAssertEqual(query[kSecAttrAccount] as? String, id.uuidString)
    XCTAssertEqual(query[kSecReturnData] as? Bool, true)
    XCTAssertEqual(query[kSecMatchLimit] as? String, kSecMatchLimitOne as String)
    XCTAssertNil(query[kSecReturnAttributes])
  }

  func testAddQueryUsesLocalThisDeviceOnlyAttributes() {
    let service = "com.example.Klyp.tests.add"
    let id = UUID()
    let passwordData = Data("test-password".utf8)
    let query = KeychainQueryFactory.addItem(
      serviceIdentifier: service,
      id: id,
      title: "Сервер Δ / 测试",
      passwordData: passwordData,
      orderValue: 42.5
    )

    XCTAssertEqual(query[kSecClass] as? String, kSecClassGenericPassword as String)
    XCTAssertEqual(query[kSecUseDataProtectionKeychain] as? Bool, true)
    XCTAssertEqual(query[kSecAttrSynchronizable] as? Bool, false)
    XCTAssertEqual(
      query[kSecAttrAccessible] as? String, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
    XCTAssertEqual(query[kSecAttrService] as? String, service)
    XCTAssertEqual(query[kSecAttrAccount] as? String, id.uuidString)
    XCTAssertEqual(query[kSecAttrLabel] as? String, "Сервер Δ / 测试")
    XCTAssertEqual(query[kSecAttrGeneric] as? Data, Data("42.5".utf8))
    XCTAssertEqual(query[kSecValueData] as? Data, passwordData)
  }

  func testUpdateQueryRetainsDataProtectionAndServiceScope() {
    let service = "com.example.Klyp.tests.update"
    let id = UUID()
    let query = KeychainQueryFactory.updateQuery(
      serviceIdentifier: service,
      id: id
    )

    XCTAssertEqual(query[kSecUseDataProtectionKeychain] as? Bool, true)
    XCTAssertEqual(query[kSecAttrSynchronizable] as? Bool, false)
    XCTAssertEqual(query[kSecAttrService] as? String, service)
    XCTAssertEqual(query[kSecAttrAccount] as? String, id.uuidString)
  }

  func testUpdateDoesNotAttemptToChangeAccessibility() {
    let attributes = KeychainQueryFactory.updateAttributes(
      title: "Новое",
      passwordData: Data("secret".utf8)
    )

    XCTAssertNil(attributes[kSecAttrAccessible])
    XCTAssertEqual(attributes[kSecAttrLabel] as? String, "Новое")
    XCTAssertEqual(attributes[kSecValueData] as? Data, Data("secret".utf8))
  }

  func testOrderUpdateChangesOnlyGenericAttribute() {
    let attributes = KeychainQueryFactory.updateOrderAttributes(orderValue: 17.25)

    XCTAssertEqual(attributes.count, 1)
    XCTAssertEqual(attributes[kSecAttrGeneric] as? Data, Data("17.25".utf8))
    XCTAssertNil(attributes[kSecValueData])
    XCTAssertNil(attributes[kSecAttrLabel])
  }

  func testDeleteAllQueryIsScopedToServiceWithoutAccount() {
    let service = "com.example.Klyp.tests.delete-all"
    let query = KeychainQueryFactory.deleteAll(serviceIdentifier: service)

    XCTAssertEqual(query[kSecAttrService] as? String, service)
    XCTAssertNil(query[kSecAttrAccount])
    XCTAssertEqual(query[kSecUseDataProtectionKeychain] as? Bool, true)
    XCTAssertEqual(query[kSecAttrSynchronizable] as? Bool, false)
  }
}
