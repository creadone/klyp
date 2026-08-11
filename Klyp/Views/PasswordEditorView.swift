import SwiftUI

struct PasswordEditorView: View {
  enum Mode: Equatable {
    case add
    case edit(PasswordItemSummary)

    var title: String {
      switch self {
      case .add:
        "Новый пароль"
      case .edit:
        "Изменить пароль"
      }
    }

    var item: PasswordItemSummary? {
      switch self {
      case .add:
        nil
      case .edit(let item):
        item
      }
    }
  }

  private enum Field: Hashable {
    case title
    case password
  }

  let mode: Mode
  @ObservedObject var viewModel: PasswordListViewModel

  @State private var title: String
  @State private var password = ""
  @State private var isPasswordVisible = false
  @State private var isLoadingPassword: Bool
  @State private var didPrepare = false
  @State private var loadingErrorMessage: String?
  @State private var operationErrorMessage: String?
  @FocusState private var focusedField: Field?

  init(mode: Mode, viewModel: PasswordListViewModel) {
    self.mode = mode
    self.viewModel = viewModel
    _title = State(initialValue: mode.item?.title ?? "")
    _isLoadingPassword = State(initialValue: mode.item != nil)
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      editorContent
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .task {
      await prepareIfNeeded()
    }
    .onExitCommand {
      guard !viewModel.isMutationInProgress else {
        return
      }
      cancel()
    }
    .onDisappear {
      clearSensitiveState()
    }
  }

  private var header: some View {
    HStack {
      Text(mode.title)
        .font(.headline)

      Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
  }

  @ViewBuilder
  private var editorContent: some View {
    if isLoadingPassword {
      VStack(spacing: 10) {
        ProgressView()
          .controlSize(.small)

        Text("Загрузка пароля…")
          .font(.caption)
          .foregroundStyle(.secondary)

        Button("Отмена", role: .cancel) {
          cancel()
        }
      }
      .frame(maxWidth: .infinity, minHeight: 180)
    } else if let loadingErrorMessage {
      VStack(spacing: 10) {
        Text(loadingErrorMessage)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)

        HStack {
          Button("Отмена", role: .cancel) {
            cancel()
          }
          .disabled(viewModel.isMutationInProgress)

          Button("Повторить") {
            Task {
              await loadPasswordForEditing()
            }
          }
        }
      }
      .frame(maxWidth: .infinity, minHeight: 180)
      .padding()
    } else {
      form
    }
  }

  private var form: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 5) {
        Text("Название")
          .font(.caption)
          .foregroundStyle(.secondary)

        TextField("Название", text: $title)
          .textFieldStyle(.roundedBorder)
          .focused($focusedField, equals: .title)
          .accessibilityLabel("Название")
      }

      VStack(alignment: .leading, spacing: 5) {
        Text("Пароль")
          .font(.caption)
          .foregroundStyle(.secondary)

        HStack(spacing: 6) {
          Group {
            if isPasswordVisible {
              TextField("Пароль", text: $password)
            } else {
              SecureField("Пароль", text: $password)
            }
          }
          .textFieldStyle(.roundedBorder)
          .focused($focusedField, equals: .password)
          .privacySensitive()
          .accessibilityLabel("Пароль")
          .accessibilityValue(password.isEmpty ? "Не введён" : "Введён")

          Button {
            isPasswordVisible.toggle()
            focusedField = .password
          } label: {
            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
          }
          .buttonStyle(.borderless)
          .help(isPasswordVisible ? "Скрыть пароль" : "Показать пароль")
          .accessibilityLabel(isPasswordVisible ? "Скрыть пароль" : "Показать пароль")
        }
      }

      if let message = displayedErrorMessage {
        Text(message)
          .font(.caption)
          .foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityLabel("Ошибка: \(message)")
      }

      HStack {
        Button("Отмена", role: .cancel) {
          cancel()
        }
        .disabled(viewModel.isMutationInProgress)

        Spacer()

        if viewModel.isMutationInProgress {
          ProgressView()
            .controlSize(.small)
        }

        Button("Сохранить") {
          Task {
            await save()
          }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(isSaveDisabled)
      }
    }
    .padding(12)
  }

  private var validationError: PasswordValidationError? {
    viewModel.validationError(
      title: title,
      password: password,
      excluding: mode.item?.id
    )
  }

  private var displayedErrorMessage: String? {
    if let operationErrorMessage {
      return operationErrorMessage
    }

    if validationError == .duplicateTitle {
      return PasswordValidationError.duplicateTitle.userMessage
    }

    return nil
  }

  private var isSaveDisabled: Bool {
    isLoadingPassword
      || loadingErrorMessage != nil
      || validationError != nil
      || viewModel.isMutationInProgress
  }

  private func prepareIfNeeded() async {
    guard !didPrepare else {
      return
    }

    didPrepare = true

    if mode.item != nil {
      await loadPasswordForEditing()
    } else {
      await Task.yield()
      focusedField = .title
    }
  }

  private func loadPasswordForEditing() async {
    guard let item = mode.item else {
      return
    }

    isLoadingPassword = true
    loadingErrorMessage = nil

    do {
      let loadedPassword = try await viewModel.passwordForEditing(id: item.id)
      guard !Task.isCancelled else {
        return
      }

      password = loadedPassword
      isPasswordVisible = false
      isLoadingPassword = false
      await Task.yield()
      focusedField = .title
    } catch {
      password.removeAll(keepingCapacity: false)
      isLoadingPassword = false
      loadingErrorMessage = UserFacingError.message(for: error)
    }
  }

  private func save() async {
    guard let validationError = validationError else {
      operationErrorMessage = nil

      do {
        if let item = mode.item {
          try await viewModel.updateItem(
            id: item.id,
            title: title,
            password: password
          )
        } else {
          try await viewModel.addItem(title: title, password: password)
        }

        clearSensitiveState()
      } catch {
        operationErrorMessage = UserFacingError.message(for: error)
      }
      return
    }

    operationErrorMessage = validationError.userMessage
  }

  private func cancel() {
    clearSensitiveState()
    viewModel.cancelEditor()
  }

  private func clearSensitiveState() {
    password.removeAll(keepingCapacity: false)
    isPasswordVisible = false
    operationErrorMessage = nil
  }
}
