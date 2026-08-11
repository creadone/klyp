import Foundation

enum PasswordValidationError: Error, Equatable, Sendable {
  case emptyTitle
  case emptyPassword
  case duplicateTitle

  var userMessage: String {
    switch self {
    case .emptyTitle:
      "Введите название"
    case .emptyPassword:
      "Введите пароль"
    case .duplicateTitle:
      "Элемент с таким названием уже существует"
    }
  }
}

struct PasswordValidator: Sendable {
  let locale: Locale

  init(locale: Locale = .current) {
    self.locale = locale
  }

  func normalizedTitle(_ title: String) -> String {
    title.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func validationError(
    title: String,
    password: String,
    existingItems: [PasswordItemSummary],
    excluding itemID: UUID? = nil
  ) -> PasswordValidationError? {
    let normalizedTitle = normalizedTitle(title)

    if normalizedTitle.isEmpty {
      return .emptyTitle
    }

    if password.isEmpty {
      return .emptyPassword
    }

    let duplicateExists = existingItems.contains { item in
      guard item.id != itemID else {
        return false
      }

      return normalizedTitle.compare(
        item.title,
        options: [.caseInsensitive],
        range: nil,
        locale: locale
      ) == .orderedSame
    }

    return duplicateExists ? .duplicateTitle : nil
  }
}
