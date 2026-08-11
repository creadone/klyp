import Foundation
import OSLog

enum DiagnosticOperation: String, Sendable {
  case listItems
  case readPassword
  case addItem
  case updateItem
  case reorderItems
  case deleteItem
  case deleteAllItems
}

enum DiagnosticCategory: String, Sendable {
  case duplicate
  case notFound
  case interactionNotAllowed
  case unavailable
  case invalidData
  case system
}

protocol DiagnosticLogging: Sendable {
  func log(operation: DiagnosticOperation, status: Int32, category: DiagnosticCategory)
}

final class OSDiagnosticLogger: DiagnosticLogging, @unchecked Sendable {
  private let logger: Logger

  init(subsystem: String = AppConstants.bundleIdentifier) {
    logger = Logger(subsystem: subsystem, category: "Keychain")
  }

  func log(operation: DiagnosticOperation, status: Int32, category: DiagnosticCategory) {
    logger.error(
      "operation=\(operation.rawValue, privacy: .public) status=\(status, privacy: .public) category=\(category.rawValue, privacy: .public)"
    )
  }
}
