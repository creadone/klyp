import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationWillFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.accessory)

    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
      return
    }

    guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
      return
    }

    let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
    let otherInstances =
      NSRunningApplication
      .runningApplications(withBundleIdentifier: bundleIdentifier)
      .filter { $0.processIdentifier != currentProcessIdentifier }

    if !otherInstances.isEmpty {
      DispatchQueue.main.async {
        NSApplication.shared.terminate(nil)
      }
    }
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    AppServices.shared.viewModel.prepareForTermination()
    return .terminateNow
  }
}
