import Foundation

@MainActor
protocol PasteboardClient: AnyObject {
  var changeCount: Int { get }
  @discardableResult func prepareForNewContents(currentHostOnly: Bool) -> Int
  func writeString(_ value: String) -> Bool
  @discardableResult func clearContents() -> Bool
}

@MainActor
final class SystemPasteboardClient: PasteboardClient {
  private(set) var changeCount = 0

  func prepareForNewContents(currentHostOnly: Bool) -> Int {
    changeCount += 1
    return changeCount
  }

  func writeString(_ value: String) -> Bool {
    changeCount += 1
    return true
  }

  func clearContents() -> Bool {
    changeCount += 1
    return true
  }
}
