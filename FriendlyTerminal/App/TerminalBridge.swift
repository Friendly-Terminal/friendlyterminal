import AppKit
import SwiftUI
import SwiftTerm

struct TerminalBridge: NSViewRepresentable {
    var onCwdChange: (String) -> Void
    var onTitleChange: (String) -> Void
    var onShellEvent: (ShellIntegrationParser.Event) -> Void
    var onTUIChange: (Bool) -> Void
    var isTUIActive: Bool = false
    var isFocusedPane: Bool = true
    var onTerminated: (() -> Void)?
    var onFocusRequested: (() -> Void)?
    var onReady: ((@escaping (String) -> Void) -> Void)?

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let tv = FriendlyTerminalView(frame: .zero)
        tv.processDelegate = context.coordinator
        tv.onShellEvent = onShellEvent
        tv.onFocusRequested = onFocusRequested
        tv.isActivePane = isFocusedPane
        tv.interactiveMode = isTUIActive
        applyAppearance(tv)

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        let env = buildEnvironment()
        tv.startProcess(executable: shell, args: [], environment: env, execName: nil)
        tv.getTerminal().setCursorStyle(.blinkBar)

        onReady? { [weak tv] text in
            tv?.send(txt: text)
        }

        return tv
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        applyAppearance(nsView)
        (nsView as? FriendlyTerminalView)?.onShellEvent = onShellEvent
        (nsView as? FriendlyTerminalView)?.onFocusRequested = onFocusRequested
        (nsView as? FriendlyTerminalView)?.isActivePane = isFocusedPane
        (nsView as? FriendlyTerminalView)?.interactiveMode = isTUIActive
        context.coordinator.onCwdChange = onCwdChange
        context.coordinator.onTitleChange = onTitleChange
        context.coordinator.onShellEvent = onShellEvent
        context.coordinator.onTUIChange = onTUIChange
        context.coordinator.onTerminated = onTerminated

        // When an interactive program takes over, hand it keyboard focus — but
        // only for the focused pane, so it doesn't steal typing from the other
        // pane in a split window.
        if isTUIActive && isFocusedPane {
            DispatchQueue.main.async { [weak nsView] in
                guard let nsView, nsView.window?.firstResponder !== nsView else { return }
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onCwdChange: onCwdChange,
            onTitleChange: onTitleChange,
            onShellEvent: onShellEvent,
            onTUIChange: onTUIChange
        )
    }

    private func buildEnvironment() -> [String] {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("FriendlyTerminalIntegration-\(UUID().uuidString)")

        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        let bundlePath = Bundle.main.path(forResource: "shell-integration", ofType: "zsh") ?? ""

        let userZdotdir = ProcessInfo.processInfo.environment["ZDOTDIR"]
            ?? ProcessInfo.processInfo.environment["HOME"]
            ?? NSHomeDirectory()

        let zshrc = """
#!/usr/bin/env zsh
export ZDOTDIR_ORIGINAL="\(userZdotdir)"
[[ -f "$ZDOTDIR_ORIGINAL/.zshrc" ]] && source "$ZDOTDIR_ORIGINAL/.zshrc"
export FRIENDLYTERMINAL_INTEGRATION=1
[[ -f "\(bundlePath)" ]] && source "\(bundlePath)"
"""
        try? zshrc.write(to: tmp.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

        var env = ProcessInfo.processInfo.environment
        env["ZDOTDIR"] = tmp.path
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"

        return env.map { "\($0.key)=\($0.value)" }
    }

    private func applyAppearance(_ tv: LocalProcessTerminalView) {
        tv.nativeBackgroundColor = NSColor.textBackgroundColor
        tv.nativeForegroundColor = NSColor.textColor
        tv.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.caretColor = NSColor.controlAccentColor
    }
}

final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
    var onCwdChange: (String) -> Void
    var onTitleChange: (String) -> Void
    var onShellEvent: (ShellIntegrationParser.Event) -> Void
    var onTUIChange: (Bool) -> Void
    var onTerminated: (() -> Void)?

    init(
        onCwdChange: @escaping (String) -> Void,
        onTitleChange: @escaping (String) -> Void,
        onShellEvent: @escaping (ShellIntegrationParser.Event) -> Void,
        onTUIChange: @escaping (Bool) -> Void
    ) {
        self.onCwdChange = onCwdChange
        self.onTitleChange = onTitleChange
        self.onShellEvent = onShellEvent
        self.onTUIChange = onTUIChange
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        // Let the workspace decide: close just this pane, or quit if it's the last.
        if let onTerminated {
            onTerminated()
        } else {
            NSApplication.shared.terminate(nil)
        }
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        onTitleChange(title)
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        guard let dir = directory else { return }
        let path: String
        if let url = URL(string: dir), url.isFileURL {
            path = url.path
        } else {
            path = dir
        }
        onCwdChange(path)
        onShellEvent(.cwdUpdate(path))
    }
}
