import Combine
import Foundation

@MainActor
final class PasswordListViewModel: ObservableObject {
  enum Screen: Equatable {
    case list
    case add
    case edit(PasswordItemSummary)
  }

  enum DialogKind: Equatable {
    case error(message: String)
    case loginItemApprovalRequired
  }

  enum DeletionConfirmation: Equatable {
    case item(PasswordItemSummary)
    case all(itemCount: Int)
  }

  struct DialogState: Identifiable, Equatable {
    let id = UUID()
    let kind: DialogKind
  }

  @Published private(set) var items: [PasswordItemSummary] = []
  @Published private(set) var isLoading = false
  @Published private(set) var hasLoaded = false
  @Published private(set) var loadErrorMessage: String?
  @Published private(set) var warningMessage: String?
  @Published private(set) var isMutationInProgress = false
  @Published private(set) var copiedItemID: UUID?
  @Published private(set) var loginItemStatus: LoginItemStatus = .disabled

  @Published var screen: Screen = .list
  @Published var dialog: DialogState?
  @Published var deletionConfirmation: DeletionConfirmation?

  private let keychainStore: any KeychainStoring
  private let clipboardService: any ClipboardServicing
  private let loginItemService: any LoginItemServicing
  private let validator: PasswordValidator

  private var copyRequestSequence = 0
  private var copyTask: Task<Void, Never>?
  private var feedbackTask: Task<Void, Never>?

  init(
    keychainStore: any KeychainStoring,
    clipboardService: any ClipboardServicing,
    loginItemService: any LoginItemServicing,
    validator: PasswordValidator = PasswordValidator()
  ) {
    self.keychainStore = keychainStore
    self.clipboardService = clipboardService
    self.loginItemService = loginItemService
    self.validator = validator
    loginItemStatus = loginItemService.currentStatus()
  }

  func loadIfNeeded() async {
    refreshLoginItemStatus()

    guard !hasLoaded else {
      return
    }

    await reload()
  }

  func reload() async {
    guard !isLoading else {
      return
    }

    isLoading = true
    loadErrorMessage = nil
    defer { isLoading = false }

    do {
      let result = try await keychainStore.listItems()
      items = result.items
      hasLoaded = true
      warningMessage =
        result.skippedCorruptedItems > 0
        ? "Некоторые повреждённые записи были пропущены"
        : nil
    } catch {
      loadErrorMessage = UserFacingError.message(for: error)
    }
  }

  func beginAdding() {
    guard !isMutationInProgress else {
      return
    }

    screen = .add
  }

  func beginEditing(_ item: PasswordItemSummary) {
    guard !isMutationInProgress else {
      return
    }

    screen = .edit(item)
  }

  func cancelEditor() {
    screen = .list
  }

  func passwordForEditing(id: UUID) async throws -> String {
    try await keychainStore.readPassword(id: id)
  }

  func validationError(
    title: String,
    password: String,
    excluding itemID: UUID? = nil
  ) -> PasswordValidationError? {
    validator.validationError(
      title: title,
      password: password,
      existingItems: items,
      excluding: itemID
    )
  }

  func addItem(title: String, password: String) async throws {
    guard !isMutationInProgress else {
      throw PasswordListViewModelError.operationInProgress
    }

    if let error = validationError(title: title, password: password) {
      throw error
    }

    let normalizedTitle = validator.normalizedTitle(title)
    isMutationInProgress = true
    defer { isMutationInProgress = false }

    let item = try await keychainStore.addItem(
      title: normalizedTitle,
      password: password
    )
    items.append(item)
    hasLoaded = true
    loadErrorMessage = nil
    screen = .list
  }

  func updateItem(
    id: UUID,
    title: String,
    password: String
  ) async throws {
    guard !isMutationInProgress else {
      throw PasswordListViewModelError.operationInProgress
    }

    if let error = validationError(
      title: title,
      password: password,
      excluding: id
    ) {
      throw error
    }

    let normalizedTitle = validator.normalizedTitle(title)
    isMutationInProgress = true
    defer { isMutationInProgress = false }

    try await keychainStore.updateItem(
      id: id,
      title: normalizedTitle,
      password: password
    )

    if let index = items.firstIndex(where: { $0.id == id }) {
      items[index] = PasswordItemSummary(id: id, title: normalizedTitle)
    } else {
      items.append(PasswordItemSummary(id: id, title: normalizedTitle))
    }
    screen = .list
  }

