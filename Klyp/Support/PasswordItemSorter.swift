struct PasswordItemSorter: Sendable {
  func sorted(
    _ items: [PasswordItemSummary],
    orderValues: [PasswordItemSummary.ID: Double]
  ) -> [PasswordItemSummary] {
    items.sorted { lhs, rhs in
      let lhsOrder = orderValues[lhs.id] ?? 0
      let rhsOrder = orderValues[rhs.id] ?? 0

      if lhsOrder == rhsOrder {
        return lhs.id.uuidString < rhs.id.uuidString
      }

      return lhsOrder < rhsOrder
    }
  }
}
