import Foundation

@testable import Klyp

actor FakeKeychainStore: KeychainStoring {
  struct Record: Sendable {
    var title: String
    var password: String
  }

  private var records: [UUID: Record]
  private var itemOrder: [UUID]
  private var listResultOverride: KeychainItemList?
  private var listError: KeychainStoreError?
  private var readError: KeychainStoreError?
  private var readDelays: [UUID: Duration] = [:]
  private var addError: KeychainStoreError?
  private var updateError: KeychainStoreError?
  private var deleteError: KeychainStoreError?
  private var deleteAllError: KeychainStoreError?
  private var reorderError: KeychainStoreError?
  private var addDelay: Duration?

  private(set) var listCallCount = 0
  private(set) var readCallCount = 0
  private(set) var addCallCount = 0
  private(set) var updateCallCount = 0
  private(set) var deleteCallCount = 0
  private(set) var deleteAllCallCount = 0
  private(set) var reorderCallCount = 0

  init(records: [UUID: Record] = [:], itemOrder: [UUID]? = nil) {
    self.records = records
    self.itemOrder = itemOrder ?? records.keys.sorted { $0.uuidString < $1.uuidString }
  }

  func listItems() async throws -> KeychainItemList {
    listCallCount += 1

    if let listError {
      throw listError
    }

    if let listResultOverride {
      return listResultOverride
    }

    return KeychainItemList(
      items: orderedItems(),
      skippedCorruptedItems: 0
    )
  }

  func readPassword(id: UUID) async throws -> String {
    readCallCount += 1

    if let delay = readDelays[id] {
      try await ContinuousClock().sleep(for: delay)
    }

    if let readError {
      throw readError
    }

    guard let record = records[id] else {
      throw KeychainStoreError.itemNotFound
    }

    return record.password
  }

  func addItem(title: String, password: String) async throws -> PasswordItemSummary {
    addCallCount += 1

    if let addDelay {
      try await ContinuousClock().sleep(for: addDelay)
    }

    if let addError {
      throw addError
    }

    let id = UUID()
    records[id] = Record(title: title, password: password)
    itemOrder.append(id)
    return PasswordItemSummary(id: id, title: title)
  }

  func updateItem(id: UUID, title: String, password: String) async throws {
    updateCallCount += 1

    if let updateError {
      throw updateError
    }

    guard records[id] != nil else {
      throw KeychainStoreError.itemNotFound
    }

    records[id] = Record(title: title, password: password)
  }

  func deleteItem(id: UUID) async throws {
    deleteCallCount += 1

    if let deleteError {
      throw deleteError
    }

    guard records.removeValue(forKey: id) != nil else {
      throw KeychainStoreError.itemNotFound
    }
    itemOrder.removeAll { $0 == id }
  }

  func setItemOrder(of id: UUID, orderedItemIDs: [UUID]) async throws {
    reorderCallCount += 1

    if let reorderError {
      throw reorderError
    }

    guard
      records[id] != nil,
      Set(orderedItemIDs) == Set(records.keys),
      orderedItemIDs.count == records.count
    else {
      throw KeychainStoreError.itemNotFound
    }

    itemOrder = orderedItemIDs
  }

  func deleteAllItems() async throws {
    deleteAllCallCount += 1

    if let deleteAllError {
      throw deleteAllError
    }

    records.removeAll()
    itemOrder.removeAll()
  }

  func setListResult(_ result: KeychainItemList?) {
    listResultOverride = result
  }

  func setListError(_ error: KeychainStoreError?) {
    listError = error
  }

  func setReadError(_ error: KeychainStoreError?) {
    readError = error
  }

  func setReadDelay(_ delay: Duration?, for id: UUID) {
    readDelays[id] = delay
  }

  func setAddError(_ error: KeychainStoreError?) {
    addError = error
  }

  func setUpdateError(_ error: KeychainStoreError?) {
    updateError = error
  }

  func setDeleteError(_ error: KeychainStoreError?) {
    deleteError = error
  }

  func setDeleteAllError(_ error: KeychainStoreError?) {
    deleteAllError = error
  }

  func setReorderError(_ error: KeychainStoreError?) {
    reorderError = error
  }

  func setAddDelay(_ delay: Duration?) {
    addDelay = delay
  }

  func record(id: UUID) -> Record? {
    records[id]
  }

  func allRecords() -> [UUID: Record] {
    records
  }

  func orderedItemIDs() -> [UUID] {
    itemOrder
  }

  private func orderedItems() -> [PasswordItemSummary] {
    let knownItems = itemOrder.compactMap { id -> PasswordItemSummary? in
      guard let record = records[id] else {
        return nil
      }
      return PasswordItemSummary(id: id, title: record.title)
    }
    let knownIDs = Set(knownItems.map(\.id))
    let missingItems = records
      .filter { !knownIDs.contains($0.key) }
      .sorted { $0.key.uuidString < $1.key.uuidString }
      .map { PasswordItemSummary(id: $0.key, title: $0.value.title) }
    return knownItems + missingItems
  }
}

