import SwiftUI

/// Renders a "list" command's output (e.g. `ls`, `git branch`) as a grid of
/// clickable chips. Tapping a chip drops its follow-up command into the command
/// bar — clicking a folder from `ls` fills in `cd folder`, and so on.
struct CommandListOutputView: View {
    let hint: String
    let items: [CommandListItem]
    let onTap: (CommandListItem) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 130, maximum: 240), spacing: 8, alignment: .leading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(hint)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(items) { item in
                    Button { onTap(item) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.systemImage)
                                .font(.system(size: 12))
                                .foregroundStyle(item.systemImage == "folder.fill"
                                                 ? Color.accentColor : Color.secondary)
                                .frame(width: 16)
                            Text(item.label)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(item.detail.map { "\($0)\n\(item.followUp)" } ?? "Fill in: \(item.followUp)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
