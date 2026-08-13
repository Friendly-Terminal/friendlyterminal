import SwiftUI

struct TerminalContainerView: View {
    @Environment(SessionState.self) private var session
    @Environment(Workspace.self) private var workspace

    @State private var passwordPromptActive = false

    var body: some View {
        let showTerminal = session.isTUIActive || passwordPromptActive
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
                isTUIActive: showTerminal,
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
            .opacity(showTerminal ? 1 : 0)
            .allowsHitTesting((session.isTUIActive && !session.isClaudeRunning) || passwordPromptActive)

            if !showTerminal {
                BlockListView()
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.15), value: showTerminal)
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
            session.altScreenOn = false
            session.bracketedPasteOn = false
            passwordPromptActive = false
            refreshInteractive()

        case .commandEnd(let exitCode):
            session.blockStore.finishBlock(exitCode: exitCode)
            session.attachUndoPlan(exitCode: exitCode)
            session.altScreenOn = false
            session.bracketedPasteOn = false
            passwordPromptActive = false
            refreshInteractive()

        case .output(let text):
            if !session.isTUIActive {
                session.blockStore.appendOutput(plain: text, attributed: nil)
                updatePasswordPrompt()
            }

        case .outputDiscardLine:
            if !session.isTUIActive, let block = session.blockStore.currentBlock {
                if let nl = block.plainText.lastIndex(of: "\n") {
                    block.plainText = String(block.plainText[...nl])
                } else {
                    block.plainText = ""
                }
                if let nl = block.outputText.characters.lastIndex(of: "\n") {
                    block.outputText = AttributedString(block.outputText[...nl])
                } else {
                    block.outputText = AttributedString()
                }
                updatePasswordPrompt()
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

    private func updatePasswordPrompt() {
        var active = false
        if let plain = session.blockStore.currentBlock?.plainText {
            // ponytail: naive keyword heuristic; extend patterns if reports come in.
            let line = plain.suffix(256)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .last ?? ""
            active = line.range(
                of: #"(password|passphrase)[^:]*:\s*$"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil
        }
        passwordPromptActive = active
    }

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
