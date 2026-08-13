import SwiftUI

struct AgentDoctorView: View {
    @Environment(SessionState.self) private var session
    @Environment(\.dismiss) private var dismiss
    var fixedProfile: AgentProfile? = nil

    private var profile: AgentProfile { fixedProfile ?? session.activeAgent ?? AgentRegistry.claude }
    private var checker: AgentInstallChecker { .shared(for: profile) }
    private var isClaude: Bool { profile.id == AgentRegistry.claude.id }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(profile.displayName) Setup")
                        .font(.headline)
                    Text("Check your \(profile.displayName) installation")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    nodeRow
                    Divider().padding(.leading, 44)
                    installRow
                    Divider().padding(.leading, 44)
                    authRow
                    Divider().padding(.leading, 44)
                    mcpRow
                }
            }

            Divider()

            if isClaude && !checker.installStatus.isInstalled {
                installInstructionsSection
                Divider()
            }

            HStack {
                Button {
                    checker.forceRecheck()
                } label: {
                    Label("Re-check", systemImage: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                if case .checking = checker.installStatus {
                    ProgressView()
                        .scaleEffect(0.65)
                        .padding(.leading, 4)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .frame(width: 400, height: 500)
        .onAppear { checker.check() }
    }

    private var nodeRow: some View {
        DoctorRow(
            icon: "shippingbox.fill",
            title: "Node.js",
            status: nodeStatusText,
            statusColor: nodeStatusColor,
            detail: nodeDetail,
            fixLabel: nodeNeedsInstall ? "Install Node.js" : nil,
            fixAction: nodeNeedsInstall ? {
                session.executeCommand("open https://nodejs.org")
            } : nil
        )
    }

    private var nodeStatusText: String {
        switch checker.nodeStatus {
        case .unknown:          return "Checking…"
        case .notApplicable:    return "Not required"
        case .installed(let v): return v
        case .notInstalled:     return "Not installed"
        }
    }

    private var nodeStatusColor: Color {
        switch checker.nodeStatus {
        case .installed:     return .green
        case .notApplicable: return .secondary
        default:             return .red
        }
    }

    private var nodeDetail: String {
        switch checker.nodeStatus {
        case .notApplicable:
            return "\(profile.displayName) does not require Node.js."
        case .installed:
            return "\(profile.displayName) is built on Node.js. All good."
        default:
            return "Node.js is required by \(profile.displayName)."
        }
    }

    private var nodeNeedsInstall: Bool {
        if case .notInstalled = checker.nodeStatus { return true }
        return false
    }

    private var installRow: some View {
        DoctorRow(
            icon: profile.symbol,
            title: "\(profile.displayName) CLI",
            status: installStatusText,
            statusColor: checker.installStatus.isInstalled ? .green : .red,
            detail: installDetail,
            fixLabel: (isClaude && !checker.installStatus.isInstalled) ? "Install Claude Code" : nil,
            fixAction: (isClaude && !checker.installStatus.isInstalled) ? {
                session.executeCommand("npm install -g @anthropic-ai/claude-code")
                dismiss()
            } : nil
        )
    }

    private var installStatusText: String {
        switch checker.installStatus {
        case .unknown:                    return "Checking…"
        case .checking:                   return "Checking…"
        case .installed(_, let version):  return version ?? "Installed"
        case .notInstalled:               return "Not installed"
        }
    }

    private var installDetail: String {
        switch checker.installStatus {
        case .installed(let path, _):
            return "Found at \(path)"
        case .notInstalled:
            return isClaude
                ? "Run the install command below, then re-check."
                : "Not found on your PATH. Install it, then re-check."
        default:
            return ""
        }
    }

    private var authRow: some View {
        DoctorRow(
            icon: "person.badge.key.fill",
            title: "Authentication",
            status: authStatusText,
            statusColor: authStatusColor,
            detail: authDetail,
            fixLabel: authNeedsSetup ? "Open \(profile.displayName) and run /login" : nil,
            fixAction: authNeedsSetup ? {
                let path = checker.installStatus.path ?? profile.binaryNames.first ?? profile.id
                session.executeCommand(AgentRegistry.shellQuote(path))
                dismiss()
            } : nil
        )
    }

    private var authStatusText: String {
        switch checker.authStatus {
        case .unknown:          return "Unknown"
        case .authenticated:    return "Configured"
        case .notAuthenticated: return "Not set up"
        }
    }

    private var authStatusColor: Color {
        switch checker.authStatus {
        case .unknown:          return .orange
        case .authenticated:    return .green
        case .notAuthenticated: return .red
        }
    }

    private var authDetail: String {
        switch checker.authStatus {
        case .unknown:
            return "Could not verify. Try running \(profile.binaryNames.first ?? profile.id) in the terminal to check."
        case .authenticated:
            return "Credentials found — you're ready to go."
        case .notAuthenticated:
            return isClaude
                ? "Start Claude Code and run /login inside the session to connect your Anthropic account."
                : "No credentials found for \(profile.displayName)."
        }
    }

    private var authNeedsSetup: Bool {
        isClaude && checker.authStatus == .notAuthenticated
    }

    private var mcpRow: some View {
        let (statusText, detail, color) = mcpInfo
        return DoctorRow(
            icon: "puzzlepiece.extension.fill",
            title: "MCP Servers",
            status: statusText,
            statusColor: color,
            detail: detail,
            fixLabel: nil,
            fixAction: nil
        )
    }

    private var mcpInfo: (String, String, Color) {
        switch checker.mcpStatus {
        case .unknown:
            return ("Unknown",
                    "MCP configuration for \(profile.displayName) can't be read from here.",
                    .secondary)
        case .none:
            return ("None configured",
                    "Optional — add MCP servers to give \(profile.displayName) access to databases, GitHub, and more.",
                    .secondary)
        case .configured(let count):
            return ("\(count) server\(count == 1 ? "" : "s")",
                    "MCP servers extend \(profile.displayName) with extra tools.",
                    .green)
        }
    }

    private var installInstructionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Install Claude Code")
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal)
                .padding(.top, 10)

            Text("Run this command in the terminal:")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            HStack(spacing: 8) {
                Text("npm install -g @anthropic-ai/claude-code")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.4))
                    )

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        "npm install -g @anthropic-ai/claude-code",
                        forType: .string
                    )
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Copy install command")

                Button {
                    session.executeCommand("npm install -g @anthropic-ai/claude-code")
                    dismiss()
                } label: {
                    Label("Run", systemImage: "play.fill")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor)
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .help("Run this in the terminal now")
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct DoctorRow: View {
    let icon: String
    let title: String
    let status: String
    let statusColor: Color
    let detail: String
    let fixLabel: String?
    let fixAction: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(statusColor)
                .frame(width: 24)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(status)
                        .font(.system(size: 12))
                        .foregroundStyle(statusColor)
                }
                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let fixLabel, let fixAction {
                    Button(action: fixAction) {
                        Label(fixLabel, systemImage: "wrench.and.screwdriver")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }

            Spacer()

            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .padding(.top, 5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

#Preview {
    AgentDoctorView()
        .environment(SessionState())
}
