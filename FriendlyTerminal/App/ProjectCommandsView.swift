import SwiftUI

struct ProjectCommandsView: View {
    @Environment(SessionState.self) private var session

    private var groups: [ProjectCommandGroup] {
        ProjectCommandDetector.suggestions(cwd: session.cwd, fileItems: session.fileItems)
    }

    var body: some View {
        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader
                groupList
                Divider()
            }
        }
    }

    private var sectionHeader: some View {
        HStack {
            Text("This Project")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var groupList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(groups) { group in
                groupSection(group)
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    private func groupSection(_ group: ProjectCommandGroup) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: group.systemImage)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text(group.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 90, maximum: 180))],
                spacing: 4
            ) {
                ForEach(group.commands) { cmd in
                    commandChip(cmd)
                }
            }
        }
    }

    private func commandChip(_ cmd: ProjectCommand) -> some View {
        Button {
            session.executeCommand(cmd.command)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: cmd.systemImage)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.accentColor)
                Text(cmd.label)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(cmd.command)
    }
}
