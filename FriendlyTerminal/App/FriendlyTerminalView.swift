import AppKit
import SwiftTerm

final class FriendlyTerminalView: LocalProcessTerminalView {

    var onShellEvent: ((ShellIntegrationParser.Event) -> Void)?
    var onFocusRequested: (() -> Void)?
    var isActivePane: Bool = true

    private let oscStream = ShellIntegrationParser.Stream()

    var interactiveMode: Bool = false {
        didSet {
            guard interactiveMode != oldValue else { return }
            if interactiveMode { installInputMonitor() } else { removeInputMonitor() }
        }
    }

    private var altScreenActive = false
    private var inputMonitor: Any?
    private var scrollAccumulator: CGFloat = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupClickRecognizer()
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    deinit { removeInputMonitor() }

    override func dataReceived(slice: ArraySlice<UInt8>) {
        let events = oscStream.feed(slice)
        for event in events {
            if case .altScreen(let on) = event { altScreenActive = on }
            onShellEvent?(event)
        }
        super.dataReceived(slice: slice)
    }

    private func installInputMonitor() {
        window?.makeFirstResponder(self)
        guard inputMonitor == nil else { return }
        inputMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .scrollWheel]) { [weak self] event in
            guard let self, self.interactiveMode, event.window === self.window else { return event }

            if event.type == .scrollWheel {
                return self.handleAltScreenScroll(event) ? nil : event
            }

            guard self.isActivePane else { return event }

            if self.window?.firstResponder !== self {
                self.window?.makeFirstResponder(self)
            }

            if event.modifierFlags.contains(.command) { return event }

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

    private func handleAltScreenScroll(_ event: NSEvent) -> Bool {
        let local = convert(event.locationInWindow, from: nil)
        guard bounds.contains(local) else { return false }

        let lineHeight = max(font.boundingRectForFont.height, 1)
        let threshold = event.hasPreciseScrollingDeltas ? lineHeight : 1
        scrollAccumulator += event.scrollingDeltaY

        let lines = Int(scrollAccumulator / threshold)
        guard lines != 0 else { return true }
        scrollAccumulator -= CGFloat(lines) * threshold

        let app = altScreenActive || getTerminal().applicationCursor
        let up = app ? "\u{1B}OA" : "\u{1B}[A"
        let down = app ? "\u{1B}OB" : "\u{1B}[B"
        let count = min(abs(lines), 100)
        send(txt: String(repeating: lines > 0 ? up : down, count: count))
        return true
    }

    private func terminalSequence(for event: NSEvent) -> String? {
        let esc = "\u{1B}"
        let app = altScreenActive || getTerminal().applicationCursor
        switch event.keyCode {
        case 126: return app ? esc + "OA" : esc + "[A"
        case 125: return app ? esc + "OB" : esc + "[B"
        case 124: return app ? esc + "OC" : esc + "[C"
        case 123: return app ? esc + "OD" : esc + "[D"
        case 116: return esc + "[5~"
        case 121: return esc + "[6~"
        case 115: return app ? esc + "OH" : esc + "[H"
        case 119: return app ? esc + "OF" : esc + "[F"
        case 117: return esc + "[3~"
        default:  return nil
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard
            .readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        guard let urls, !urls.isEmpty else { return false }
        let text = urls.map { url -> String in
            let p = url.path
            return p.contains(" ") ? "'\(p.replacingOccurrences(of: "'", with: "'\\''"))'" : p
        }.joined(separator: " ")
        send(txt: text)
        return true
    }

    private func setupClickRecognizer() {
        let recognizer = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        recognizer.numberOfClicksRequired = 1
        recognizer.delaysPrimaryMouseButtonEvents = false
        addGestureRecognizer(recognizer)
    }

    @objc private func handleClick(_ recognizer: NSClickGestureRecognizer) {
        if interactiveMode {
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