@MainActor
final class FakeClipboardService: ClipboardServicing {
  private(set) var copiedValues: [String] = []
  private(set) var clearCallCount = 0
  private(set) var cancelCallCount = 0
  var nextError: ClipboardServiceError?

  func copy(_ value: String) throws {
    if let nextError {
      self.nextError = nil
      throw nextError
    }

    copiedValues.append(value)
  }

  func clearIfOwned() {
    clearCallCount += 1
  }

  func cancelScheduledClear() {
    cancelCallCount += 1
  }
}

@MainActor
final class FakeLoginItemService: LoginItemServicing {
  var status: LoginItemStatus
  var nextError: LoginItemServiceError?
  private(set) var setEnabledCalls: [Bool] = []
  private(set) var openSettingsCallCount = 0

  init(status: LoginItemStatus = .disabled) {
    self.status = status
  }

  func currentStatus() -> LoginItemStatus {
    status
  }

  func setEnabled(_ enabled: Bool) throws -> LoginItemStatus {
    setEnabledCalls.append(enabled)

    if let nextError {
      self.nextError = nil
      throw nextError
    }

    status = enabled ? .enabled : .disabled
    return status
  }

  func openSystemSettings() {
    openSettingsCallCount += 1
  }
}

@MainActor
final class FakePasteboardClient: PasteboardClient {
  private(set) var storedString: String?
  private(set) var changeCount = 0
  private(set) var prepareCurrentHostOnlyValues: [Bool] = []
  private(set) var clearCallCount = 0
  var shouldWriteSucceed = true
  var shouldClearSucceed = true

  @discardableResult
  func prepareForNewContents(currentHostOnly: Bool) -> Int {
    prepareCurrentHostOnlyValues.append(currentHostOnly)
    storedString = nil
    changeCount += 1
    return changeCount
  }

  func writeString(_ value: String) -> Bool {
    guard shouldWriteSucceed else {
      return false
    }

    storedString = value
    changeCount += 1
    return true
  }

  @discardableResult
  func clearContents() -> Bool {
    clearCallCount += 1

    guard shouldClearSucceed else {
      return false
    }

    storedString = nil
    changeCount += 1
    return true
  }

  func externalWrite(_ value: String) {
    storedString = value
    changeCount += 1
  }
}

struct FixedDelayClipboardSleeper: ClipboardSleeping {
  let delay: Duration

  func sleep(for duration: Duration) async throws {
    try await ContinuousClock().sleep(for: delay)
  }
}

struct LongClipboardSleeper: ClipboardSleeping {
  func sleep(for duration: Duration) async throws {
    try await ContinuousClock().sleep(for: .seconds(60))
  }
}

@MainActor
func makeViewModel(
  keychainStore: FakeKeychainStore,
  clipboardService: FakeClipboardService = FakeClipboardService(),
  loginItemService: FakeLoginItemService = FakeLoginItemService()
) -> PasswordListViewModel {
  PasswordListViewModel(
    keychainStore: keychainStore,
    clipboardService: clipboardService,
    loginItemService: loginItemService,
    validator: PasswordValidator(locale: Locale(identifier: "ru_RU"))
  )
}
