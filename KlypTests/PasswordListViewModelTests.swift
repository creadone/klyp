import XCTest

@testable import Klyp

final class PasswordListViewModelTests: XCTestCase {
  @MainActor
  func testSuccessfulAddUpdatesListAndPreservesPasswordExactly() async throws {
    let store = FakeKeychainStore()
    let viewModel = makeViewModel(keychainStore: store)
    let password = "  P@ss/\"\\[]{}:=+🙂  "

    await viewModel.loadIfNeeded()
    try await viewModel.addItem(title: "  GitHub — личный  ", password: password)

    XCTAssertEqual(viewModel.items.map(\.title), ["GitHub — личный"])
    XCTAssertEqual(viewModel.screen, .list)

    let records = await store.allRecords()
    XCTAssertEqual(records.count, 1)
    XCTAssertEqual(records.values.first?.password, password)
  }

  @MainActor
  func testAddErrorLeavesEditorAndListUnchanged() async {
    let store = FakeKeychainStore()
    await store.setAddError(.operationFailed(status: -1))
    let viewModel = makeViewModel(keychainStore: store)
    await viewModel.loadIfNeeded()
    viewModel.beginAdding()

    do {
      try await viewModel.addItem(title: "Тест", password: "secret")
      XCTFail("Ожидалась ошибка")
    } catch {
      XCTAssertEqual(error as? KeychainStoreError, .operationFailed(status: -1))
    }

    XCTAssertTrue(viewModel.items.isEmpty)
    XCTAssertEqual(viewModel.screen, .add)
  }

  @MainActor
  func testSuccessfulUpdateChangesOnlyRequestedItem() async throws {
    let id = UUID()
    let store = FakeKeychainStore(records: [
      id: .init(title: "Старое", password: "old")
    ])
    let viewModel = makeViewModel(keychainStore: store)
    await viewModel.loadIfNeeded()

    try await viewModel.updateItem(
      id: id,
      title: "  Новое  ",
      password: "new"
    )

    XCTAssertEqual(viewModel.items, [PasswordItemSummary(id: id, title: "Новое")])
    let updatedRecord = await store.record(id: id)
    XCTAssertEqual(updatedRecord?.password, "new")
  }

  @MainActor
  func testUpdateErrorKeepsEditorAndOriginalListItem() async {
    let id = UUID()
    let original = PasswordItemSummary(id: id, title: "Исходное")
    let store = FakeKeychainStore(records: [
      id: .init(title: original.title, password: "old")
    ])
    await store.setUpdateError(.operationFailed(status: -4))
    let viewModel = makeViewModel(keychainStore: store)
    await viewModel.loadIfNeeded()
    viewModel.beginEditing(original)

    do {
      try await viewModel.updateItem(
        id: id,
        title: "Новое",
        password: "new"
      )
      XCTFail("Ожидалась ошибка обновления")
    } catch {
      XCTAssertEqual(error as? KeychainStoreError, .operationFailed(status: -4))
    }

    XCTAssertEqual(viewModel.items, [original])
    XCTAssertEqual(viewModel.screen, .edit(original))
    let stored = await store.record(id: id)
    XCTAssertEqual(stored?.title, "Исходное")
    XCTAssertEqual(stored?.password, "old")
  }

  @MainActor
  func testAddAndRenamePreserveInsertionOrder() async throws {
    let firstID = UUID()
    let secondID = UUID()
    let store = FakeKeychainStore(records: [
      firstID: .init(title: "Сервер 10", password: "a"),
      secondID: .init(title: "Сервер 2", password: "b"),
    ], itemOrder: [firstID, secondID])
    let viewModel = makeViewModel(keychainStore: store)
    await viewModel.loadIfNeeded()

    XCTAssertEqual(viewModel.items.map(\.title), ["Сервер 10", "Сервер 2"])

    try await viewModel.updateItem(
      id: firstID,
      title: "Сервер 1",
      password: "a"
    )

    XCTAssertEqual(viewModel.items.map(\.title), ["Сервер 1", "Сервер 2"])
  }

