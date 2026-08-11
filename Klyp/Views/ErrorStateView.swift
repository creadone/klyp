import SwiftUI

struct ErrorStateView: View {
  let message: String
  let retryAction: () -> Void

  var body: some View {
    VStack(spacing: 10) {
      Image(systemName: "exclamationmark.triangle")
        .font(.title2)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text(message)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)

      Button("Повторить", action: retryAction)
    }
    .frame(maxWidth: .infinity, minHeight: 150)
    .padding()
    .accessibilityElement(children: .contain)
  }
}
