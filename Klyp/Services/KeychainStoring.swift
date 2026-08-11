import Foundation

protocol KeychainStoring: Sendable {
  func listItems() async throws -> KeychainItemList
  func readPassword(id: UUID) async throws -> String
  func addItem(title: String, password: String) async throws -> PasswordItemSummary
  func updateItem(id: UUID, title: String, password: String) async throws
  func setItemOrder(of id: UUID, orderedItemIDs: [UUID]) async throws
  func deleteItem(id: UUID) async throws
  func deleteAllItems() async throws
}
