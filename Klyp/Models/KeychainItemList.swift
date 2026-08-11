import Foundation

struct KeychainItemList: Equatable, Sendable {
  let items: [PasswordItemSummary]
  let skippedCorruptedItems: Int
}
