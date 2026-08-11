import AppKit
import SwiftUI

struct AppMenuView: View {
  @ObservedObject var viewModel: PasswordListViewModel

  var body: some View {
    Menu {
      if let warningMessage = viewModel.warningMessage {
        Button {} label: {
          Label(warningMessage, systemImage: "exclamationmark.triangle")
        }
        .disabled(true)

        Divider()
      }

      loginItemButton

      Divider()

      Button("Удалить все данные…", role: .destructive) {
        viewModel.requestDeleteAll()
      }
      .disabled(viewModel.items.isEmpty || viewModel.isMutationInProgress)

      Divider()

      Button("Выйти") {
        NSApplication.shared.terminate(nil)
      }
    } label: {
      Image(systemName: "ellipsis")
        .frame(width: 20, height: 20)
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
    .help("Системные команды")
    .accessibilityLabel("Системные команды")
  }

  @ViewBuilder
  private var loginItemButton: some View {
    switch viewModel.loginItemStatus {
    case .enabled:
      Button {
        viewModel.toggleLoginItem()
      } label: {
        Label("Запускать при входе", systemImage: "checkmark")
      }
    case .requiresApproval:
      Button {
        viewModel.toggleLoginItem()
      } label: {
        Label("Запускать при входе", systemImage: "exclamationmark.triangle")
      }
    case .disabled:
      Button("Запускать при входе") {
        viewModel.toggleLoginItem()
      }
    case .unavailable:
      Button {
        viewModel.toggleLoginItem()
      } label: {
        Label("Запускать при входе", systemImage: "xmark.circle")
      }
    }
  }
}
