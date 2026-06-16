import SwiftUI

/// The left column: file list on top, and either the interactive-program hints
/// (during a TUI) or the command-help menu below. Operates on whichever session
/// is currently focused (injected by the parent).
struct SidebarColumnView: View {
    @Environment(SessionState.self) private var session

    var body: some View {
        VStack(spacing: 0) {
            FileSidebarView()
                .frame(maxHeight: .infinity)

            Divider()

            Group {
                if session.isTUIActive {
                    InteractiveHintView()
                } else {
                    CommandHelpView()
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.2), value: session.isTUIActive)
    }
}
