import Foundation

@main
struct ViewModelLogicChecks {
  @MainActor
  static func main() async throws {
    let firstID = UUID()
    let secondID = UUID()
    let exactPassword = "  P@ss/\"\\[]{}:=+🙂  "
    let store = HarnessKeychainStore(records: [
      firstID: .init(title: "Сервер 10", password: "first"),
      secondID: .init(title: "Сервер 2", password: "second"),
    ], itemOrder: [firstID, secondID])
    let clipboard = HarnessClipboardService()
    let login = HarnessLoginItemService()
    let viewModel = PasswordListViewModel(
      keychainStore: store,
      clipboardService: clipboard,
      loginItemService: login,
      validator: PasswordValidator(locale: Locale(identifier: "ru_RU"))
    )

    await viewModel.loadIfNeeded()
    try require(
      viewModel.items.map(\.title) == ["Сервер 10", "Сервер 2"],
      "Начальный список должен сохранять порядок добавления"
    )

    try await viewModel.addItem(
      title: "  GitHub — личный  ",
      password: exactPassword
    )
    guard let added = viewModel.items.first(where: { $0.title == "GitHub — личный" }) else {
      throw CheckFailure(message: "Добавленный элемент не найден")
    }
    let storedAdded = await store.record(id: added.id)
    try require(storedAdded?.password == exactPassword, "Пароль должен сохраняться без изменения")
    try require(
      viewModel.items.last?.id == added.id,
      "Новый элемент должен добавляться в конец списка"
    )

    try require(
      viewModel.validationError(
        title: "github — ЛИЧНЫЙ",
        password: "x"
      ) == .duplicateTitle,
      "Дубликат без учёта регистра должен обнаруживаться"
    )

    await store.setUpdateError(.operationFailed(status: -4))
    viewModel.beginEditing(added)
    do {
      try await viewModel.updateItem(
        id: added.id,
        title: "Изменённый",
        password: exactPassword
      )
      throw CheckFailure(message: "Ожидалась ошибка обновления")
    } catch let error as KeychainStoreError {
      try require(error == .operationFailed(status: -4), "Должна сохраниться типизированная ошибка")
    }
    try require(viewModel.screen == .edit(added), "Форма должна остаться открытой после ошибки")
    await store.setUpdateError(nil)

    guard
      let first = viewModel.items.first(where: { $0.id == firstID }),
      let second = viewModel.items.first(where: { $0.id == secondID })
    else {
      throw CheckFailure(message: "Исходные элементы не найдены")
    }
    await store.setReadDelay(.milliseconds(120), for: firstID)
    await store.setReadDelay(.milliseconds(10), for: secondID)
    viewModel.requestCopy(first)
    viewModel.requestCopy(second)
    try await ContinuousClock().sleep(for: .milliseconds(180))
    try require(clipboard.copiedValues == ["second"], "Последний быстрый клик должен победить")

    await store.setDeleteError(.operationFailed(status: -5))
    await viewModel.deleteItem(second)
    try require(
      viewModel.items.contains(where: { $0.id == secondID }),
      "Элемент должен оставаться в модели при ошибке удаления"
    )
    await store.setDeleteError(nil)

    login.status = .unavailable
    viewModel.toggleLoginItem()
    try require(
      login.setEnabledCalls == [true],
      "Недоступный статус должен приводить к попытке регистрации"
    )
    try require(
      viewModel.loginItemStatus == .enabled,
      "Успешная регистрация должна обновить статус автозапуска"
    )

    viewModel.prepareForTermination()
    try require(clipboard.clearCount == 1, "Штатный выход должен вызвать безопасную очистку")

    print("ViewModel logic checks: PASS")
  }

  private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
      throw CheckFailure(message: message)
    }
  }
}

private struct CheckFailure: Error, CustomStringConvertible {
  let message: String
  var description: String { message }
}
