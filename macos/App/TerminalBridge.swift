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

        let (env, integrationDir) = buildEnvironment()
        context.coordinator.integrationDir = integrationDir
        tv.startProcess(executable: shell, args: [], environment: env, execName: nil)
        tv.getTerminal().setCursorStyle(.blinkBar)

        onReady? { [weak tv] text in
            tv?.send(txt: text)
        }

        context.coordinator.fontObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak tv] _ in
            if let tv { Self.applyFont(tv) }
        }

        return tv
    }

    static func dismantleNSView(_ nsView: LocalProcessTerminalView, coordinator: Coordinator) {
        if let observer = coordinator.fontObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        let pid = nsView.process.shellPid
        if pid > 0 {
            kill(-pid, SIGHUP)
            kill(pid, SIGHUP)
        }
        if let dir = coordinator.integrationDir {
            try? FileManager.default.removeItem(at: dir)
        }
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

    private static let staleIntegrationCleanup: Void = {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: fm.temporaryDirectory, includingPropertiesForKeys: nil
        ) else { return }
        for url in items where url.lastPathComponent.hasPrefix("FriendlyTerminalIntegration-") {
            try? fm.removeItem(at: url)
        }
    }()

    private func buildEnvironment() -> (env: [String], dir: URL) {
        _ = Self.staleIntegrationCleanup

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("FriendlyTerminalIntegration-\(UUID().uuidString)")

        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        let bundlePath = Bundle.main.path(forResource: "shell-integration", ofType: "zsh") ?? ""

        let userZdotdir = ProcessInfo.processInfo.environment["ZDOTDIR"]
            ?? ProcessInfo.processInfo.environment["HOME"]
            ?? NSHomeDirectory()

        func shq(_ s: String) -> String {
            "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }

        // Track a user .zshenv that redirects ZDOTDIR (XDG setups), then point
        // ZDOTDIR back at us so our .zshrc still loads.
        let zshenv = """
#!/usr/bin/env zsh
_ft_zdotdir="$ZDOTDIR"
export ZDOTDIR_ORIGINAL=\(shq(userZdotdir))
[[ -f "$ZDOTDIR_ORIGINAL/.zshenv" ]] && source "$ZDOTDIR_ORIGINAL/.zshenv"
[[ -n "$ZDOTDIR" && "$ZDOTDIR" != "$_ft_zdotdir" ]] && export ZDOTDIR_ORIGINAL="$ZDOTDIR"
export ZDOTDIR="$_ft_zdotdir"
unset _ft_zdotdir
"""
        try? zshenv.write(to: tmp.appendingPathComponent(".zshenv"), atomically: true, encoding: .utf8)

        let zshrc = """
#!/usr/bin/env zsh
export ZDOTDIR="$ZDOTDIR_ORIGINAL"
[[ -f "$ZDOTDIR_ORIGINAL/.zshrc" ]] && source "$ZDOTDIR_ORIGINAL/.zshrc"
export FRIENDLYTERMINAL_INTEGRATION=1
[[ -f \(shq(bundlePath)) ]] && source \(shq(bundlePath))
"""
        try? zshrc.write(to: tmp.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

        var env = ProcessInfo.processInfo.environment
        env["ZDOTDIR"] = tmp.path
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"

        return (env.map { "\($0.key)=\($0.value)" }, tmp)
    }

    private func applyAppearance(_ tv: LocalProcessTerminalView) {
        tv.nativeBackgroundColor = NSColor.textBackgroundColor
        tv.nativeForegroundColor = NSColor.textColor
        Self.applyFont(tv)
        tv.caretColor = NSColor.controlAccentColor
    }

    private static func applyFont(_ tv: LocalProcessTerminalView) {
        let defaults = UserDefaults.standard
        let size = CGFloat((defaults.object(forKey: "terminalFontSize") as? Double) ?? 13)
        // "Menlo" matches SettingsView's @AppStorage default so the picker and
        // the rendered font agree before the user ever touches the setting.
        let name = defaults.string(forKey: "terminalFontName") ?? "Menlo"
        let font = NSFont(name: name, size: size)
            ?? .monospacedSystemFont(ofSize: size, weight: .regular)
        if tv.font != font {
            tv.font = font
        }
    }
}

final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
    var onCwdChange: (String) -> Void
    var onTitleChange: (String) -> Void
    var onShellEvent: (ShellIntegrationParser.Event) -> Void
    var onTUIChange: (Bool) -> Void
    var onTerminated: (() -> Void)?
    var integrationDir: URL?
    var fontObserver: NSObjectProtocol?

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
        guard let dir = directory,
              let path = ShellIntegrationParser.decodeFileURL(dir) else { return }
        onCwdChange(path)
        onShellEvent(.cwdUpdate(path))
    }
}
