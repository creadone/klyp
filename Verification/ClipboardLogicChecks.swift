import Foundation

@MainActor
final class HarnessPasteboardClient: PasteboardClient {
  private(set) var storedString: String?
  private(set) var changeCount = 0
  private(set) var currentHostOnlyValues: [Bool] = []
  private(set) var clearCount = 0

  func prepareForNewContents(currentHostOnly: Bool) -> Int {
    currentHostOnlyValues.append(currentHostOnly)
    storedString = nil
    changeCount += 1
    return changeCount
  }

  func writeString(_ value: String) -> Bool {
    storedString = value
    changeCount += 1
    return true
  }

  func clearContents() -> Bool {
    clearCount += 1
    storedString = nil
    changeCount += 1
    return true
  }

  func externalWrite(_ value: String) {
    storedString = value
    changeCount += 1
  }
}

struct HarnessSleeper: ClipboardSleeping {
  let actualDelay: Duration

  func sleep(for duration: Duration) async throws {
    try await ContinuousClock().sleep(for: actualDelay)
  }
}

@main
struct ClipboardLogicChecks {
  @MainActor
  static func main() async throws {
    let exactPassword = "  P@ss/\"\\[]{}:=+🙂  "

    let firstPasteboard = HarnessPasteboardClient()
    let firstService = ClipboardService(
      pasteboard: firstPasteboard,
      sleeper: HarnessSleeper(actualDelay: .milliseconds(25)),
      clearDelay: .seconds(30)
    )
    try firstService.copy(exactPassword)
    try require(firstPasteboard.storedString == exactPassword, "Строка должна копироваться точно")
    try require(firstPasteboard.currentHostOnlyValues == [true], "currentHostOnly обязателен")
    try require(
      firstService.ownedChangeCount == firstPasteboard.changeCount,
      "Нужно сохранить changeCount после записи"
    )
    try await ContinuousClock().sleep(for: .milliseconds(70))
    try require(firstPasteboard.storedString == nil, "Неизменённый буфер должен очищаться")

    let secondPasteboard = HarnessPasteboardClient()
    let secondService = ClipboardService(
      pasteboard: secondPasteboard,
      sleeper: HarnessSleeper(actualDelay: .milliseconds(30)),
      clearDelay: .seconds(30)
    )
    try secondService.copy("secret")
    secondPasteboard.externalWrite("foreign")
    try await ContinuousClock().sleep(for: .milliseconds(80))
    try require(
      secondPasteboard.storedString == "foreign",
      "Более новое содержимое буфера нельзя удалять"
    )

    let thirdPasteboard = HarnessPasteboardClient()
    let thirdService = ClipboardService(
      pasteboard: thirdPasteboard,
      sleeper: HarnessSleeper(actualDelay: .seconds(60)),
      clearDelay: .seconds(30)
    )
    try thirdService.copy("owned")
    thirdService.clearIfOwned()
    try require(
      thirdPasteboard.storedString == nil, "Собственное значение нужно очищать при выходе")

    print("Clipboard logic checks: PASS")
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
