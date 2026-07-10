import SwiftUI

struct ClaudeControlBarView: View {
    @Environment(SessionState.self) private var session
    @State private var slashMenuExpanded = false

    private var checker: ClaudeInstallChecker { .shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
                navigationSection
                Divider()
                controlSection
                Divider()
                slashSection
                Divider()
                exitSection
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Claude Code")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Running")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            if let version = checker.claudeStatus.version {
                Text(version)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .overlay(alignment: .bottom) {
            if session.claudeRunsWithDangerousFlag {
                dangerBanner
            }
        }
    }

    private var dangerBanner: some View {
        HStack(spacing: 5) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9))
                .foregroundStyle(.orange)
            Text("Auto-approve mode — Claude can act without asking")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.12))
    }

    private var navigationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Navigate & select")

            HStack(spacing: 6) {
                claudeButton(
                    label: "↑",
                    symbol: "chevron.up",
                    color: .secondary,
                    help: "Up arrow — move selection up"
                ) {
                    session.sendRaw("\u{1B}[A")
                }
                claudeButton(
                    label: "↓",
                    symbol: "chevron.down",
                    color: .secondary,
                    help: "Down arrow — move selection down"
                ) {
                    session.sendRaw("\u{1B}[B")
                }
            }

            HStack(spacing: 6) {
                ForEach(1...4, id: \.self) { n in
                    Button {
                        session.sendRaw("\(n)\r")
                    } label: {
                        Text("\(n)")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Select option \(n)")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var controlSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Controls")

            HStack(spacing: 8) {
                claudeButton(
                    label: "Enter",
                    symbol: "return",
                    color: .accentColor,
                    help: "Send Enter / submit current input"
                ) {
                    session.sendRaw("\r")
                }

                claudeButton(
                    label: "Stop",
                    symbol: "stop.circle.fill",
                    color: .orange,
                    help: "Ctrl+C — interrupt current operation"
                ) {
                    session.sendRaw("\u{03}")
                }

                claudeButton(
                    label: "Esc",
                    symbol: "escape",
                    color: .secondary,
                    help: "Escape — cancel / back"
                ) {
                    session.sendRaw("\u{1B}")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var slashSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    slashMenuExpanded.toggle()
                }
            } label: {
                HStack {
                    sectionLabel("Slash commands")
                    Spacer()
                    Image(systemName: slashMenuExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if slashMenuExpanded {
                slashGrid
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var slashGrid: some View {
        let commands: [(label: String, command: String, help: String)] = [
            ("/clear",   "/clear\r",   "Clear the conversation history"),
            ("/compact", "/compact\r", "Compact context to save tokens"),
            ("/help",    "/help\r",    "Show Claude's built-in help"),
            ("/init",    "/init\r",    "Create a CLAUDE.md for this project"),
            ("/model",   "/model\r",   "Switch the model"),
            ("/resume",  "/resume\r",  "Resume a previous conversation"),
        ]
        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
            spacing: 6
        ) {
            ForEach(commands, id: \.label) { cmd in
                Button {
                    session.sendRaw(cmd.command)
                } label: {
                    Text(cmd.label)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.accentColor.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help(cmd.help)
            }
        }
    }

    private var exitSection: some View {
        VStack(spacing: 4) {
            Button {
                session.sendRaw("/exit\r")
            } label: {
                Label("Exit Claude", systemImage: "power")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.35))
                    )
            }
            .buttonStyle(.plain)
            .help("Send /exit — end the Claude session")

            Text("or press Ctrl+C twice")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func claudeButton(
        label: String,
        symbol: String,
        color: Color,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
            )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

#Preview {
    ClaudeControlBarView()
        .environment(SessionState())
        .frame(width: 220, height: 420)
}
