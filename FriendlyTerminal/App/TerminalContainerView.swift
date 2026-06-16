import SwiftUI

struct TerminalContainerView: View {
    @Environment(SessionState.self) private var session
    @Environment(Workspace.self) private var workspace

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
                isTUIActive: session.isTUIActive,
                isFocusedPane: workspace.focusedID == session.id,
                onTerminated: {
                    workspace.handleSessionExit(session.id)
                },
                onFocusRequested: {
                    workspace.focus(session.id)
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
            // A fresh command starts non-interactive; only its own signals count
            // (ignore any bracketed-paste state left on by the shell's prompt).
            session.altScreenOn = false
            session.bracketedPasteOn = false
            refreshInteractive()

        case .commandEnd(let exitCode):
            session.blockStore.finishBlock(exitCode: exitCode)
            session.altScreenOn = false
            session.bracketedPasteOn = false
            refreshInteractive()

        case .output(let text):
            // While an interactive program owns the screen, its redraw stream is
            // cursor noise — don't fold it into the command block's text.
            if !session.isTUIActive {
                session.blockStore.appendOutput(plain: text, attributed: nil)
            }

        case .altScreen(let on):
            session.altScreenOn = on
            refreshInteractive()

        case .bracketedPaste(let on):
            session.bracketedPasteOn = on
            refreshInteractive()

        case .cwdUpdate(let path):
            _ = path

        case .promptStart:
            break
        }
    }

    /// The live terminal takes over when a full-screen program is on the
    /// alternate screen, or when a *running* command turns on bracketed-paste
    /// mode (raw-input programs like Claude Code that render inline).
    private func refreshInteractive() {
        let commandRunning = session.blockStore.currentBlock != nil
        let interactive = session.altScreenOn || (session.bracketedPasteOn && commandRunning)
        if interactive != session.isTUIActive {
            withAnimation(.easeInOut(duration: 0.15)) {
                session.isTUIActive = interactive
            }
        }
    }
}
