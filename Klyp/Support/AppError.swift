import Foundation

enum KeychainStoreError: Error, Equatable, Sendable {
  case duplicateItem
  case itemNotFound
  case interactionNotAllowed
  case keychainUnavailable
  case invalidUUID
  case invalidUTF8
  case unexpectedResult
  case operationFailed(status: Int32)

  var userMessage: String {
    switch self {
    case .duplicateItem:
      "Не удалось сохранить элемент: запись уже существует"
    case .itemNotFound:
      "Элемент не найден. Возможно, он был удалён"
    case .interactionNotAllowed:
      "Доступ к Keychain невозможен, пока Mac заблокирован"
    case .keychainUnavailable:
      "Keychain сейчас недоступен. Повторите попытку"
    case .invalidUUID, .invalidUTF8, .unexpectedResult:
      "Данные в Keychain повреждены"
    case .operationFailed:
      "Не удалось обратиться к Keychain. Повторите попытку"
    }
  }
}

enum PasswordListViewModelError: Error, Equatable, Sendable {
  case operationInProgress

  var userMessage: String {
    "Дождитесь завершения текущей операции"
  }
}

enum ClipboardServiceError: Error, Equatable, Sendable {
  case writeFailed

  var userMessage: String {
    "Не удалось записать пароль в буфер обмена"
  }
}

enum LoginItemServiceError: Error, Equatable, Sendable {
  case operationFailed
  case serviceNotFound

  var userMessage: String {
    switch self {
    case .operationFailed:
      "Не удалось изменить запуск при входе"
    case .serviceNotFound:
      "Служба запуска при входе недоступна для этой копии приложения"
    }
  }
}

enum UserFacingError {
  static func message(for error: Error) -> String {
    if let error = error as? PasswordValidationError {
      return error.userMessage
    }

    if let error = error as? KeychainStoreError {
      return error.userMessage
    }

    if let error = error as? PasswordListViewModelError {
      return error.userMessage
    }

    if let error = error as? ClipboardServiceError {
      return error.userMessage
    }

    if let error = error as? LoginItemServiceError {
      return error.userMessage
    }

    return "Операцию не удалось выполнить. Повторите попытку"
  }
}