  @MainActor
  func testMoveItemPersistsManualOrder() async {
    let firstID = UUID()
    let secondID = UUID()
    let thirdID = UUID()
    let store = FakeKeychainStore(
      records: [
        firstID: .init(title: "A", password: "1"),
        secondID: .init(title: "B", password: "2"),
        thirdID: .init(title: "C", password: "3"),
      ],
      itemOrder: [firstID, secondID, thirdID]
    )
    let viewModel = makeViewModel(keychainStore: store)
    await viewModel.loadIfNeeded()

    await viewModel.moveItem(
      id: firstID,
      relativeTo: thirdID,
      placeAfterTarget: true
    )

    XCTAssertEqual(viewModel.items.map(\.id), [secondID, thirdID, firstID])
    let storedOrder = await store.orderedItemIDs()
    XCTAssertEqual(storedOrder, [secondID, thirdID, firstID])
    let reorderCallCount = await store.reorderCallCount
    XCTAssertEqual(reorderCallCount, 1)
  }

  @MainActor
  func testReorderErrorRestoresOriginalOrder() async {
    let firstID = UUID()
    let secondID = UUID()
    let store = FakeKeychainStore(
      records: [
        firstID: .init(title: "A", password: "1"),
        secondID: .init(title: "B", password: "2"),
      ],
      itemOrder: [firstID, secondID]
    )
    await store.setReorderError(.operationFailed(status: -7))
    let viewModel = makeViewModel(keychainStore: store)
    await viewModel.loadIfNeeded()

    await viewModel.moveItem(
      id: firstID,
      relativeTo: secondID,
      placeAfterTarget: true
    )

    XCTAssertEqual(viewModel.items.map(\.id), [firstID, secondID])
    guard case .error = viewModel.dialog?.kind else {
      return XCTFail("Должна быть показана ошибка перестановки")
    }
  }

  @MainActor
  func testNewItemIsAppendedAfterManualReorder() async throws {
    let firstID = UUID()
    let secondID = UUID()
    let store = FakeKeychainStore(
      records: [
        firstID: .init(title: "A", password: "1"),
        secondID: .init(title: "B", password: "2"),
      ],
      itemOrder: [firstID, secondID]
    )
    let viewModel = makeViewModel(keychainStore: store)
    await viewModel.loadIfNeeded()

    await viewModel.moveItem(
      id: secondID,
      relativeTo: firstID,
      placeAfterTarget: false
    )
    try await viewModel.addItem(title: "Новый", password: "3")

    XCTAssertEqual(viewModel.items.prefix(2).map(\.id), [secondID, firstID])
    XCTAssertEqual(viewModel.items.last?.title, "Новый")
  }

  @MainActor
  func testCancelEditingDoesNotChangeStoredData() async {
    let id = UUID()
    let store = FakeKeychainStore(records: [
      id: .init(title: "Исходное", password: "secret")
    ])
    let viewModel = makeViewModel(keychainStore: store)
    await viewModel.loadIfNeeded()
    let item = viewModel.items[0]

    viewModel.beginEditing(item)
    viewModel.cancelEditor()

    XCTAssertEqual(viewModel.screen, .list)
    let record = await store.record(id: id)
    XCTAssertEqual(record?.title, "Исходное")
    XCTAssertEqual(record?.password, "secret")
    let updateCallCount = await store.updateCallCount
    XCTAssertEqual(updateCallCount, 0)
  }

  @MainActor
  func testSuccessfulDeleteRemovesItemFromModel() async {
    let id = UUID()
    let store = FakeKeychainStore(records: [
      id: .init(title: "Тест", password: "secret")
    ])
    let viewModel = makeViewModel(keychainStore: store)
    await viewModel.loadIfNeeded()

    await viewModel.deleteItem(viewModel.items[0])

    XCTAssertTrue(viewModel.items.isEmpty)
    let deletedRecord = await store.record(id: id)
    XCTAssertNil(deletedRecord)
  }

