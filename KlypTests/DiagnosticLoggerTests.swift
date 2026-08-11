import Foundation
import XCTest

@testable import Klyp

final class DiagnosticLoggerTests: XCTestCase {
  func testDiagnosticLoggerInterfaceCannotReceiveSecretFields() {
    let logger = RecordingDiagnosticLogger()

    logger.log(operation: .readPassword, status: -25300, category: .notFound)

    XCTAssertEqual(
      logger.records,
      [
        .init(
          operation: .readPassword,
          status: -25300,
          category: .notFound
        )
      ]
    )
    let labels = Mirror(reflecting: logger.records[0]).children.compactMap(\.label)
    XCTAssertEqual(Set(labels), Set(["operation", "status", "category"]))
  }
}

private final class RecordingDiagnosticLogger: DiagnosticLogging, @unchecked Sendable {
  struct Record: Equatable {
    let operation: DiagnosticOperation
    let status: Int32
    let category: DiagnosticCategory
  }

  private let lock = NSLock()
  private var storage: [Record] = []

  var records: [Record] {
    lock.lock()
    defer { lock.unlock() }
    return storage
  }

  func log(operation: DiagnosticOperation, status: Int32, category: DiagnosticCategory) {
    lock.lock()
    storage.append(
      Record(operation: operation, status: status, category: category)
    )
    lock.unlock()
  }
}
