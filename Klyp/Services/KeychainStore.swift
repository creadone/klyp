import Foundation
import Security

actor KeychainStore: KeychainStoring {
  private struct StoredItem {
    let summary: PasswordItemSummary
    let orderValue: Double
  }

  private let serviceIdentifier: String
  private let logger: any DiagnosticLogging
  private let sorter = PasswordItemSorter()

  init(
    serviceIdentifier: String = AppConstants.keychainServiceIdentifier,
    logger: any DiagnosticLogging = OSDiagnosticLogger()
  ) {
    self.serviceIdentifier = serviceIdentifier
    self.logger = logger
  }

  func listItems() async throws -> KeychainItemList {
    let query = KeychainQueryFactory.listItems(serviceIdentifier: serviceIdentifier)
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    if status == errSecItemNotFound {
      return KeychainItemList(items: [], skippedCorruptedItems: 0)
    }

    guard status == errSecSuccess else {
      throw mappedError(for: status, operation: .listItems)
    }

    let loaded = storedItems(from: try attributeDictionaries(from: result))
    let orderValues = Dictionary(
      uniqueKeysWithValues: loaded.items.map { ($0.summary.id, $0.orderValue) }
    )
    let items = sorter.sorted(
      loaded.items.map(\.summary),
      orderValues: orderValues
    )

    return KeychainItemList(
      items: items,
      skippedCorruptedItems: loaded.skippedCorruptedItems
    )
  }

  func readPassword(id: UUID) async throws -> String {
    let query = KeychainQueryFactory.readPassword(
      serviceIdentifier: serviceIdentifier,
      id: id
    )
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    guard status == errSecSuccess else {
      throw mappedError(for: status, operation: .readPassword)
    }

    guard
      let data = result as? Data,
      let password = String(data: data, encoding: .utf8)
    else {
      logger.log(
        operation: .readPassword,
        status: errSecDecode,
        category: .invalidData
      )
      throw KeychainStoreError.invalidUTF8
    }

    return password
  }

  func addItem(title: String, password: String) async throws -> PasswordItemSummary {
    try await addItem(id: UUID(), title: title, password: password)
  }

  func updateItem(id: UUID, title: String, password: String) async throws {
    let query = KeychainQueryFactory.updateQuery(
      serviceIdentifier: serviceIdentifier,
      id: id
    )
    let attributes = KeychainQueryFactory.updateAttributes(
      title: title,
      passwordData: Data(password.utf8)
    )
    let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

    guard status == errSecSuccess else {
      throw mappedError(for: status, operation: .updateItem)
    }
  }

  func setItemOrder(of id: UUID, orderedItemIDs: [UUID]) async throws {
    let loaded = try loadStoredItems()
    let itemsByID = Dictionary(
      uniqueKeysWithValues: loaded.items.map { ($0.summary.id, $0) }
    )

    guard
      itemsByID[id] != nil,
      Set(orderedItemIDs).count == orderedItemIDs.count,
      Set(orderedItemIDs) == Set(itemsByID.keys),
      let targetIndex = orderedItemIDs.firstIndex(of: id)
    else {
      throw mappedError(for: errSecItemNotFound, operation: .reorderItems)
    }

    let leftOrder =
      targetIndex > 0
      ? itemsByID[orderedItemIDs[targetIndex - 1]]?.orderValue
      : nil
    let rightOrder =
      targetIndex + 1 < orderedItemIDs.count
      ? itemsByID[orderedItemIDs[targetIndex + 1]]?.orderValue
      : nil

    if let orderValue = orderValue(between: leftOrder, and: rightOrder) {
      try persistOrderValue(orderValue, for: id)
    } else {
      try normalizeOrder(orderedItemIDs)
    }
  }

  func deleteItem(id: UUID) async throws {
    let query = KeychainQueryFactory.updateQuery(
      serviceIdentifier: serviceIdentifier,
      id: id
    )
    let status = SecItemDelete(query as CFDictionary)

    guard status == errSecSuccess else {
      throw mappedError(for: status, operation: .deleteItem)
    }
  }

  func deleteAllItems() async throws {
    let query = KeychainQueryFactory.deleteAll(serviceIdentifier: serviceIdentifier)
    let status = SecItemDelete(query as CFDictionary)

    if status == errSecItemNotFound {
      return
    }

    guard status == errSecSuccess else {
      throw mappedError(for: status, operation: .deleteAllItems)
    }
  }

  func addItem(id: UUID, title: String, password: String) async throws -> PasswordItemSummary {
    let orderValue = try nextOrderValue()
    let attributes = KeychainQueryFactory.addItem(
      serviceIdentifier: serviceIdentifier,
      id: id,
      title: title,
      passwordData: Data(password.utf8),
      orderValue: orderValue
    )
    let status = SecItemAdd(attributes as CFDictionary, nil)

    guard status == errSecSuccess else {
      throw mappedError(for: status, operation: .addItem)
    }

    return PasswordItemSummary(id: id, title: title)
  }

  private func loadStoredItems() throws -> (
    items: [StoredItem],
    skippedCorruptedItems: Int
  ) {
    let query = KeychainQueryFactory.listItems(serviceIdentifier: serviceIdentifier)
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    if status == errSecItemNotFound {
      return ([], 0)
    }

    guard status == errSecSuccess else {
      throw mappedError(for: status, operation: .listItems)
    }

    return storedItems(from: try attributeDictionaries(from: result))
  }

  private func storedItems(
    from dictionaries: [[String: Any]]
  ) -> (items: [StoredItem], skippedCorruptedItems: Int) {
    var items: [StoredItem] = []
    var skippedCorruptedItems = 0
    var hasInvalidOrderData = false

    for attributes in dictionaries {
      guard
        let account = attributes[kSecAttrAccount as String] as? String,
        let id = UUID(uuidString: account),
        let title = attributes[kSecAttrLabel as String] as? String,
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        skippedCorruptedItems += 1
        continue
      }

      let genericData = attributes[kSecAttrGeneric as String] as? Data
      let storedOrder = genericData.flatMap(decodeOrderValue)
      if genericData != nil, storedOrder == nil {
        hasInvalidOrderData = true
      }

      let creationDate = attributes[kSecAttrCreationDate as String] as? Date
      let fallbackOrder = creationDate?.timeIntervalSinceReferenceDate ?? 0
      items.append(
        StoredItem(
          summary: PasswordItemSummary(id: id, title: title),
          orderValue: storedOrder ?? fallbackOrder
        )
      )
    }

    if skippedCorruptedItems > 0 || hasInvalidOrderData {
      logger.log(
        operation: .listItems,
        status: errSecDecode,
        category: .invalidData
      )
    }

    return (items, skippedCorruptedItems)
  }

  private func decodeOrderValue(_ data: Data) -> Double? {
    guard
      let string = String(data: data, encoding: .utf8),
      let value = Double(string),
      value.isFinite
    else {
      return nil
    }

    return value
  }

  private func nextOrderValue() throws -> Double {
    let maximum = try loadStoredItems().items.map(\.orderValue).max()
    return (maximum ?? -1) + 1
  }

  private func orderValue(between left: Double?, and right: Double?) -> Double? {
    switch (left, right) {
    case (nil, nil):
      return 0
    case (.some(let left), nil):
      return left + 1
    case (nil, .some(let right)):
      return right - 1
    case (.some(let left), .some(let right)):
      guard left < right else {
        return nil
      }

      let midpoint = left + ((right - left) / 2)
      return midpoint > left && midpoint < right ? midpoint : nil
    }
  }

  private func persistOrderValue(_ value: Double, for id: UUID) throws {
    let query = KeychainQueryFactory.updateQuery(
      serviceIdentifier: serviceIdentifier,
      id: id
    )
    let attributes = KeychainQueryFactory.updateOrderAttributes(orderValue: value)
    let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

    guard status == errSecSuccess else {
      throw mappedError(for: status, operation: .reorderItems)
    }
  }

  private func normalizeOrder(_ orderedItemIDs: [UUID]) throws {
    for (index, id) in orderedItemIDs.enumerated() {
      try persistOrderValue(Double(index), for: id)
    }
  }

  private func attributeDictionaries(from result: CFTypeRef?) throws -> [[String: Any]] {
    if let dictionaries = result as? [[String: Any]] {
      return dictionaries
    }

    if let dictionary = result as? [String: Any] {
      return [dictionary]
    }

    logger.log(
      operation: .listItems,
      status: errSecDecode,
      category: .invalidData
    )
    throw KeychainStoreError.unexpectedResult
  }

  private func mappedError(
    for status: OSStatus,
    operation: DiagnosticOperation
  ) -> KeychainStoreError {
    let error: KeychainStoreError
    let category: DiagnosticCategory

    switch status {
    case errSecDuplicateItem:
      error = .duplicateItem
      category = .duplicate
    case errSecItemNotFound:
      error = .itemNotFound
      category = .notFound
    case errSecInteractionNotAllowed:
      error = .interactionNotAllowed
      category = .interactionNotAllowed
    case errSecNotAvailable:
      error = .keychainUnavailable
      category = .unavailable
    default:
      error = .operationFailed(status: status)
      category = .system
    }

    logger.log(operation: operation, status: status, category: category)
    return error
  }
}
