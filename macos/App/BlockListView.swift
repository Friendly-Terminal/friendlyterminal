import SwiftUI

struct BlockListView: View {
    @Environment(SessionState.self) private var session

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(session.blockStore.visibleBlocks) { block in
                        BlockView(block: block)
                            .id(block.id)
                            .padding(.horizontal, 12)
                    }

                    if session.blockStore.currentBlock != nil {
                        HStack(spacing: 8) {
                            RunningIndicatorView()
                            Button {
                                session.sendRaw("\u{03}")
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 9))
                                    Text("Stop")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Stop this command (sends Ctrl-C)")
                            Spacer()
                        }
                        .id("running-indicator")
                        .padding(.horizontal, 12)
                    }

                    Color.clear.frame(height: 16)
                        .id("bottom-anchor")
                }
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onChange(of: session.blockStore.visibleBlocks.count) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottom-anchor", anchor: .bottom)
                }
            }
            .onChange(of: session.blockStore.currentBlock?.plainText) { _, _ in
                proxy.scrollTo("bottom-anchor", anchor: .bottom)
            }
        }
    }
}

private struct RunningIndicatorView: View {
    @State private var dotCount: Int = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 5, height: 5)
                    .opacity(dotCount == i ? 1 : 0.3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                dotCount = (dotCount + 1) % 3
            }
        }
    }
}

struct BlockView: View {
    var block: CommandBlock
    @Environment(SessionState.self) private var session
    @State private var isExpanded: Bool = true
    @State private var showingDeleteConfirm: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            commandHeader

            if isExpanded {
                outputArea
                    .transition(.opacity.combined(with: .move(edge: .top)))

                if block.failed {
                    aiActionsBar
                        .transition(.opacity)
                }

                if block.undoPlan != nil {
                    undoBar
                        .transition(.opacity)
                }
            }

            Divider()
                .opacity(0.5)
        }
        .contextMenu { blockContextMenu }
        .animation(.easeInOut(duration: 0.15), value: isExpanded)
    }

    private var commandHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)

            Text(">")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)

            Text(block.command.isEmpty ? "(no command)" : block.command)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            exitCodeBadge

            if !block.command.isEmpty {
                Button {
                    session.executeCommand(block.command)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Re-run this command")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(headerBackground)
    }

    private var headerBackground: some View {
        Group {
            if block.failed {
                Color.red.opacity(0.06)
            } else if block.succeeded {
                Color.clear
            } else {
                Color.accentColor.opacity(0.04)
            }
        }
    }

    @ViewBuilder
    private var exitCodeBadge: some View {
        if let code = block.exitCode {
            if code == 0 {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.green)
            } else {
                Text("Exit \(code)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red.opacity(0.8))
                    )
            }
        } else {
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 16, height: 16)
        }
    }

    @ViewBuilder
    private var outputArea: some View {
        if block.plainText.isEmpty && block.isRunning {
            EmptyView()
        } else {
            switch block.renderKind {
            case .plainText, .errorHighlighted:
                plainTextOutput

            case .table(let rows):
                TableOutputView(rows: rows)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)

            case .csvTable(let rows):
                CSVTableView(rows: rows)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)

            case .jsonTree:
                JSONTreeView(text: block.plainText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)

            case .commandList(let hint, let items):
                CommandListOutputView(hint: hint, items: items) { item in
                    session.prefillCommand(item.followUp)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

            case .imageFile(let url):
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView()
                }
                .frame(maxHeight: 400)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

            case .imageData(let data):
                if let img = NSImage(data: data) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 400)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                } else {
                    plainTextOutput
                }
            }
        }
    }

    @ViewBuilder
    private var undoBar: some View {
        if let plan = block.undoPlan {
            HStack(spacing: 6) {
                if block.isUndone {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("Undone")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        session.performUndo(block)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                            Text(plan.label)
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Reverse this command")
                }
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 5)
        }
    }

    private var plainTextOutput: some View {
        Text(linkifiedText(block.plainText))
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .padding(.horizontal, 28)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func linkifiedText(_ text: String) -> AttributedString {
        var attr = AttributedString(text)
        guard text.contains("http"),
              let detector = try? NSDataDetector(
                types: NSTextCheckingResult.CheckingType.link.rawValue
              ) else { return attr }
        let nsRange = NSRange(text.startIndex..., in: text)
        for match in detector.matches(in: text, range: nsRange) {
            guard let url = match.url,
                  let stringRange = Range(match.range, in: text),
                  let attrRange = Range(stringRange, in: attr) else { continue }
            attr[attrRange].link = url
        }
        return attr
    }

    @ViewBuilder
    private var aiActionsBar: some View {
        switch block.aiState {
        case .idle:
            HStack(spacing: 8) {
                Button("Explain error") {
                    AIManager.shared.explainError(for: block)
                }
                .buttonStyle(FriendlyButtonStyle(color: .secondary))

                Button("Fix it") {
                    AIManager.shared.suggestFix(for: block)
                }
                .buttonStyle(FriendlyButtonStyle(color: .accentColor))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 8)

        case .fetchingExplanation:
            HStack {
                ProgressView().scaleEffect(0.6)
                Text("Explaining…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 8)

        case .explanation(let text):
            VStack(alignment: .leading, spacing: 6) {
                Label("Explanation", systemImage: "lightbulb")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)

                Button("Fix it") {
                }
                .buttonStyle(FriendlyButtonStyle(color: .accentColor))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 8)

        case .fix(let fix):
            CommandApprovalChip(
                command: fix.fixedCommand,
                explanation: fix.why,
                isDangerous: fix.isDangerous
            ) {
                session.executeCommand(fix.fixedCommand)
                block.aiState = .idle
            } onReject: {
                block.aiState = .idle
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 8)

        case .unavailable:
            Label("Apple Intelligence not available on this device.", systemImage: "exclamationmark.triangle")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 28)
                .padding(.bottom, 8)

        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var blockContextMenu: some View {
        Button("Copy command") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(block.command, forType: .string)
        }

        Button("Copy output") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(block.plainText, forType: .string)
        }

        if !block.command.isEmpty {
            Button("Re-run") {
                session.executeCommand(block.command)
            }
        }

        Divider()

        Button("Explain") {
        }

        Button("Fix it") {
        }
        .disabled(block.succeeded)
    }
}

