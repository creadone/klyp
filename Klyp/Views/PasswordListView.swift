import SwiftUI
import UniformTypeIdentifiers

struct PasswordListView: View {
  @ObservedObject var viewModel: PasswordListViewModel
  @State private var draggedItemID: UUID?
  @State private var dropTarget: PasswordDropTarget?

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      content
    }
    .background(Color(nsColor: .windowBackgroundColor))
  }

  private var header: some View {
    HStack {
      Text("Klyp")
        .font(.headline)

      Spacer()

      Button {
        viewModel.beginAdding()
      } label: {
        Image(systemName: "plus")
      }
      .buttonStyle(.borderless)
      .keyboardShortcut("n", modifiers: .command)
      .help("Добавить пароль")
      .accessibilityLabel("Добавить пароль")
      .disabled(
        viewModel.isMutationInProgress
          || (viewModel.loadErrorMessage != nil && !viewModel.hasLoaded)
      )

      Divider()
        .frame(height: 16)

      AppMenuView(viewModel: viewModel)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
  }

  @ViewBuilder
  private var content: some View {
    if viewModel.isLoading, !viewModel.hasLoaded {
      ProgressView()
        .controlSize(.small)
        .frame(maxWidth: .infinity, minHeight: 150)
    } else if let message = viewModel.loadErrorMessage {
      ErrorStateView(message: message) {
        Task {
          await viewModel.reload()
        }
      }
    } else if viewModel.items.isEmpty {
      EmptyStateView {
        viewModel.beginAdding()
      }
    } else {
      passwordList
    }
  }

  private var listHeight: CGFloat {
    min(
      max(
        CGFloat(viewModel.items.count) * AppConstants.minimumRowHeight,
        AppConstants.minimumRowHeight
      ),
      AppConstants.maximumListHeight
    )
  }

  private var passwordList: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(viewModel.items) { item in
          PasswordRowView(
            item: item,
            isCopied: viewModel.copiedItemID == item.id,
            copyAction: {
              viewModel.requestCopy(item)
            },
            dragItemProvider: {
              draggedItemID = item.id
              return NSItemProvider(object: item.id.uuidString as NSString)
            },
            editAction: {
              viewModel.beginEditing(item)
            },
            deleteAction: {
              viewModel.requestDeletion(of: item)
            }
          )
          .onDrop(
            of: [UTType.text],
            delegate: PasswordRowDropDelegate(
              targetItemID: item.id,
              draggedItemID: $draggedItemID,
              dropTarget: $dropTarget,
              moveAction: { sourceID, targetID, edge in
                Task {
                  await viewModel.moveItem(
                    id: sourceID,
                    relativeTo: targetID,
                    placeAfterTarget: edge == .bottom
                  )
                }
              }
            )
          )
          .overlay(alignment: .top) {
            if dropTarget == PasswordDropTarget(itemID: item.id, edge: .top) {
              dropIndicator
            }
          }
          .overlay(alignment: .bottom) {
            if dropTarget == PasswordDropTarget(itemID: item.id, edge: .bottom) {
              dropIndicator
            } else if item.id != viewModel.items.last?.id {
              Color.primary
                .opacity(0.08)
                .frame(height: 1)
                .allowsHitTesting(false)
            }
          }
        }
      }
      .frame(maxWidth: .infinity)
    }
    .frame(height: listHeight)
  }

  private var dropIndicator: some View {
    Color.accentColor
      .frame(height: 2)
      .allowsHitTesting(false)
  }
}

private struct PasswordDropTarget: Equatable {
  enum Edge: Equatable {
    case top
    case bottom
  }

  let itemID: UUID
  let edge: Edge
}

private struct PasswordRowDropDelegate: DropDelegate {
  let targetItemID: UUID
  @Binding var draggedItemID: UUID?
  @Binding var dropTarget: PasswordDropTarget?
  let moveAction: (UUID, UUID, PasswordDropTarget.Edge) -> Void

  func validateDrop(info: DropInfo) -> Bool {
    draggedItemID != nil && draggedItemID != targetItemID
  }

  func dropEntered(info: DropInfo) {
    updateDropTarget(using: info)
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    updateDropTarget(using: info)
    return DropProposal(operation: .move)
  }

  func dropExited(info: DropInfo) {
    if dropTarget?.itemID == targetItemID {
      dropTarget = nil
    }
  }

  func performDrop(info: DropInfo) -> Bool {
    guard
      let sourceID = draggedItemID,
      sourceID != targetItemID
    else {
      dropTarget = nil
      draggedItemID = nil
      return false
    }

    let edge = edge(for: info)
    dropTarget = nil
    draggedItemID = nil
    moveAction(sourceID, targetItemID, edge)
    return true
  }

  private func updateDropTarget(using info: DropInfo) {
    guard draggedItemID != targetItemID else {
      dropTarget = nil
      return
    }

    dropTarget = PasswordDropTarget(
      itemID: targetItemID,
      edge: edge(for: info)
    )
  }

  private func edge(for info: DropInfo) -> PasswordDropTarget.Edge {
    info.location.y < AppConstants.minimumRowHeight / 2 ? .top : .bottom
  }
}
