import Foundation

@MainActor
protocol ClipboardServicing: AnyObject {
  func copy(_ value: String) throws
  func clearIfOwned()
  func cancelScheduledClear()
}

enum LoginItemStatus: Equatable, Sendable {
  case disabled
  case enabled
  case requiresApproval
  case unavailable
}

@MainActor
protocol LoginItemServicing: AnyObject {
  func currentStatus() -> LoginItemStatus
  func setEnabled(_ enabled: Bool) throws -> LoginItemStatus
  func openSystemSettings()
}

actor HarnessKeychainStore: KeychainStoring {
  struct Record: Sendable {
    var title: String
    var password: String
  }

  private var records: [UUID: Record]
  private var itemOrder: [UUID]
  private var readDelays: [UUID: Duration] = [:]
  private var updateError: KeychainStoreError?
  private var deleteError: KeychainStoreError?

  init(records: [UUID: Record] = [:], itemOrder: [UUID]? = nil) {
    self.records = records
    self.itemOrder = itemOrder ?? records.keys.sorted { $0.uuidString < $1.uuidString }
  }

  func listItems() async throws -> KeychainItemList {
    KeychainItemList(
      items: itemOrder.compactMap { id in
        records[id].map { PasswordItemSummary(id: id, title: $0.title) }
      },
      skippedCorruptedItems: 0
    )
  }

  func readPassword(id: UUID) async throws -> String {
    if let delay = readDelays[id] {
      try await ContinuousClock().sleep(for: delay)
    }
    guard let record = records[id] else {
      throw KeychainStoreError.itemNotFound
    }
    return record.password
  }

  func addItem(title: String, password: String) async throws -> PasswordItemSummary {
    let id = UUID()
    records[id] = Record(title: title, password: password)
    itemOrder.append(id)
    return PasswordItemSummary(id: id, title: title)
  }

  func updateItem(id: UUID, title: String, password: String) async throws {
    if let updateError {
      throw updateError
    }
    guard records[id] != nil else {
      throw KeychainStoreError.itemNotFound
    }
    records[id] = Record(title: title, password: password)
  }

  func deleteItem(id: UUID) async throws {
    if let deleteError {
      throw deleteError
    }
    guard records.removeValue(forKey: id) != nil else {
      throw KeychainStoreError.itemNotFound
    }
    itemOrder.removeAll { $0 == id }
  }

  func setItemOrder(of id: UUID, orderedItemIDs: [UUID]) async throws {
    guard records[id] != nil else {
      throw KeychainStoreError.itemNotFound
    }
    itemOrder = orderedItemIDs
  }

  func deleteAllItems() async throws {
    records.removeAll()
    itemOrder.removeAll()
  }

  func setReadDelay(_ delay: Duration?, for id: UUID) {
    readDelays[id] = delay
  }

  func setUpdateError(_ error: KeychainStoreError?) {
    updateError = error
  }

  func setDeleteError(_ error: KeychainStoreError?) {
    deleteError = error
  }

  func record(id: UUID) -> Record? {
    records[id]
  }
}

@MainActor
final class HarnessClipboardService: ClipboardServicing {
  private(set) var copiedValues: [String] = []
  private(set) var clearCount = 0

  func copy(_ value: String) throws {
    copiedValues.append(value)
  }

  func clearIfOwned() {
    clearCount += 1
  }

  func cancelScheduledClear() {}
}

@MainActor
final class HarnessLoginItemService: LoginItemServicing {
  var status: LoginItemStatus
  private(set) var openSettingsCount = 0
  private(set) var setEnabledCalls: [Bool] = []

  init(status: LoginItemStatus = .disabled) {
    self.status = status
  }

  func currentStatus() -> LoginItemStatus {
    status
  }

  func setEnabled(_ enabled: Bool) throws -> LoginItemStatus {
    setEnabledCalls.append(enabled)
    status = enabled ? .enabled : .disabled
    return status
  }

  func openSystemSettings() {
    openSettingsCount += 1
  }
}