private struct TableOutputView: View {
    let rows: [[String]]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let header = rows.first {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(header.enumerated()), id: \.offset) { _, cell in
                        Text(cell)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .frame(minWidth: 80, alignment: .leading)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                Divider().padding(.vertical, 2)
            }

            ForEach(Array(rows.dropFirst().enumerated()), id: \.offset) { index, row in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        Text(cell)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(minWidth: 80, alignment: .leading)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    index.isMultiple(of: 2)
                        ? Color.clear
                        : Color(nsColor: .controlBackgroundColor).opacity(0.4)
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        )
    }
}

private struct CSVTableView: View {
    let rows: [[String]]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let header = rows.first {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(header.enumerated()), id: \.offset) { _, cell in
                        Text(cell)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .frame(minWidth: 100, alignment: .leading)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                Divider().padding(.vertical, 2)
            }

            ForEach(Array(rows.dropFirst().enumerated()), id: \.offset) { index, row in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        Text(cell)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(minWidth: 100, alignment: .leading)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(index.isMultiple(of: 2) ? Color.clear : Color(nsColor: .controlBackgroundColor).opacity(0.4))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        )
    }
}

struct CommandApprovalChip: View {
    let command: String
    let explanation: String
    let isDangerous: Bool
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: isDangerous ? "exclamationmark.triangle.fill" : "sparkles")
                    .foregroundStyle(isDangerous ? .orange : .accentColor)
                Text("Suggested fix")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text(explanation)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text(command)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .stroke(isDangerous ? Color.orange.opacity(0.5) : Color.accentColor.opacity(0.3))
                    )
                    .textSelection(.enabled)

                Spacer()

                Button("Reject") { onReject() }
                    .buttonStyle(FriendlyButtonStyle(color: .secondary))

                Button(isDangerous ? "Run anyway" : "Run") { onApprove() }
                    .buttonStyle(FriendlyButtonStyle(color: isDangerous ? .orange : .accentColor))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .stroke(isDangerous ? Color.orange.opacity(0.3) : Color.accentColor.opacity(0.2))
        )
    }
}

struct FriendlyButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(color == .secondary ? Color.secondary : Color.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color == .secondary ? Color(nsColor: .controlBackgroundColor) : color)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

