import XCTest

@testable import Klyp

final class PasswordItemSorterTests: XCTestCase {
  func testSortingUsesStoredOrderInsteadOfTitle() {
    let sorter = PasswordItemSorter()
    let items = [
      PasswordItemSummary(id: UUID(), title: "A"),
      PasswordItemSummary(id: UUID(), title: "B"),
      PasswordItemSummary(id: UUID(), title: "C"),
    ]
    let orderValues = [
      items[0].id: 30.0,
      items[1].id: 10.0,
      items[2].id: 20.0,
    ]

    let sorted = sorter.sorted(items, orderValues: orderValues)

    XCTAssertEqual(sorted.map(\.title), ["B", "C", "A"])
    XCTAssertEqual(sorter.sorted(sorted, orderValues: orderValues), sorted)
  }
}
