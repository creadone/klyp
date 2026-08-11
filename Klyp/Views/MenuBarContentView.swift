import SwiftUI

struct MenuBarContentView: View {
  @ObservedObject var viewModel: PasswordListViewModel

  var body: some View {
    Group {
      if let confirmation = viewModel.deletionConfirmation {
        deletionConfirmation(for: confirmation)
      } else {
        screenContent
      }
    }
    .frame(width: AppConstants.popoverWidth)
    .task {
      await viewModel.loadIfNeeded()
    }
    .onAppear {
      viewModel.refreshLoginItemStatus()
    }
    .alert(item: $viewModel.dialog) { dialog in
      alert(for: dialog.kind)
    }
  }

  private func alert(for kind: PasswordListViewModel.DialogKind) -> Alert {
    switch kind {
    case .error(let message):
      Alert(
        title: Text("Ошибка"),
        message: Text(message),
        dismissButton: .default(Text("OK"))
      )

    case .loginItemApprovalRequired:
      Alert(
        title: Text("Требуется подтверждение"),
        message: Text(
          "Разрешите Klyp запускаться при входе в разделе «Объекты входа» системных настроек."
        ),
        primaryButton: .default(Text("Открыть настройки")) {
          viewModel.openLoginItemSettings()
        },
        secondaryButton: .cancel(Text("Отмена"))
      )
    }
  }

  @ViewBuilder
  private var screenContent: some View {
    switch viewModel.screen {
    case .list:
      PasswordListView(viewModel: viewModel)
    case .add:
      PasswordEditorView(mode: .add, viewModel: viewModel)
    case .edit(let item):
      PasswordEditorView(mode: .edit(item), viewModel: viewModel)
    }
  }

  private func deletionConfirmation(
    for confirmation: PasswordListViewModel.DeletionConfirmation
  ) -> some View {
    let content: (title: String, message: String)

    switch confirmation {
    case .item(let item):
      content = (
        title: "Удалить «\(item.title)»?",
        message: "Пароль будет удалён из Keychain."
      )
    case .all(let itemCount):
      content = (
        title: "Удалить все данные?",
        message: deleteAllMessage(itemCount: itemCount)
      )
    }

    return DeletionConfirmationView(
      title: content.title,
      message: content.message,
      isDeleting: viewModel.isMutationInProgress,
      cancelAction: viewModel.cancelDeletion,
      deleteAction: {
        Task {
          await viewModel.confirmDeletion()
        }
      }
    )
  }

  private func deleteAllMessage(itemCount: Int) -> String {
    "Будут удалены только записи Klyp: \(itemCount). Это действие нельзя отменить."
  }
}

private struct DeletionConfirmationView: View {
  let title: String
  let message: String
  let isDeleting: Bool
  let cancelAction: () -> Void
  let deleteAction: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.headline)
        .lineLimit(2)
        .truncationMode(.tail)

      Text(message)
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 8) {
        Spacer()

        Button("Отмена", action: cancelAction)
          .keyboardShortcut(.cancelAction)

        Button("Удалить", role: .destructive, action: deleteAction)
      }
      .disabled(isDeleting)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
