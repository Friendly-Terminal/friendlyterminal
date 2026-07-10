import SwiftUI

struct SidebarColumnView: View {
    @Environment(SessionState.self) private var session

    var body: some View {
        VStack(spacing: 0) {
            FileSidebarView()
                .frame(maxHeight: .infinity)
                .coachmarkTarget(Coachmark.fileSidebar)

            Divider()

            Group {
                if session.isTUIActive && session.isClaudeRunning {
                    ClaudeControlBarView()
                } else if session.isTUIActive {
                    InteractiveHintView()
                } else {
                    VStack(spacing: 0) {
                        ProjectCommandsView()
                        CommandHelpView()
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .coachmarkTarget(Coachmark.commandHelp)
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.2), value: session.isTUIActive)
        .animation(.easeInOut(duration: 0.2), value: session.isClaudeRunning)
    }
}
