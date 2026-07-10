import SwiftUI

/// A single terminal pane: its own shell session, output blocks, and command
/// bar. When the window is split, each pane shows a header with its folder and
/// a close button, and the focused pane is marked with an accent strip.
struct TerminalPaneView: View {
    let session: SessionState
    @Environment(Workspace.self) private var workspace

    private var isFocused: Bool { workspace.focusedID == session.id }

    var body: some View {
        VStack(spacing: 0) {
            if workspace.isSplit {
                paneHeader
                Divider()
            }

            TerminalContainerView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            NLCommandBarView()
        }
        .environment(session)
        .overlay(alignment: .top) {
            if workspace.isSplit && isFocused {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)
            }
        }
    }

    private var paneHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "terminal")
                .font(.system(size: 10))
                .foregroundStyle(isFocused ? Color.accentColor : .secondary)

            Text(paneTitle)
                .font(.system(size: 11, weight: isFocused ? .semibold : .regular))
                .foregroundStyle(isFocused ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.head)

            Spacer()

            Button {
                workspace.closePane(session.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close this terminal")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isFocused ? Color.accentColor.opacity(0.06) : Color(nsColor: .windowBackgroundColor))
        .contentShape(Rectangle())
        .onTapGesture { workspace.focus(session.id) }
    }

    private var paneTitle: String {
        let name = (session.cwd as NSString).lastPathComponent
        return name.isEmpty ? session.cwd : name
    }
}
