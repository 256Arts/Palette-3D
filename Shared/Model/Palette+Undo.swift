import Foundation
import PaletteKit

extension Palette {

    /// Everything an edit in the editor can change. Undo restores all of it together, so undoing past
    /// the edit that customized a perfect palette also unlocks its parameters again.
    struct EditState: Equatable {
        var colors: [PaletteColor]
        var parameters: PaletteGenerator.Parameters?
        var isCustomized: Bool
    }

    var editState: EditState {
        get { EditState(colors: colors, parameters: parameters, isCustomized: isCustomized) }
        set {
            colors = newValue.colors
            parameters = newValue.parameters
            isCustomized = newValue.isCustomized
            dateModified = .now
        }
    }

    /// Registers the step from `previous` to the current state with `undoManager`, named for what
    /// changed. Undoing restores `previous` and registers the redo in turn, so the step can be walked
    /// back and forth; `onRestore` hears each state it restores.
    @MainActor func registerUndo(from previous: EditState, with undoManager: UndoManager, onRestore: @escaping @MainActor (EditState) -> Void = { _ in }) {
        registerUndo(from: previous, with: undoManager,
                     actionName: Self.actionName(from: previous, to: editState), onRestore: onRestore)
    }

    /// The redo keeps the undo's name: named afresh, it would describe the edit backwards.
    @MainActor private func registerUndo(from previous: EditState, with undoManager: UndoManager, actionName: String, onRestore: @escaping @MainActor (EditState) -> Void) {
        let current = editState
        guard previous != current else { return }
        undoManager.registerUndo(withTarget: self) { palette in
            palette.editState = previous
            onRestore(previous)
            palette.registerUndo(from: current, with: undoManager, actionName: actionName, onRestore: onRestore)
        }
        undoManager.setActionName(actionName)
    }

    private static func actionName(from previous: EditState, to current: EditState) -> String {
        if previous.isCustomized && !current.isCustomized {
            String(localized: "Discard Manual Edits")
        } else if previous.parameters != current.parameters {
            String(localized: "Change Parameters")
        } else {
            String(localized: "Edit Colors")
        }
    }
}
