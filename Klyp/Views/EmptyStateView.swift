import SwiftUI

struct EmptyStateView: View {
  let addAction: () -> Void

  var body: some View {
    VStack(spacing: 6) {
      Text("Паролей пока нет")
        .font(.headline)

      Text("Нажмите +, чтобы добавить первый")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Button("Добавить пароль", action: addAction)
        .controlSize(.small)
        .padding(.top, 6)
    }
    .frame(maxWidth: .infinity, minHeight: 150)
    .padding()
    .accessibilityElement(children: .contain)
  }
}
