import XCTest

@testable import Klyp

final class PasswordValidationTests: XCTestCase {
  private let validator = PasswordValidator(locale: Locale(identifier: "ru_RU"))

  func testEmptyTitleIsRejected() {
    XCTAssertEqual(
      validator.validationError(
        title: "",
        password: "secret",
        existingItems: []
      ),
      .emptyTitle
    )
  }

  func testWhitespaceOnlyTitleIsRejected() {
    XCTAssertEqual(
      validator.validationError(
        title: "  \t\n ",
        password: "secret",
        existingItems: []
      ),
      .emptyTitle
    )
  }

  func testTitleIsTrimmed() {
    XCTAssertEqual(validator.normalizedTitle("  Сервер  "), "Сервер")
  }

  func testPasswordWhitespaceIsNotModified() {
    let password = "  P@ss/\"\\[]{}:=+🙂  "

    XCTAssertNil(
      validator.validationError(
        title: "Тест",
        password: password,
        existingItems: []
      )
    )
    XCTAssertEqual(password, "  P@ss/\"\\[]{}:=+🙂  ")
  }

  func testEmptyPasswordIsRejected() {
    XCTAssertEqual(
      validator.validationError(
        title: "Тест",
        password: "",
        existingItems: []
      ),
      .emptyPassword
    )
  }

  func testDuplicateTitleIsDetectedIgnoringCase() {
    let existing = PasswordItemSummary(id: UUID(), title: "GitHub — личный")

    XCTAssertEqual(
      validator.validationError(
        title: "github — ЛИЧНЫЙ",
        password: "secret",
        existingItems: [existing]
      ),
      .duplicateTitle
    )
  }

  func testUnicodeDuplicateUsesLocalizedCaseComparison() {
    let existing = PasswordItemSummary(id: UUID(), title: "СЕРВЕР Δ / 测试")

    XCTAssertEqual(
      validator.validationError(
        title: "сервер δ / 测试",
        password: "secret",
        existingItems: [existing]
      ),
      .duplicateTitle
    )
  }

  func testSingleSpacePasswordIsValid() {
    XCTAssertNil(
      validator.validationError(
        title: "Тест",
        password: " ",
        existingItems: []
      )
    )
  }

  func testOwnTitleIsNotDuplicateDuringRename() {
    let id = UUID()
    let existing = PasswordItemSummary(id: id, title: "GitHub")

    XCTAssertNil(
      validator.validationError(
        title: "GITHUB",
        password: "secret",
        existingItems: [existing],
        excluding: id
      )
    )
  }
}
