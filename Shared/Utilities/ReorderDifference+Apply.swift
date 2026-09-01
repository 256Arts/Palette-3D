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
        let moving = Set(sources)
        guard !moving.isEmpty else { return }

        // One in-place pass: drop the moved items and capture them in order.
        var moved: [C.Element] = []
        moved.reserveCapacity(moving.count)
        collection.removeAll { element in
            guard moving.contains(element.id) else { return false }
            moved.append(element)
            return true
        }

        switch destination.position {
        case .before(let id):
            let index = collection.firstIndex { $0.id == id } ?? collection.endIndex
            collection.insert(contentsOf: moved, at: index)
        case .end:
            collection.append(contentsOf: moved)
        }
    }
}
