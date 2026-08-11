import SwiftUI

@MainActor
final class AppServices {
  static let shared = AppServices()

  let clipboardService: ClipboardService
  let viewModel: PasswordListViewModel

  private init() {
    let keychainStore = KeychainStore()
    let clipboardService = ClipboardService()
    let loginItemService = SystemLoginItemService()

    self.clipboardService = clipboardService
    viewModel = PasswordListViewModel(
      keychainStore: keychainStore,
      clipboardService: clipboardService,
      loginItemService: loginItemService
    )
  }
}

@main
struct KlypApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    MenuBarExtra("Klyp", systemImage: "key.horizontal.fill") {
      MenuBarContentView(viewModel: AppServices.shared.viewModel)
    }
    .menuBarExtraStyle(.window)
  }
}
