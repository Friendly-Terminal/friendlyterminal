import SwiftUI

struct AgentControlBarView: View {
    @Environment(SessionState.self) private var session
    @State private var slashMenuExpanded = false

    private var agent: AgentProfile? { session.activeAgent }
    private var checker: AgentInstallChecker {
        .shared(for: session.activeAgent ?? AgentRegistry.claude)
    }

    var body: some View {
        Group {
            if let agent {
                content(for: agent)
            }
        }
        .onAppear { checker.check() }
    }

    private func content(for agent: AgentProfile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(for: agent)
                Divider()
                navigationSection(for: agent)
                Divider()
                controlSection
                Divider()
                slashSection(for: agent)
                Divider()
                exitSection(for: agent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func header(for agent: AgentProfile) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: agent.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(agent.accentHex.flatMap(Color.init(hex:)) ?? Color.accentColor)
                Text(agent.displayName)
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

            if let version = checker.installStatus.version {
                Text(version)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .overlay(alignment: .bottom) {
            if session.agentRunsWithDangerousFlag {
                dangerBanner(for: agent)
            }
        }
    }

    private func dangerBanner(for agent: AgentProfile) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9))
                .foregroundStyle(.orange)
            Text("Auto-approve mode — \(agent.displayName) can act without asking")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.12))
    }

    private func navigationSection(for agent: AgentProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Navigate & select")

            HStack(spacing: 6) {
                agentButton(
                    label: "↑",
                    symbol: "chevron.up",
                    color: .secondary,
                    help: "Up arrow — move selection up"
                ) {
                    session.sendRaw("\u{1B}[A")
                }
                agentButton(
                    label: "↓",
                    symbol: "chevron.down",
                    color: .secondary,
                    help: "Down arrow — move selection down"
                ) {
                    session.sendRaw("\u{1B}[B")
                }
            }

            if agent.supportsNumberedOptions {
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
                        .accessibilityLabel("Select option \(n)")
                    }
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
                agentButton(
                    label: "Enter",
                    symbol: "return",
                    color: .accentColor,
                    help: "Send Enter / submit current input"
                ) {
                    session.sendRaw("\r")
                }

                agentButton(
                    label: "Stop",
                    symbol: "stop.circle.fill",
                    color: .orange,
                    help: "Ctrl+C — interrupt current operation"
                ) {
                    session.sendRaw("\u{03}")
                }

                agentButton(
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

    private func slashSection(for agent: AgentProfile) -> some View {
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
                slashGrid(for: agent)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func slashGrid(for agent: AgentProfile) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
            spacing: 6
        ) {
            ForEach(agent.slashCommands, id: \.label) { cmd in
                Button {
                    session.sendRaw(cmd.sendText)
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

    private func exitSection(for agent: AgentProfile) -> some View {
        VStack(spacing: 4) {
            Button {
                session.sendRaw(agent.exitSendText)
            } label: {
                Label("Exit \(agent.displayName)", systemImage: "power")
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
            .help("End the \(agent.displayName) session")

            Text(agent.exitHint)
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

    private func agentButton(
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
        .accessibilityLabel(help)
    }
}

extension Color {
    init?(hex: String) {
        var value: UInt64 = 0
        guard Scanner(string: String(hex.dropFirst())).scanHexInt64(&value) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

#Preview {
    AgentControlBarView()
        .environment(SessionState())
        .frame(width: 220, height: 420)
}
