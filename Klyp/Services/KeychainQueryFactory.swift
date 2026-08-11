import Foundation
import Security

enum KeychainQueryFactory {
  static func listItems(serviceIdentifier: String) -> [CFString: Any] {
    var query = baseQuery(serviceIdentifier: serviceIdentifier)
    query[kSecReturnAttributes] = true
    query[kSecMatchLimit] = kSecMatchLimitAll
    return query
  }

  static func readPassword(serviceIdentifier: String, id: UUID) -> [CFString: Any] {
    var query = itemQuery(serviceIdentifier: serviceIdentifier, id: id)
    query[kSecReturnData] = true
    query[kSecMatchLimit] = kSecMatchLimitOne
    return query
  }

  static func addItem(
    serviceIdentifier: String,
    id: UUID,
    title: String,
    passwordData: Data,
    orderValue: Double
  ) -> [CFString: Any] {
    var attributes = itemQuery(serviceIdentifier: serviceIdentifier, id: id)
    attributes[kSecAttrLabel] = title
    attributes[kSecAttrGeneric] = orderData(for: orderValue)
    attributes[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    attributes[kSecValueData] = passwordData
    return attributes
  }

  static func updateQuery(serviceIdentifier: String, id: UUID) -> [CFString: Any] {
    itemQuery(serviceIdentifier: serviceIdentifier, id: id)
  }

  static func updateAttributes(title: String, passwordData: Data) -> [CFString: Any] {
    [
      kSecAttrLabel: title,
      kSecValueData: passwordData,
    ]
  }

  static func updateOrderAttributes(orderValue: Double) -> [CFString: Any] {
    [kSecAttrGeneric: orderData(for: orderValue)]
  }

  static func deleteAll(serviceIdentifier: String) -> [CFString: Any] {
    baseQuery(serviceIdentifier: serviceIdentifier)
  }

  private static func baseQuery(serviceIdentifier: String) -> [CFString: Any] {
    [
      kSecClass: kSecClassGenericPassword,
      kSecUseDataProtectionKeychain: true,
      kSecAttrSynchronizable: false,
      kSecAttrService: serviceIdentifier,
    ]
  }

  private static func itemQuery(serviceIdentifier: String, id: UUID) -> [CFString: Any] {
    var query = baseQuery(serviceIdentifier: serviceIdentifier)
    query[kSecAttrAccount] = id.uuidString
    return query
  }

  private static func orderData(for value: Double) -> Data {
    Data(String(value).utf8)
  }
}
