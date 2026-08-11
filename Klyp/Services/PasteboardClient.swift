import AppKit
import Foundation

@MainActor
protocol PasteboardClient: AnyObject {
  var changeCount: Int { get }

  @discardableResult
  func prepareForNewContents(currentHostOnly: Bool) -> Int

  func writeString(_ value: String) -> Bool

  @discardableResult
  func clearContents() -> Bool
}

@MainActor
final class SystemPasteboardClient: PasteboardClient {
  private let pasteboard: NSPasteboard

  init(pasteboard: NSPasteboard = .general) {
    self.pasteboard = pasteboard
  }

  var changeCount: Int {
    pasteboard.changeCount
  }

  @discardableResult
  func prepareForNewContents(currentHostOnly: Bool) -> Int {
    let options: NSPasteboard.ContentsOptions = currentHostOnly ? [.currentHostOnly] : []
    return pasteboard.prepareForNewContents(with: options)
  }

  func writeString(_ value: String) -> Bool {
    pasteboard.setString(value, forType: .string)
  }

  @discardableResult
  func clearContents() -> Bool {
    _ = pasteboard.clearContents()
    return true
  }
}
