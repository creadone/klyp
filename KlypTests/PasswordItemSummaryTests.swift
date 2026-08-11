import XCTest

@testable import Klyp

final class PasswordItemSummaryTests: XCTestCase {
  func testSummaryContainsNoPasswordProperty() {
    let summary = PasswordItemSummary(id: UUID(), title: "Тест")
    let labels = Mirror(reflecting: summary).children.compactMap(\.label)

    XCTAssertEqual(Set(labels), Set(["id", "title"]))
    XCTAssertFalse(labels.contains { $0.localizedCaseInsensitiveContains("password") })
  }
}