  @MainActor
  func testConfirmedDeletionClearsConfirmationAndRemovesItem() async {
    let id = UUID()
    let item = PasswordItemSummary(id: id, title: "Тест")
    let store = FakeKeychainStore(records: [
      id: .init(title: item.title, password: "secret")
    ])
    let viewModel = makeViewModel(keychainStore: store)
    await viewModel.loadIfNeeded()

    viewModel.requestDeletion(of: item)
    XCTAssertEqual(viewModel.deletionConfirmation, .item(item))

    await viewModel.confirmDeletion()

    XCTAssertNil(viewModel.deletionConfirmation)
    XCTAssertTrue(viewModel.items.isEmpty)
    let deletedRecord = await store.record(id: id)
    XCTAssertNil(deletedRecord)
  }

  @MainActor
  func testCancelledDeletionClearsConfirmationWithoutDeletingItem() async {
    let id = UUID()
    let item = PasswordItemSummary(id: id, title: "Тест")
    let store = FakeKeychainStore(records: [
      id: .init(title: item.title, password: "secret")
    ])
    let viewModel = makeViewModel(keychainStore: store)
    await viewModel.loadIfNeeded()

    viewModel.requestDeletion(of: item)
    viewModel.cancelDeletion()

    XCTAssertNil(viewModel.deletionConfirmation)
    XCTAssertEqual(viewModel.items, [item])
    let retainedRecord = await store.record(id: id)
    XCTAssertNotNil(retainedRecord)
  }

  @MainActor
  func testDeleteErrorKeepsItemInModel() async {
    let id = UUID()
    let store = FakeKeychainStore(records: [
      id: .init(title: "Тест", password: "secret")
    ])
    await store.setDeleteError(.operationFailed(status: -2))
    let viewModel = makeViewModel(keychainStore: store)
    await viewModel.loadIfNeeded()

    await viewModel.deleteItem(viewModel.items[0])

    XCTAssertEqual(viewModel.items.count, 1)
    let retainedRecord = await store.record(id: id)
    XCTAssertNotNil(retainedRecord)
    guard case .error = viewModel.dialog?.kind else {
      return XCTFail("Должен быть показан диалог ошибки")
    }
  }

  @MainActor
  func testSuccessfulCopyWritesExactPassword() async {
    let id = UUID()
    let password = "  P@ss/\"\\[]{}:=+🙂  "
    let store = FakeKeychainStore(records: [
      id: .init(title: "Тест", password: password)
    ])
    let clipboard = FakeClipboardService()
    let viewModel = makeViewModel(
      keychainStore: store,
      clipboardService: clipboard
    )
    await viewModel.loadIfNeeded()

    await viewModel.copyItem(viewModel.items[0])

    XCTAssertEqual(clipboard.copiedValues, [password])
    XCTAssertEqual(viewModel.copiedItemID, id)
  }

  @MainActor
  func testRapidCopyRequestsKeepPasswordFromLastClick() async throws {
    let firstID = UUID()
    let secondID = UUID()
    let store = FakeKeychainStore(records: [
      firstID: .init(title: "A", password: "first"),
      secondID: .init(title: "B", password: "second"),
    ])
    await store.setReadDelay(.milliseconds(120), for: firstID)
    await store.setReadDelay(.milliseconds(10), for: secondID)
    let clipboard = FakeClipboardService()
    let viewModel = makeViewModel(
      keychainStore: store,
      clipboardService: clipboard
    )
    await viewModel.loadIfNeeded()

    guard
      let first = viewModel.items.first(where: { $0.id == firstID }),
      let second = viewModel.items.first(where: { $0.id == secondID })
    else {
      return XCTFail("Тестовые элементы должны быть загружены")
    }

    viewModel.requestCopy(first)
    viewModel.requestCopy(second)
    try await ContinuousClock().sleep(for: .milliseconds(180))

    XCTAssertEqual(clipboard.copiedValues, ["second"])
    XCTAssertEqual(viewModel.copiedItemID, secondID)
  }

