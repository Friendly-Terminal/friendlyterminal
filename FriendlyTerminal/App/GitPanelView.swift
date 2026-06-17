import SwiftUI

/// A small "GitHub Desktop"-style panel: see the current branch, check off files
/// to stage, write a message, and commit — then push. Opened from the branch
/// chip in the breadcrumb bar.
struct GitPanelView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionState.self) private var session
    @State private var panel: GitPanel

    init(path: String) {
        _panel = State(initialValue: GitPanel(path: path))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if !panel.isRepo {
                notARepo
            } else {
                changesList
                Divider()
                commitArea
            }
        }
        .frame(width: 440, height: 540)
        .onAppear { panel.refresh() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text("Source Control")
                    .font(.headline)
                if panel.isRepo {
                    Text(panel.branch)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if panel.isBusy { ProgressView().scaleEffect(0.6) }
            Button {
                panel.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh")
            Button("Done") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding()
    }

    private var notARepo: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 26))
                .foregroundStyle(.tertiary)
            Text("This folder isn't a Git repository.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Button("Start tracking with Git") {
                session.executeCommand("git init")
                dismiss()
            }
            .font(.system(size: 12))
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var changesList: some View {
        if panel.changes.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 26))
                    .foregroundStyle(.green)
                Text("Nothing to commit — working tree clean.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                HStack {
                    Text("\(panel.changes.count) changed · \(panel.stagedCount) staged")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(panel.stagedCount == panel.changes.count ? "Unstage all" : "Stage all") {
                        if panel.stagedCount == panel.changes.count { panel.unstageAll() }
                        else { panel.stageAll() }
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(panel.changes) { change in
                            changeRow(change)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private func changeRow(_ change: GitFileChange) -> some View {
        Button {
            panel.toggleStage(change)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: change.isStaged ? "checkmark.square.fill" : "square")
                    .foregroundStyle(change.isStaged ? Color.accentColor : Color.secondary)
                Image(systemName: change.systemImage)
                    .font(.system(size: 11))
                    .foregroundStyle(color(for: change))
                    .frame(width: 14)
                Text(change.path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 6)
                Text(change.statusLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(color(for: change))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.25))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(change.isStaged ? "Staged — click to unstage" : "Click to stage")
    }

    private func color(for change: GitFileChange) -> Color {
        switch change.statusLabel {
        case "New", "Added": return .green
        case "Deleted":      return .red
        case "Conflict":     return .orange
        default:             return .secondary
        }
    }

    private var commitArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Commit message", text: $panel.commitMessage, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .lineLimit(1...4)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
                )

            HStack(spacing: 8) {
                Button {
                    panel.commit()
                } label: {
                    Text(panel.stagedCount > 0 ? "Commit \(panel.stagedCount) file\(panel.stagedCount == 1 ? "" : "s")" : "Commit")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(panel.canCommit ? Color.accentColor : Color(nsColor: .quaternaryLabelColor))
                        )
                        .foregroundStyle(panel.canCommit ? Color.white : Color.secondary)
                }
                .buttonStyle(.plain)
                .disabled(!panel.canCommit)

                Button {
                    session.executeCommand("git push")
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                        Text(panel.ahead > 0 ? "Push \(panel.ahead)" : "Push")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.5))
                    )
                }
                .buttonStyle(.plain)
                .help("Push commits to the remote (runs in the terminal so you can sign in if needed)")
            }
        }
        .padding(14)
    }
}
