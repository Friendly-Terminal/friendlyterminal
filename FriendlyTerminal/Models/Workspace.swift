import AppKit
import Observation

/// Owns the terminal panes for a window (up to two, side by side) and tracks
/// which one is focused so the sidebar, breadcrumb, and menu actions follow it.
@Observable
@MainActor
final class Workspace {
    static let maxPanes = 6

    private(set) var sessions: [SessionState]
    var focusedID: UUID
    var sidebarVisible: Bool = true

    init() {
        let first = SessionState()
        sessions = [first]
        focusedID = first.id
    }

    var focused: SessionState {
        sessions.first { $0.id == focusedID } ?? sessions[0]
    }

    var isSplit: Bool { sessions.count > 1 }
    var canAddPane: Bool { sessions.count < Self.maxPanes }

    func addPane() {
        guard canAddPane else { return }
        let new = SessionState()
        sessions.append(new)
        focusedID = new.id
    }

    func focus(_ id: UUID) {
        guard focusedID != id, sessions.contains(where: { $0.id == id }) else { return }
        focusedID = id
    }

    func closePane(_ id: UUID) {
        guard sessions.count > 1, let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions.remove(at: index)
        if focusedID == id { focusedID = sessions[0].id }
    }

    /// Called when a pane's shell process exits on its own (e.g. the user typed
    /// `exit`). Closes just that pane, or quits the app if it was the last one.
    func handleSessionExit(_ id: UUID) {
        guard sessions.contains(where: { $0.id == id }) else { return }
        if sessions.count <= 1 {
            NSApplication.shared.terminate(nil)
        } else {
            closePane(id)
        }
    }
}