  @MainActor
  func testReadErrorDoesNotModifyClipboard() async {
    let id = UUID()
    let store = FakeKeychainStore(records: [
      id: .init(title: "Тест", password: "secret")
    ])
    await store.setReadError(.itemNotFound)
    let clipboard = FakeClipboardService()
    let viewModel = makeViewModel(
      keychainStore: store,
      clipboardService: clipboard
    )
    await viewModel.loadIfNeeded()

    await viewModel.copyItem(viewModel.items[0])

    XCTAssertTrue(clipboard.copiedValues.isEmpty)
  }

  @MainActor
  func testClipboardWriteErrorDoesNotShowSuccess() async {
    let id = UUID()
    let store = FakeKeychainStore(records: [
      id: .init(title: "Тест", password: "secret")
    ])
    let clipboard = FakeClipboardService()
    clipboard.nextError = .writeFailed
    let viewModel = makeViewModel(
      keychainStore: store,
      clipboardService: clipboard
    )
    await viewModel.loadIfNeeded()

    await viewModel.copyItem(viewModel.items[0])

    XCTAssertNil(viewModel.copiedItemID)
    guard case .error = viewModel.dialog?.kind else {
      return XCTFail("Должна быть показана ошибка")
    }
  }

  @MainActor
  func testCorruptedEntriesProduceWarningWithoutHidingValidItems() async {
    let validItem = PasswordItemSummary(id: UUID(), title: "Рабочий")
    let store = FakeKeychainStore()
    await store.setListResult(
      KeychainItemList(items: [validItem], skippedCorruptedItems: 1)
    )
    let viewModel = makeViewModel(keychainStore: store)

    await viewModel.loadIfNeeded()

    XCTAssertEqual(viewModel.items, [validItem])
    XCTAssertEqual(
      viewModel.warningMessage,
      "Некоторые повреждённые записи были пропущены"
    )
  }

  @MainActor
  func testKeychainUnavailableHasDedicatedUserMessage() async {
    let store = FakeKeychainStore()
    await store.setListError(.keychainUnavailable)
    let viewModel = makeViewModel(keychainStore: store)

    await viewModel.loadIfNeeded()

    XCTAssertEqual(
      viewModel.loadErrorMessage,
      "Keychain сейчас недоступен. Повторите попытку"
    )
    XCTAssertFalse(viewModel.hasLoaded)
  }

  @MainActor
  func testLoadFailurePreservesPreviouslyLoadedItems() async {
    let id = UUID()
    let store = FakeKeychainStore(records: [
      id: .init(title: "Тест", password: "secret")
    ])
    let viewModel = makeViewModel(keychainStore: store)
    await viewModel.loadIfNeeded()
    await store.setListError(.interactionNotAllowed)

    await viewModel.reload()

    XCTAssertEqual(viewModel.items, [PasswordItemSummary(id: id, title: "Тест")])
    XCTAssertNotNil(viewModel.loadErrorMessage)
  }

  @MainActor
  func testDeleteAllSuccessClearsModel() async {
    let store = FakeKeychainStore(records: [
      UUID(): .init(title: "A", password: "1"),
      UUID(): .init(title: "B", password: "2"),
    ])
    let viewModel = makeViewModel(keychainStore: store)
    await viewModel.loadIfNeeded()

    await viewModel.deleteAllItems()

    XCTAssertTrue(viewModel.items.isEmpty)
    let remainingRecords = await store.allRecords()
    XCTAssertTrue(remainingRecords.isEmpty)
  }

  @MainActor
  func testConfirmedDeleteAllClearsConfirmationAndModel() async {
    let store = FakeKeychainStore(records: [
      UUID(): .init(title: "A", password: "1"),
      UUID(): .init(title: "B", password: "2"),
    ])
    let viewModel = makeViewModel(keychainStore: store)
    await viewModel.loadIfNeeded()

    viewModel.requestDeleteAll()
    XCTAssertEqual(viewModel.deletionConfirmation, .all(itemCount: 2))

    await viewModel.confirmDeletion()

    XCTAssertNil(viewModel.deletionConfirmation)
    XCTAssertTrue(viewModel.items.isEmpty)
    let remainingRecords = await store.allRecords()
    XCTAssertTrue(remainingRecords.isEmpty)
  }

