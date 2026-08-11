import Foundation

protocol ClipboardSleeping: Sendable {
  func sleep(for duration: Duration) async throws
}

struct ContinuousClipboardSleeper: ClipboardSleeping {
  func sleep(for duration: Duration) async throws {
    try await ContinuousClock().sleep(for: duration)
  }
}

@MainActor
protocol ClipboardServicing: AnyObject {
  func copy(_ value: String) throws
  func clearIfOwned()
  func cancelScheduledClear()
}

@MainActor
final class ClipboardService: ClipboardServicing {
  private let pasteboard: any PasteboardClient
  private let sleeper: any ClipboardSleeping
  private let clearDelay: Duration

  private var clearTask: Task<Void, Never>?
  private(set) var ownedChangeCount: Int?

  init(
    pasteboard: (any PasteboardClient)? = nil,
    sleeper: any ClipboardSleeping = ContinuousClipboardSleeper(),
    clearDelay: Duration = AppConstants.clipboardClearDelay
  ) {
    self.pasteboard = pasteboard ?? SystemPasteboardClient()
    self.sleeper = sleeper
    self.clearDelay = clearDelay
  }

  var hasScheduledClear: Bool {
    clearTask != nil
  }

  func copy(_ value: String) throws {
    clearTask?.cancel()
    clearTask = nil
    ownedChangeCount = nil

    pasteboard.prepareForNewContents(currentHostOnly: true)

    guard pasteboard.writeString(value) else {
      throw ClipboardServiceError.writeFailed
    }

    let changeCountAfterWrite = pasteboard.changeCount
    ownedChangeCount = changeCountAfterWrite
    scheduleClear(expectedChangeCount: changeCountAfterWrite)
  }

  func clearIfOwned() {
    clearTask?.cancel()
    clearTask = nil

    guard
      let ownedChangeCount,
      pasteboard.changeCount == ownedChangeCount
    else {
      self.ownedChangeCount = nil
      return
    }

    if pasteboard.clearContents() {
      self.ownedChangeCount = nil
    }
  }

  func cancelScheduledClear() {
    clearTask?.cancel()
    clearTask = nil
  }

  private func scheduleClear(expectedChangeCount: Int) {
    let sleeper = sleeper
    let clearDelay = clearDelay

    clearTask = Task { [weak self] in
      do {
        try await sleeper.sleep(for: clearDelay)
      } catch {
        return
      }

      guard !Task.isCancelled else {
        return
      }

      self?.clearAfterDelay(expectedChangeCount: expectedChangeCount)
    }
  }

  private func clearAfterDelay(expectedChangeCount: Int) {
    guard ownedChangeCount == expectedChangeCount else {
      return
    }

    guard pasteboard.changeCount == expectedChangeCount else {
      ownedChangeCount = nil
      clearTask = nil
      return
    }

    if pasteboard.clearContents() {
      ownedChangeCount = nil
    }
    clearTask = nil
  }
}
