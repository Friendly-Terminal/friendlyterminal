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

    private static let savedCwdsKey = "savedPaneCwds"

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: Self.savedCwdsKey) ?? []
        let restored = saved.prefix(Self.maxPanes).map { SessionState(restoredCwd: $0) }
        let initial = restored.isEmpty ? [SessionState()] : Array(restored)
        sessions = initial
        focusedID = initial[0].id
        for session in initial { hookPersistence(session) }
    }

    private func hookPersistence(_ session: SessionState) {
        session.onCwdChange = { [weak self] in self?.persistPanes() }
    }

    private func persistPanes() {
        UserDefaults.standard.set(sessions.map(\.cwd), forKey: Self.savedCwdsKey)
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
        hookPersistence(new)
        persistPanes()
    }

    func focus(_ id: UUID) {
        guard focusedID != id, sessions.contains(where: { $0.id == id }) else { return }
        focusedID = id
    }

    func closePane(_ id: UUID) {
        guard sessions.count > 1, let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions.remove(at: index)
        if focusedID == id { focusedID = sessions[0].id }
        persistPanes()
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
