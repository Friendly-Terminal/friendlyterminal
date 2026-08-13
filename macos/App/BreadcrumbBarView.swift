import SwiftUI

struct BreadcrumbBarView: View {
    @Environment(SessionState.self) private var session
    @Environment(Workspace.self) private var workspace
    @State private var showingDoctorSheet = false
    @State private var showingGitPanel = false
    @State private var showingProcessPanel = false
    @State private var doctorProfile: AgentProfile?
    private let checker = AgentInstallChecker.shared

    private var otherProfiles: [AgentProfile] {
        AgentRegistry.all.filter { $0.id != AgentRegistry.claude.id }
    }

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
            .accessibilityLabel("Toggle sidebar")

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
                .accessibilityLabel("Open Source Control — branch \(git.branch)")
            }

            claudeButton

            otherAgentsMenu

            Button {
                showingProcessPanel = true
            } label: {
                Image(systemName: "bolt.horizontal.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("What's running on this machine")
            .accessibilityLabel("What's running on this machine")

            Button {
                session.refreshFileItems()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Refresh")
            .accessibilityLabel("Refresh")

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { workspace.addPane() }
            } label: {
                Image(systemName: "plus.rectangle.on.rectangle")
                    .foregroundStyle(workspace.canAddPane ? .secondary : .tertiary)
            }
            .buttonStyle(.plain)
            .disabled(!workspace.canAddPane)
            .help("Add another terminal")
            .accessibilityLabel("Add another terminal")
            .coachmarkTarget(Coachmark.addPane)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
        .sheet(isPresented: $showingDoctorSheet) {
            AgentDoctorView()
                .environment(session)
        }
        .sheet(item: $doctorProfile) { profile in
            AgentDoctorView(fixedProfile: profile)
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
            for profile in otherProfiles {
                AgentInstallChecker.shared(for: profile).check()
            }
        }
    }

    @ViewBuilder
    private var otherAgentsMenu: some View {
        let installed = otherProfiles.compactMap { profile in
            AgentInstallChecker.shared(for: profile).installStatus.path.map { (profile, $0) }
        }
        if !installed.isEmpty {
            Menu {
                ForEach(installed, id: \.0.id) { profile, path in
                    Menu(profile.displayName) {
                        Button {
                            session.executeCommand(AgentRegistry.shellQuote(path))
                        } label: {
                            Label("Launch", systemImage: "play")
                        }
                        Button {
                            doctorProfile = profile
                        } label: {
                            Label("Setup doctor…", systemImage: "stethoscope")
                        }
                    }
                }
            } label: {
                Image(systemName: "square.grid.2x2")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .help("Other installed AI agents")
            .accessibilityLabel("Other installed AI agents")
        }
    }

    @ViewBuilder
    private var claudeButton: some View {
        switch checker.installStatus {
        case .installed(let installPath, _):
            let launch = AgentRegistry.shellQuote(installPath)
            Menu {
                Button {
                    session.executeCommand(launch)
                } label: {
                    Label("New Chat", systemImage: "plus.bubble")
                }

                Button {
                    session.executeCommand("\(launch) --continue")
                } label: {
                    Label("Resume Last Chat", systemImage: "arrow.counterclockwise")
                }

                Button {
                    session.executeCommand("\(launch) --resume")
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
