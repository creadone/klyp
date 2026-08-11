import Foundation

@main
struct CoreLogicChecks {
  static func main() throws {
    let locale = Locale(identifier: "ru_RU")
    let validator = PasswordValidator(locale: locale)
    let sorter = PasswordItemSorter()

    try require(
      validator.validationError(title: "", password: "x", existingItems: []) == .emptyTitle,
      "Пустое название должно отклоняться"
    )
    try require(
      validator.validationError(title: "   ", password: "x", existingItems: []) == .emptyTitle,
      "Название из пробелов должно отклоняться"
    )
    try require(
      validator.normalizedTitle("  Сервер  ") == "Сервер",
      "Название должно обрезаться по краям"
    )

    let exactPassword = "  P@ss/\"\\[]{}:=+🙂  "
    try require(
      validator.validationError(
        title: "Тест",
        password: exactPassword,
        existingItems: []
      ) == nil,
      "Пароль со значимыми пробелами должен быть валиден"
    )
    try require(
      validator.validationError(title: "Тест", password: " ", existingItems: []) == nil,
      "Один пробел должен считаться непустым паролем"
    )

    let existingID = try makeUUID("00000000-0000-0000-0000-000000000001")
    let existing = PasswordItemSummary(id: existingID, title: "GitHub — личный")
    try require(
      validator.validationError(
        title: "github — ЛИЧНЫЙ",
        password: "x",
        existingItems: [existing]
      ) == .duplicateTitle,
      "Дубликат без учёта регистра должен отклоняться"
    )
    try require(
      validator.validationError(
        title: "GITHUB — ЛИЧНЫЙ",
        password: "x",
        existingItems: [existing],
        excluding: existingID
      ) == nil,
      "Элемент не должен считаться дубликатом самого себя"
    )

    let orderedItems = [
      PasswordItemSummary(
        id: try makeUUID("00000000-0000-0000-0000-000000000010"),
        title: "Первый"
      ),
      PasswordItemSummary(
        id: try makeUUID("00000000-0000-0000-0000-000000000011"),
        title: "Второй"
      ),
      PasswordItemSummary(
        id: try makeUUID("00000000-0000-0000-0000-000000000012"),
        title: "Третий"
      ),
    ]
    let orderValues = [
      orderedItems[0].id: 20.0,
      orderedItems[1].id: 30.0,
      orderedItems[2].id: 10.0,
    ]
    let titles = sorter.sorted(orderedItems, orderValues: orderValues).map(\.title)
    try require(
      titles == ["Третий", "Первый", "Второй"],
      "Список должен использовать сохранённый пользовательский порядок"
    )

    let labels = Mirror(reflecting: existing).children.compactMap(\.label)
    try require(Set(labels) == Set(["id", "title"]), "Summary не должен содержать пароль")

    print("Core logic checks: PASS")
  }

  private static func makeUUID(_ value: String) throws -> UUID {
    guard let id = UUID(uuidString: value) else {
      throw CheckFailure(message: "Некорректный UUID в проверочном наборе")
    }
    return id
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
