import SwiftUI

struct TerminalContainerView: View {
    @Environment(SessionState.self) private var session

    var body: some View {
        ZStack {
            TerminalBridge(
                onCwdChange: { path in
                    session.updateCwd(path)
                },
                onTitleChange: { title in
                    session.windowTitle = title
                },
                onShellEvent: { event in
                    handleShellEvent(event)
                },
                onTUIChange: { active in
                    session.isTUIActive = active
                },
                onReady: { sender in
                    session.sendToShell = sender
                }
            )
            .opacity(session.isTUIActive ? 1 : 0)
            .allowsHitTesting(session.isTUIActive)

            if !session.isTUIActive {
                BlockListView()
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.15), value: session.isTUIActive)
        .onReceive(NotificationCenter.default.publisher(for: .sendToShell)) { note in
            if let text = note.object as? String {
                session.sendToShell?(text)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                session.sidebarVisible.toggle()
            }
        }
    }

    private func handleShellEvent(_ event: ShellIntegrationParser.Event) {
        switch event {
        case .commandStart:
            break

        case .commandText(let text):
            session.pendingCommandText = text

        case .outputStart:
            let cmd = session.pendingCommandText
            let cwd = session.cwd
            session.pendingCommandText = ""
            session.blockStore.startBlock(command: cmd, cwd: cwd)

        case .commandEnd(let exitCode):
            session.blockStore.finishBlock(exitCode: exitCode)

        case .cwdUpdate(let path):
            _ = path

        case .promptStart:
            break
        }
    }
}
