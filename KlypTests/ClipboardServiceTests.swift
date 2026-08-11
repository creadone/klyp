import XCTest

@testable import Klyp

final class ClipboardServiceTests: XCTestCase {
  @MainActor
  func testCopyWritesExactValueWithCurrentHostOnly() throws {
    let pasteboard = FakePasteboardClient()
    let service = ClipboardService(
      pasteboard: pasteboard,
      sleeper: LongClipboardSleeper(),
      clearDelay: .seconds(30)
    )
    let password = "  P@ss/\"\\[]{}:=+🙂  "

    try service.copy(password)

    XCTAssertEqual(pasteboard.storedString, password)
    XCTAssertEqual(pasteboard.prepareCurrentHostOnlyValues, [true])
    XCTAssertEqual(service.ownedChangeCount, pasteboard.changeCount)
    XCTAssertTrue(service.hasScheduledClear)
  }

  @MainActor
  func testUnchangedPasteboardIsClearedAfterDelay() async throws {
    let pasteboard = FakePasteboardClient()
    let service = ClipboardService(
      pasteboard: pasteboard,
      sleeper: FixedDelayClipboardSleeper(delay: .milliseconds(30)),
      clearDelay: .seconds(30)
    )

    try service.copy("secret")
    try await ContinuousClock().sleep(for: .milliseconds(80))

    XCTAssertNil(pasteboard.storedString)
    XCTAssertEqual(pasteboard.clearCallCount, 1)
    XCTAssertNil(service.ownedChangeCount)
    XCTAssertFalse(service.hasScheduledClear)
  }

  @MainActor
  func testNewerPasteboardContentIsNotCleared() async throws {
    let pasteboard = FakePasteboardClient()
    let service = ClipboardService(
      pasteboard: pasteboard,
      sleeper: FixedDelayClipboardSleeper(delay: .milliseconds(40)),
      clearDelay: .seconds(30)
    )

    try service.copy("secret")
    pasteboard.externalWrite("new content")
    try await ContinuousClock().sleep(for: .milliseconds(90))

    XCTAssertEqual(pasteboard.storedString, "new content")
    XCTAssertEqual(pasteboard.clearCallCount, 0)
    XCTAssertNil(service.ownedChangeCount)
  }

  @MainActor
  func testRepeatedCopyCancelsPreviousTimer() async throws {
    let pasteboard = FakePasteboardClient()
    let service = ClipboardService(
      pasteboard: pasteboard,
      sleeper: FixedDelayClipboardSleeper(delay: .milliseconds(100)),
      clearDelay: .seconds(30)
    )

    try service.copy("A")
    try await ContinuousClock().sleep(for: .milliseconds(60))
    try service.copy("B")
    try await ContinuousClock().sleep(for: .milliseconds(60))

    XCTAssertEqual(pasteboard.storedString, "B")
    XCTAssertEqual(pasteboard.clearCallCount, 0)

    try await ContinuousClock().sleep(for: .milliseconds(70))

    XCTAssertNil(pasteboard.storedString)
    XCTAssertEqual(pasteboard.clearCallCount, 1)
  }

  @MainActor
  func testWriteFailureDoesNotScheduleClear() {
    let pasteboard = FakePasteboardClient()
    pasteboard.shouldWriteSucceed = false
    let service = ClipboardService(
      pasteboard: pasteboard,
      sleeper: FixedDelayClipboardSleeper(delay: .milliseconds(10)),
      clearDelay: .seconds(30)
    )

    XCTAssertThrowsError(try service.copy("secret")) { error in
      XCTAssertEqual(error as? ClipboardServiceError, .writeFailed)
    }
    XCTAssertFalse(service.hasScheduledClear)
    XCTAssertNil(service.ownedChangeCount)
  }

  @MainActor
  func testClearOnExitRemovesOwnedValue() throws {
    let pasteboard = FakePasteboardClient()
    let service = ClipboardService(
      pasteboard: pasteboard,
      sleeper: LongClipboardSleeper(),
      clearDelay: .seconds(30)
    )

    try service.copy("secret")
    service.clearIfOwned()

    XCTAssertNil(pasteboard.storedString)
    XCTAssertEqual(pasteboard.clearCallCount, 1)
    XCTAssertFalse(service.hasScheduledClear)
  }

  @MainActor
  func testClearOnExitPreservesNewerForeignValue() throws {
    let pasteboard = FakePasteboardClient()
    let service = ClipboardService(
      pasteboard: pasteboard,
      sleeper: LongClipboardSleeper(),
      clearDelay: .seconds(30)
    )

    try service.copy("secret")
    pasteboard.externalWrite("foreign")
    service.clearIfOwned()

    XCTAssertEqual(pasteboard.storedString, "foreign")
    XCTAssertEqual(pasteboard.clearCallCount, 0)
    XCTAssertNil(service.ownedChangeCount)
  }

  @MainActor
  func testOwnedChangeCountComesFromAfterSuccessfulWrite() throws {
    let pasteboard = FakePasteboardClient()
    let service = ClipboardService(
      pasteboard: pasteboard,
      sleeper: LongClipboardSleeper(),
      clearDelay: .seconds(30)
    )

    try service.copy("secret")

    XCTAssertEqual(pasteboard.changeCount, 2)
    XCTAssertEqual(service.ownedChangeCount, 2)
  }

  @MainActor
  func testClearFailureDoesNotCrashOrExposeDataInState() async throws {
    let pasteboard = FakePasteboardClient()
    pasteboard.shouldClearSucceed = false
    let service = ClipboardService(
      pasteboard: pasteboard,
      sleeper: FixedDelayClipboardSleeper(delay: .milliseconds(20)),
      clearDelay: .seconds(30)
    )

    try service.copy("secret")
    try await ContinuousClock().sleep(for: .milliseconds(60))

    XCTAssertEqual(pasteboard.storedString, "secret")
    XCTAssertEqual(pasteboard.clearCallCount, 1)
    XCTAssertEqual(service.ownedChangeCount, pasteboard.changeCount)
    XCTAssertFalse(service.hasScheduledClear)
  }
}
