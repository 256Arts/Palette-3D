import SwiftUI

// `ReorderDifference` is OS 27-only, so this gate goes away with OS 26 — at which point
// `PaletteGridView` can hand the difference straight to `DisplayView` again.
@available(iOS 27, macOS 27, visionOS 27, *)
extension ReorderDifference where CollectionID == ReorderableSingleCollectionIdentifier {
    /// Reorders `collection` in place to reflect this single-collection move.
    func apply<C>(to collection: inout C)
        where C: RangeReplaceableCollection,
              C.Element: Identifiable,
              C.Element.ID == ItemID
    {
        let before: ItemID? = switch destination.position {
        case .before(let id): id
        case .end: nil
        }
        collection.move(ids: sources, before: before)
    }
}

extension RangeReplaceableCollection where Element: Identifiable {
    /// Moves the elements identified by `ids` — in their current order — to just before the element
    /// `before`, or to the end when it's `nil` or not found. Split from `ReorderDifference.apply(to:)`,
    /// which has no public initializer and so can't be built in a test.
    mutating func move(ids: [Element.ID], before: Element.ID?) {
        let moving = Set(ids)
        guard !moving.isEmpty else { return }

        // One in-place pass: drop the moved items and capture them in order.
        var moved: [Element] = []
        moved.reserveCapacity(moving.count)
        removeAll { element in
            guard moving.contains(element.id) else { return false }
            moved.append(element)
            return true
        }

        let index = before.flatMap { id in firstIndex { $0.id == id } } ?? endIndex
        insert(contentsOf: moved, at: index)
    }
}
