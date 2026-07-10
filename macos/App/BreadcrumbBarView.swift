import SwiftUI

struct BreadcrumbBarView: View {
    @Environment(SessionState.self) private var session
    @Environment(Workspace.self) private var workspace
    @State private var showingDoctorSheet = false
    @State private var showingGitPanel = false
    @State private var showingProcessPanel = false
    private let checker = ClaudeInstallChecker.shared

    var body: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    workspace.sidebarVisible.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Toggle sidebar")

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(Array(session.breadcrumbs.enumerated()), id: \.element.id) { index, crumb in
                            HStack(spacing: 2) {
                                if index > 0 {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.tertiary)
                                }

                                Button(crumb.name) {
                                    session.navigateShellTo(crumb.path)
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 12, weight: index == session.breadcrumbs.count - 1 ? .semibold : .regular))
                                .foregroundStyle(index == session.breadcrumbs.count - 1 ? .primary : .secondary)
                                .id(crumb.id)
                            }
                        }
                    }
                }
                .onChange(of: session.breadcrumbs.last?.id) { _, newID in
                    if let id = newID {
                        withAnimation { proxy.scrollTo(id, anchor: .trailing) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .coachmarkTarget(Coachmark.breadcrumbs)

            if let git = session.gitStatus {
                Divider().frame(height: 14)

                Button {
                    showingGitPanel = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 10, weight: .medium))
                        Text(git.branch)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        if git.isDirty {
                            Text("·\(git.uncommittedCount)")
                                .font(.system(size: 11))
                                .foregroundStyle(.orange)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(git.isDirty
                      ? "\(git.uncommittedCount) uncommitted file(s) — open Source Control"
                      : "Clean working tree — open Source Control")
            }

            claudeButton

            Button {
                showingProcessPanel = true
            } label: {
                Image(systemName: "bolt.horizontal.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("What's running on this machine")

            Button {
                session.refreshFileItems()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Refresh")

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { workspace.addPane() }
            } label: {
                Image(systemName: "plus.rectangle.on.rectangle")
                    .foregroundStyle(workspace.canAddPane ? .secondary : .tertiary)
            }
            .buttonStyle(.plain)
            .disabled(!workspace.canAddPane)
            .help("Add another terminal")
            .coachmarkTarget(Coachmark.addPane)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
        .sheet(isPresented: $showingDoctorSheet) {
            ClaudeDoctorView()
                .environment(session)
        }
        .sheet(isPresented: $showingGitPanel) {
            GitPanelView(path: session.cwd)
                .environment(session)
        }
        .onChange(of: showingGitPanel) { _, open in
            if !open { session.refreshGitStatus() }
        }
        .sheet(isPresented: $showingProcessPanel) {
            ProcessPanelView()
        }
        .onAppear {
            checker.check()
        }
    }

    @ViewBuilder
    private var claudeButton: some View {
        switch checker.claudeStatus {
        case .installed:
            Menu {
                Button {
                    session.executeCommand("claude")
                } label: {
                    Label("New Chat", systemImage: "plus.bubble")
                }

                Button {
                    session.executeCommand("claude --continue")
                } label: {
                    Label("Resume Last Chat", systemImage: "arrow.counterclockwise")
                }

                Button {
                    session.executeCommand("claude --resume")
                } label: {
                    Label("Choose Session…", systemImage: "list.bullet.rectangle")
                }

                Divider()

                Button {
                    showingDoctorSheet = true
                } label: {
                    Label("Setup & Doctor…", systemImage: "stethoscope")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Claude")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                )
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .help("Start a Claude Code session")
            .coachmarkTarget(Coachmark.claudeButton)

        case .notInstalled:
            Button {
                showingDoctorSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Setup Claude")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.4))
                )
            }
            .buttonStyle(.plain)
            .help("Claude Code is not installed — click to set it up")

        case .checking:
            ProgressView()
                .scaleEffect(0.55)
                .frame(width: 24)

        case .unknown:
            EmptyView()
        }
    }
}

#Preview {
    BreadcrumbBarView()
        .environment(SessionState())
        .environment(Workspace())
        .frame(width: 600)
}
