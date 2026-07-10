import SwiftUI

struct InteractiveHintView: View {
    @Environment(SessionState.self) private var session

    private var hint: ProgramHint {
        ProgramHint.detect(from: session.blockStore.currentBlock?.command ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: hint.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(hint.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            Text(hint.subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            if !hint.actions.isEmpty {
                VStack(spacing: 6) {
                    ForEach(hint.actions) { action in
                        Button {
                            session.sendRaw(action.sequence)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: action.icon)
                                    .font(.system(size: 11))
                                Text(action.label)
                                    .font(.system(size: 11, weight: .medium))
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill((action.destructive ? Color.orange : Color.accentColor).opacity(0.15))
                            )
                            .foregroundStyle(action.destructive ? Color.orange : Color.accentColor)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                ForEach(hint.keys) { entry in
                    HStack(alignment: .top, spacing: 8) {
                        Text(entry.key)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.6))
                            )
                            .frame(width: 66, alignment: .leading)

                        Text(entry.description)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct ProgramHint {
    struct Key: Identifiable {
        let id = UUID()
        let key: String
        let description: String
    }

    /// A one-tap button that sends the right key sequence so the user doesn't
    /// have to know it (e.g. "Quit" sends `q`, "Save & quit" sends `Esc :wq ↵`).
    struct Action: Identifiable {
        let id = UUID()
        let label: String
        let icon: String
        let sequence: String
        var destructive: Bool = false
    }

    let title: String
    let subtitle: String
    let icon: String
    let keys: [Key]
    let actions: [Action]

    static func detect(from command: String) -> ProgramHint {
        switch primaryProgram(in: command) {
        case "claude":
            return claude
        case "vim", "vi", "nvim", "view":
            return vim
        case "nano", "pico":
            return nano
        case "emacs":
            return emacs
        case "less", "more", "man":
            return pager
        case "top", "htop", "btop":
            return monitor
        case "git":
            return pager
        default:
            return generic
        }
    }

    private static func primaryProgram(in command: String) -> String {
        let lastStage = command.split(separator: "|").last.map(String.init) ?? command
        let tokens = lastStage
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .map(String.init)

        for token in tokens {
            if token.contains("=") { continue }
            if ["sudo", "command", "exec", "time", "env"].contains(token) { continue }
            return (token as NSString).lastPathComponent.lowercased()
        }
        return ""
    }

    static let claude = ProgramHint(
        title: "Claude Code",
        subtitle: "Use the sidebar controls to drive Claude — no typing needed.",
        icon: "sparkles",
        keys: [
            Key(key: "y + ↵", description: "Approve a permission prompt"),
            Key(key: "n + ↵", description: "Reject a permission prompt"),
            Key(key: "Ctrl C", description: "Stop the current operation"),
            Key(key: "/clear", description: "Clear conversation history"),
            Key(key: "/exit", description: "Exit Claude and return to shell"),
        ],
        actions: []
    )

    static let pager = ProgramHint(
        title: "Text viewer",
        subtitle: "You're reading a document.",
        icon: "doc.text.magnifyingglass",
        keys: [
            Key(key: "Space", description: "Scroll down one page"),
            Key(key: "b", description: "Scroll up one page"),
            Key(key: "↑ ↓", description: "Move one line"),
            Key(key: "/", description: "Search for text"),
            Key(key: "q", description: "Quit and go back"),
        ],
        actions: [
            Action(label: "Quit (go back)", icon: "xmark.circle", sequence: "q"),
            Action(label: "Page down", icon: "arrow.down", sequence: " "),
            Action(label: "Page up", icon: "arrow.up", sequence: "b"),
        ]
    )

    static let vim = ProgramHint(
        title: "Vim editor",
        subtitle: "A text editor. Use the buttons to get out:",
        icon: "pencil.and.outline",
        keys: [
            Key(key: "i", description: "Start typing (insert mode)"),
            Key(key: "Esc", description: "Stop typing"),
            Key(key: ":w", description: "Save (then Return)"),
            Key(key: ":q", description: "Quit (then Return)"),
            Key(key: ":wq", description: "Save and quit"),
            Key(key: ":q!", description: "Quit without saving"),
        ],
        actions: [
            Action(label: "Save & quit", icon: "square.and.arrow.down", sequence: "\u{1B}:wq\r"),
            Action(label: "Quit, discard changes", icon: "xmark.circle", sequence: "\u{1B}:q!\r", destructive: true),
        ]
    )

    static let nano = ProgramHint(
        title: "Nano editor",
        subtitle: "A simple text editor.",
        icon: "pencil",
        keys: [
            Key(key: "type", description: "Just type to edit"),
            Key(key: "Ctrl O", description: "Save (then Return)"),
            Key(key: "Ctrl X", description: "Exit"),
            Key(key: "Ctrl K", description: "Cut current line"),
            Key(key: "Ctrl W", description: "Search"),
        ],
        actions: [
            Action(label: "Save & exit", icon: "square.and.arrow.down", sequence: "\u{18}y\r"),
            Action(label: "Exit without saving", icon: "xmark.circle", sequence: "\u{18}n", destructive: true),
        ]
    )

    static let emacs = ProgramHint(
        title: "Emacs editor",
        subtitle: "A text editor.",
        icon: "pencil",
        keys: [
            Key(key: "Ctrl X Ctrl S", description: "Save"),
            Key(key: "Ctrl X Ctrl C", description: "Exit"),
            Key(key: "Ctrl G", description: "Cancel current action"),
        ],
        actions: [
            Action(label: "Save", icon: "square.and.arrow.down", sequence: "\u{18}\u{13}"),
            Action(label: "Exit", icon: "xmark.circle", sequence: "\u{18}\u{03}"),
        ]
    )

    static let monitor = ProgramHint(
        title: "System monitor",
        subtitle: "A live activity view.",
        icon: "gauge.with.dots.needle.67percent",
        keys: [
            Key(key: "q", description: "Quit"),
            Key(key: "Space", description: "Refresh now"),
            Key(key: "↑ ↓", description: "Scroll the list"),
        ],
        actions: [
            Action(label: "Quit", icon: "xmark.circle", sequence: "q"),
        ]
    )

    static let generic = ProgramHint(
        title: "Interactive program",
        subtitle: "This program is reading the keyboard.",
        icon: "keyboard",
        keys: [
            Key(key: "q", description: "Often quits"),
            Key(key: "Ctrl C", description: "Interrupt / stop"),
            Key(key: "Esc", description: "Cancel"),
        ],
        actions: [
            Action(label: "Try to quit", icon: "xmark.circle", sequence: "q"),
            Action(label: "Force stop", icon: "stop.circle", sequence: "\u{03}", destructive: true),
        ]
    )
}

#Preview {
    InteractiveHintView()
        .environment(SessionState())
        .frame(width: 220, height: 280)
}