  func moveItem(
    id: UUID,
    relativeTo targetID: UUID,
    placeAfterTarget: Bool
  ) async {
    guard
      !isMutationInProgress,
      id != targetID,
      let sourceIndex = items.firstIndex(where: { $0.id == id })
    else {
      return
    }

    let originalItems = items
    let movedItem = items.remove(at: sourceIndex)

    guard let targetIndex = items.firstIndex(where: { $0.id == targetID }) else {
      items = originalItems
      return
    }

    let insertionIndex = targetIndex + (placeAfterTarget ? 1 : 0)
    items.insert(movedItem, at: insertionIndex)

    guard items != originalItems else {
      return
    }

    isMutationInProgress = true
    defer { isMutationInProgress = false }

    do {
      try await keychainStore.setItemOrder(
        of: id,
        orderedItemIDs: items.map(\.id)
      )
    } catch {
      items = originalItems
      showError(error)
    }
  }

  func requestDeletion(of item: PasswordItemSummary) {
    guard !isMutationInProgress else {
      return
    }

    deletionConfirmation = .item(item)
  }

  func cancelDeletion() {
    deletionConfirmation = nil
  }

  func confirmDeletion() async {
    guard
      !isMutationInProgress,
      let confirmation = deletionConfirmation
    else {
      return
    }

    deletionConfirmation = nil

    switch confirmation {
    case .item(let item):
      await deleteItem(item)
    case .all:
      await deleteAllItems()
    }
  }

  func deleteItem(_ item: PasswordItemSummary) async {
    guard !isMutationInProgress else {
      return
    }

    isMutationInProgress = true
    defer { isMutationInProgress = false }

    do {
      try await keychainStore.deleteItem(id: item.id)
      items.removeAll { $0.id == item.id }
    } catch {
      showError(error)
    }
  }

  func requestDeleteAll() {
    guard !items.isEmpty, !isMutationInProgress else {
      return
    }

    deletionConfirmation = .all(itemCount: items.count)
  }

  func deleteAllItems() async {
    guard !isMutationInProgress else {
      return
    }

    isMutationInProgress = true
    defer { isMutationInProgress = false }

    do {
      try await keychainStore.deleteAllItems()
      items = []
      warningMessage = nil
      hasLoaded = true
      loadErrorMessage = nil
    } catch {
      showError(error)
    }
  }

  func requestCopy(_ item: PasswordItemSummary) {
    copyRequestSequence &+= 1
    let requestSequence = copyRequestSequence

    copyTask?.cancel()
    copyTask = Task { [weak self] in
      guard !Task.isCancelled else {
        return
      }

      await self?.performCopy(item, requestSequence: requestSequence)

      guard
        let self,
        requestSequence == self.copyRequestSequence
      else {
        return
      }
      self.copyTask = nil
    }
  }

  func copyItem(_ item: PasswordItemSummary) async {
    copyTask?.cancel()
    copyTask = nil
    copyRequestSequence &+= 1
    let requestSequence = copyRequestSequence
    await performCopy(item, requestSequence: requestSequence)
  }

  func refreshLoginItemStatus() {
    loginItemStatus = loginItemService.currentStatus()
  }

  func toggleLoginItem() {
    refreshLoginItemStatus()

    switch loginItemStatus {
    case .requiresApproval:
      dialog = DialogState(kind: .loginItemApprovalRequired)
      return
    case .disabled, .enabled, .unavailable:
      break
    }

    let shouldEnable = loginItemStatus != .enabled

    do {
      loginItemStatus = try loginItemService.setEnabled(shouldEnable)
      if loginItemStatus == .requiresApproval {
        dialog = DialogState(kind: .loginItemApprovalRequired)
      }
    } catch {
      refreshLoginItemStatus()
      showError(error)
    }
  }

  func openLoginItemSettings() {
    loginItemService.openSystemSettings()
  }

  func prepareForTermination() {
    copyTask?.cancel()
    copyTask = nil
    feedbackTask?.cancel()
    feedbackTask = nil
    clipboardService.clearIfOwned()
  }

  private func performCopy(
    _ item: PasswordItemSummary,
    requestSequence: Int
  ) async {
    guard !Task.isCancelled else {
      return
    }

    do {
      let password = try await keychainStore.readPassword(id: item.id)

      guard
        !Task.isCancelled,
        requestSequence == copyRequestSequence
      else {
        return
      }

      try clipboardService.copy(password)
      showCopiedFeedback(for: item.id)
    } catch {
      guard
        !Task.isCancelled,
        requestSequence == copyRequestSequence
      else {
        return
      }

      copiedItemID = nil
      showError(error)

      if error as? KeychainStoreError == .itemNotFound {
        await reload()
      }
    }
  }

  private func showCopiedFeedback(for itemID: UUID) {
    feedbackTask?.cancel()
    copiedItemID = itemID

    feedbackTask = Task { [weak self] in
      do {
        try await ContinuousClock().sleep(for: AppConstants.copiedFeedbackDuration)
      } catch {
        return
      }

      guard !Task.isCancelled else {
        return
      }

      self?.copiedItemID = nil
      self?.feedbackTask = nil
    }
  }

  private func showError(_ error: Error) {
    dialog = DialogState(
      kind: .error(message: UserFacingError.message(for: error))
    )
  }
}