private struct JSONTreeView: View {
    let text: String

    private var root: JSONNode? {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return JSONNode(value: obj)
    }

    var body: some View {
        if let root {
            ScrollView {
                JSONNodeView(node: root, key: nil)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .frame(maxHeight: 420)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
            )
        } else {
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct JSONPair: Identifiable {
    let key: String
    let value: JSONNode
    var id: String { key }
}

private indirect enum JSONNode {
    case object([JSONPair])
    case array([JSONNode])
    case string(String)
    case number(Double, isInteger: Bool)
    case bool(Bool)
    case null

    init(value: Any) {
        if let dict = value as? [String: Any] {
            self = .object(
                dict.map { JSONPair(key: $0.key, value: JSONNode(value: $0.value)) }
                    .sorted { $0.key < $1.key }
            )
        } else if let arr = value as? [Any] {
            self = .array(arr.map { JSONNode(value: $0) })
        } else if let s = value as? String {
            self = .string(s)
        } else if let n = value as? NSNumber {
            let type = String(cString: n.objCType)
            if type == "c" {
                self = .bool(n.boolValue)
            } else {
                let d = n.doubleValue
                self = .number(d, isInteger: d == d.rounded() && abs(d) < 1e15)
            }
        } else {
            self = .null
        }
    }
}

private struct JSONNodeView: View {
    let node: JSONNode
    let key: String?
    @State private var expanded: Bool = true

    var body: some View {
        switch node {
        case .object(let pairs):
            DisclosureGroup(isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(pairs.prefix(200)) { pair in
                        JSONNodeView(node: pair.value, key: pair.key)
                    }
                    if pairs.count > 200 {
                        Text("… \(pairs.count - 200) more")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 2)
                    }
                }
                .padding(.leading, 14)
            } label: {
                containerLabel(suffix: "{ \(pairs.count) }")
            }

        case .array(let items):
            DisclosureGroup(isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(items.prefix(200).enumerated()), id: \.offset) { i, item in
                        JSONNodeView(node: item, key: "[\(i)]")
                    }
                    if items.count > 200 {
                        Text("… \(items.count - 200) more")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 2)
                    }
                }
                .padding(.leading, 14)
            } label: {
                containerLabel(suffix: "[ \(items.count) ]")
            }

        case .string(let s):
            leafRow(value: "\"\(s)\"", color: .green)

        case .number(let d, let isInt):
            leafRow(value: isInt ? "\(Int(d))" : String(format: "%g", d), color: .blue)

        case .bool(let b):
            leafRow(value: b ? "true" : "false", color: .orange)

        case .null:
            leafRow(value: "null", color: .secondary)
        }
    }

    private func containerLabel(suffix: String) -> some View {
        HStack(spacing: 4) {
            if let key {
                Text(key.hasPrefix("[") ? "\(key):" : "\"\(key)\":")
                    .foregroundStyle(key.hasPrefix("[") ? .secondary : .primary)
            }
            Text(suffix)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 12, design: .monospaced))
    }

    private func leafRow(value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            if let key {
                Text(key.hasPrefix("[") ? "\(key):" : "\"\(key)\":")
                    .foregroundStyle(key.hasPrefix("[") ? .secondary : .primary)
            }
            Text(value)
                .foregroundStyle(color)
                .lineLimit(3)
        }
        .font(.system(size: 12, design: .monospaced))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 1)
    }
}

#if DEBUG
@MainActor
private func blockListPreviewSession() -> SessionState {
    let session = SessionState()
    let block = CommandBlock(command: "ls -la", cwd: "/Users/test", sessionID: UUID())
    block.plainText = "total 48\ndrwxr-xr-x  12 user  staff   384 Jun 13 10:00 .\ndrwxr-xr-x  15 user  staff   480 Jun 12 09:00 .."
    block.exitCode = 0
    session.blockStore.appendForPreview(block)

    let failBlock = CommandBlock(command: "cat /nope", cwd: "/Users/test", sessionID: UUID())
    failBlock.plainText = "cat: /nope: No such file or directory"
    failBlock.exitCode = 1
    session.blockStore.appendForPreview(failBlock)

    return session
}

#Preview {
    BlockListView()
        .environment(blockListPreviewSession())
        .frame(width: 800, height: 500)
}
#endif
