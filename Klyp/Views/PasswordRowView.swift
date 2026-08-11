import SwiftUI

struct PasswordRowView: View {
  let item: PasswordItemSummary
  let isCopied: Bool
  let copyAction: () -> Void
  let dragItemProvider: () -> NSItemProvider
  let editAction: () -> Void
  let deleteAction: () -> Void

  @State private var isHovering = false

  var body: some View {
    HStack(spacing: 4) {
      Text(item.title)
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, minHeight: AppConstants.minimumRowHeight)
        .simultaneousGesture(
          TapGesture().onEnded(copyAction)
        )
        .onDrag(dragItemProvider)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityHint("Скопировать пароль")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text("Скопировать пароль"), copyAction)

      Menu {
        Button("Изменить", action: editAction)
        Button("Удалить", role: .destructive, action: deleteAction)
      } label: {
        Image(systemName: "ellipsis")
          .frame(width: 20, height: AppConstants.minimumRowHeight)
          .contentShape(Rectangle())
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .fixedSize()
      .opacity(isHovering ? 1 : 0)
      .accessibilityLabel("Действия для \(item.title)")
    }
    .padding(.horizontal, 12)
    .frame(maxWidth: .infinity)
    .background(backgroundColor)
    .contentShape(Rectangle())
    .onHover { isHovering = $0 }
    .contextMenu {
      Button("Изменить", action: editAction)
      Button("Удалить", role: .destructive, action: deleteAction)
    }
    .help(item.title)
  }

  private var backgroundColor: Color {
    if isCopied {
      return Color(nsColor: .systemGreen).opacity(0.18)
    }

    if isHovering {
      return Color.primary.opacity(0.05)
    }

    return Color.clear
  }
}
