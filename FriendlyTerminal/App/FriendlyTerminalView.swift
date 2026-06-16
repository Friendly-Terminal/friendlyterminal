import AppKit
import SwiftTerm

final class FriendlyTerminalView: LocalProcessTerminalView {

    /// Invoked for every shell-integration event parsed out of the PTY stream.
    var onShellEvent: ((ShellIntegrationParser.Event) -> Void)?

    /// Invoked when this pane should become the focused one (e.g. clicked).
    var onFocusRequested: (() -> Void)?

    /// Whether this pane is the focused one. The key monitor only routes input
    /// (and grabs focus) for the active pane, so a split window's two terminals
    /// don't fight over the keyboard.
    var isActivePane: Bool = true

    private let oscStream = ShellIntegrationParser.Stream()

    /// Whether the foreground program wants raw keyboard input — set by the
    /// container (alt-screen programs, or raw-mode ones like Claude Code).
    /// Drives the key/scroll monitor.
    var interactiveMode: Bool = false {
        didSet {
            guard interactiveMode != oldValue else { return }
            if interactiveMode { installInputMonitor() } else { removeInputMonitor() }
        }
    }

    /// Tracks the actual alternate-screen / app-cursor state, used only to pick
    /// the right arrow-key escape form.
    private var altScreenActive = false

    private var inputMonitor: Any?
    private var scrollAccumulator: CGFloat = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupClickRecognizer()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    deinit { removeInputMonitor() }

    override func dataReceived(slice: ArraySlice<UInt8>) {
        // Intercept the raw stream to extract command blocks and output, then
        // hand the untouched bytes to the emulator so it still renders correctly.
        let events = oscStream.feed(slice)
        for event in events {
            if case .altScreen(let on) = event { altScreenActive = on }
            onShellEvent?(event)
        }
        super.dataReceived(slice: slice)
    }

    // While a full-screen program owns the screen, SwiftUI tries to consume
    // arrow keys for focus movement before they reach the emulator, and the
    // alternate screen has no scrollback for the wheel to act on. Intercept
    // both here: route navigation keys to the program, and translate scroll
    // gestures into the program's own line-scroll arrows.
    private func installInputMonitor() {
        window?.makeFirstResponder(self)
        guard inputMonitor == nil else { return }
        inputMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .scrollWheel]) { [weak self] event in
            guard let self, self.interactiveMode, event.window === self.window else { return event }

            if event.type == .scrollWheel {
                return self.handleAltScreenScroll(event) ? nil : event
            }

            // Application-wide monitor: in a split window only the focused pane's
            // program should receive keys, so ignore events for the other pane.
            guard self.isActivePane else { return event }

            // Make sure keystrokes land in this terminal (not a lingering command
            // bar), so the program — including prompts like Claude Code's — is
            // actually interactive.
            if self.window?.firstResponder !== self {
                self.window?.makeFirstResponder(self)
            }

            // Leave ⌘-shortcuts to the menu bar (Quit, Copy, etc.).
            if event.modifierFlags.contains(.command) { return event }

            // Translate navigation keys to terminal sequences and write them to
            // the shell ourselves; everything else (text, Return, Esc, Tab…)
            // passes through to this now-focused terminal.
            if let seq = self.terminalSequence(for: event) {
                self.send(txt: seq)
                return nil
            }
            return event
        }
    }

    private func removeInputMonitor() {
        if let inputMonitor { NSEvent.removeMonitor(inputMonitor) }
        inputMonitor = nil
        scrollAccumulator = 0
    }

    /// Converts a scroll gesture over the terminal into line-scroll arrows for
    /// the foreground program. Returns true if it was handled (and consumed).
    private func handleAltScreenScroll(_ event: NSEvent) -> Bool {
        // Only act when the pointer is actually over the terminal, so scrolling
        // the sidebar / hint panel keeps working normally.
        let local = convert(event.locationInWindow, from: nil)
        guard bounds.contains(local) else { return false }

        // A trackpad reports many small precise deltas; accumulate them so one
        // line of travel maps to one arrow. A mouse wheel reports coarse notches.
        let lineHeight = max(font.boundingRectForFont.height, 1)
        let threshold = event.hasPreciseScrollingDeltas ? lineHeight : 1
        scrollAccumulator += event.scrollingDeltaY

        let lines = Int(scrollAccumulator / threshold)
        guard lines != 0 else { return true }
        scrollAccumulator -= CGFloat(lines) * threshold

        // Positive delta means scrolling toward earlier content (up arrow). Use
        // the application-cursor form only when the program expects it.
        let app = altScreenActive || getTerminal().applicationCursor
        let up = app ? "\u{1B}OA" : "\u{1B}[A"
        let down = app ? "\u{1B}OB" : "\u{1B}[B"
        let count = min(abs(lines), 100)
        send(txt: String(repeating: lines > 0 ? up : down, count: count))
        return true
    }

    /// Maps the special navigation keys to their xterm escape sequences.
    /// Full-screen programs (less, vim, nano, htop…) enable application-cursor
    /// mode and bind the arrows to the ESC O form, so use that whenever a TUI
    /// owns the screen; otherwise honor the emulator's tracked mode.
    private func terminalSequence(for event: NSEvent) -> String? {
        let esc = "\u{1B}"
        let app = altScreenActive || getTerminal().applicationCursor
        switch event.keyCode {
        case 126: return app ? esc + "OA" : esc + "[A"   // up
        case 125: return app ? esc + "OB" : esc + "[B"   // down
        case 124: return app ? esc + "OC" : esc + "[C"   // right
        case 123: return app ? esc + "OD" : esc + "[D"   // left
        case 116: return esc + "[5~"                      // page up
        case 121: return esc + "[6~"                      // page down
        case 115: return app ? esc + "OH" : esc + "[H"    // home
        case 119: return app ? esc + "OF" : esc + "[F"    // end
        case 117: return esc + "[3~"                      // forward delete
        default:  return nil
        }
    }

    private func setupClickRecognizer() {
        let recognizer = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        recognizer.numberOfClicksRequired = 1
        recognizer.delaysPrimaryMouseButtonEvents = false
        addGestureRecognizer(recognizer)
    }

    @objc private func handleClick(_ recognizer: NSClickGestureRecognizer) {
        if interactiveMode {
            // A click on an interactive program means "work in this pane": take
            // keyboard focus instead of injecting cursor-movement arrows.
            window?.makeFirstResponder(self)
            onFocusRequested?()
            return
        }
        let point = recognizer.location(in: self)
        moveReadlineCursorTo(clickPoint: point)
    }

    private func moveReadlineCursorTo(clickPoint: NSPoint) {
        let charWidth = computeCharWidth()
        guard charWidth > 0 else { return }

        let targetCol = max(0, Int(clickPoint.x / charWidth))

        let terminal = getTerminal()
        let currentCol = terminal.buffer.x

        let delta = targetCol - currentCol
        guard delta != 0 else { return }

        let arrowSeq = delta > 0 ? "\u{1B}[C" : "\u{1B}[D"
        let count = min(abs(delta), 500)
        send(txt: String(repeating: arrowSeq, count: count))
    }

    private func computeCharWidth() -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: self.font as Any]
        let width = ("M" as NSString).size(withAttributes: attrs).width
        return width > 0 ? width : 8.0
    }
}
