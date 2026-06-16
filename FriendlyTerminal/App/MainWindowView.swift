import SwiftUI

struct MainWindowView: View {
    @Environment(Workspace.self) private var workspace

    var body: some View {
        VStack(spacing: 0) {
            BreadcrumbBarView()
                .environment(workspace.focused)

            Divider()

            HSplitView {
                if workspace.sidebarVisible {
                    SidebarColumnView()
                        .environment(workspace.focused)
                        .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)
                }

                HSplitView {
                    ForEach(workspace.sessions) { session in
                        TerminalPaneView(session: session)
                            .frame(minWidth: 140, maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 700, minHeight: 400)
        .background(Color(nsColor: .textBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .sendToShell)) { note in
            if let text = note.object as? String {
                workspace.focused.sendToShell?(text)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) { workspace.sidebarVisible.toggle() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newPane)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) { workspace.addPane() }
        }
        .onAppear {
            workspace.focused.refreshFileItems()
        }
    }
}

#Preview {
    MainWindowView()
        .environment(Workspace())
        .frame(width: 1100, height: 720)
}