  @MainActor
  func testDeleteAllErrorDoesNotShowEmptyState() async {
    let store = FakeKeychainStore(records: [
      UUID(): .init(title: "A", password: "1")
    ])
    await store.setDeleteAllError(.operationFailed(status: -3))
    let viewModel = makeViewModel(keychainStore: store)
    await viewModel.loadIfNeeded()

    await viewModel.deleteAllItems()

    XCTAssertEqual(viewModel.items.count, 1)
    guard case .error = viewModel.dialog?.kind else {
      return XCTFail("Должна быть показана ошибка")
    }
  }

  @MainActor
  func testRepeatedSaveInvokesStoreOnlyOnce() async throws {
    let store = FakeKeychainStore()
    await store.setAddDelay(.milliseconds(120))
    let viewModel = makeViewModel(keychainStore: store)
    await viewModel.loadIfNeeded()

    let first = Task { @MainActor in
      try await viewModel.addItem(title: "Тест", password: "secret")
    }

    try await ContinuousClock().sleep(for: .milliseconds(20))

    do {
      try await viewModel.addItem(title: "Тест", password: "secret")
      XCTFail("Повторная операция должна быть отклонена")
    } catch {
      XCTAssertEqual(
        error as? PasswordListViewModelError,
        .operationInProgress
      )
    }

    try await first.value
    let addCallCount = await store.addCallCount
    XCTAssertEqual(addCallCount, 1)
    XCTAssertEqual(viewModel.items.count, 1)
  }

  @MainActor
  func testViewModelHasNoLongLivedPasswordProperty() async {
    let store = FakeKeychainStore()
    let viewModel = makeViewModel(keychainStore: store)
    await viewModel.loadIfNeeded()
    viewModel.beginAdding()
    viewModel.cancelEditor()

    let labels = Mirror(reflecting: viewModel).children.compactMap(\.label)
    XCTAssertFalse(labels.contains { $0.localizedCaseInsensitiveContains("password") })
    XCTAssertEqual(viewModel.screen, .list)
  }

  @MainActor
  func testLoginItemErrorKeepsStatusConsistent() {
    let store = FakeKeychainStore()
    let login = FakeLoginItemService(status: .disabled)
    login.nextError = .operationFailed
    let viewModel = makeViewModel(
      keychainStore: store,
      loginItemService: login
    )

    viewModel.toggleLoginItem()

    XCTAssertEqual(viewModel.loginItemStatus, .disabled)
    XCTAssertEqual(login.setEnabledCalls, [true])
    guard case .error = viewModel.dialog?.kind else {
      return XCTFail("Должна быть показана ошибка")
    }
  }

  @MainActor
  func testRequiresApprovalShowsExplanationWithoutFalseEnabledState() {
    let store = FakeKeychainStore()
    let login = FakeLoginItemService(status: .requiresApproval)
    let viewModel = makeViewModel(
      keychainStore: store,
      loginItemService: login
    )

    viewModel.toggleLoginItem()

    XCTAssertEqual(viewModel.loginItemStatus, .requiresApproval)
    XCTAssertTrue(login.setEnabledCalls.isEmpty)
    XCTAssertEqual(viewModel.dialog?.kind, .loginItemApprovalRequired)
  }

  @MainActor
  func testUnavailableLoginItemAttemptsRegistration() {
    let store = FakeKeychainStore()
    let login = FakeLoginItemService(status: .unavailable)
    let viewModel = makeViewModel(
      keychainStore: store,
      loginItemService: login
    )

    viewModel.toggleLoginItem()

    XCTAssertEqual(login.setEnabledCalls, [true])
    XCTAssertEqual(viewModel.loginItemStatus, .enabled)
    XCTAssertNil(viewModel.dialog)
  }

  @MainActor
  func testPrepareForTerminationClearsOnlyThroughClipboardService() {
    let store = FakeKeychainStore()
    let clipboard = FakeClipboardService()
    let viewModel = makeViewModel(
      keychainStore: store,
      clipboardService: clipboard
    )

    viewModel.prepareForTermination()

    XCTAssertEqual(clipboard.clearCallCount, 1)
  }
}
