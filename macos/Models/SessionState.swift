import Foundation
import Observation

struct GitStatus {
    let branch: String
    let isDirty: Bool
    let uncommittedCount: Int
}

@Observable
@MainActor
final class SessionState: Identifiable {
    let id = UUID()

    var windowTitle: String = "FriendlyTerminal"

    var cwd: String = FileManager.default.homeDirectoryForCurrentUser.path

    var gitStatus: GitStatus? = nil
    @ObservationIgnored private var gitTask: Task<Void, Never>? = nil

    var breadcrumbs: [BreadcrumbItem] {
        let parts = cwd.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        var items: [BreadcrumbItem] = [BreadcrumbItem(name: "~", path: FileManager.default.homeDirectoryForCurrentUser.path)]
        var accumulated = ""
        for part in parts {
            accumulated += "/" + part
            items.append(BreadcrumbItem(name: part, path: accumulated))
        }
        return items
    }

    var fileItems: [FileItem] = []

    let blockStore: BlockStore = BlockStore()
    var isTUIActive: Bool = false

    var altScreenOn: Bool = false
    var bracketedPasteOn: Bool = false

    var pendingCommandText: String = ""

    private(set) var commandBarDraft: String = ""
    private(set) var commandBarRequestToken: Int = 0

    var sendToShell: ((String) -> Void)?

    var isClaudeRunning: Bool {
        guard isTUIActive else { return false }
        return Self.isClaudeCommand(blockStore.currentBlock?.command ?? "")
    }

    var currentClaudeCommand: String? {
        isClaudeRunning ? blockStore.currentBlock?.command : nil
    }

    var claudeRunsWithDangerousFlag: Bool {
        currentClaudeCommand?.contains("--dangerously-skip-permissions") ?? false
    }

    func sendRaw(_ text: String) {
        sendToShell?(text)
    }

    static func isClaudeCommand(_ command: String) -> Bool {
        let lastStage = command.split(separator: "|").last.map(String.init) ?? command
        let tokens = lastStage
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .map(String.init)
        for token in tokens {
            if token.contains("=") { continue }
            if ["sudo", "command", "exec", "time", "env"].contains(token) { continue }
            return (token as NSString).lastPathComponent.lowercased() == "claude"
        }
        return false
    }

    func prefillCommand(_ command: String) {
        commandBarDraft = command
        commandBarRequestToken += 1
    }

    func updateCwd(_ path: String) {
        cwd = path
        refreshFileItems()
        refreshGitStatus()
    }

    func refreshGitStatus() {
        gitTask?.cancel()
        let path = cwd
        gitTask = Task { [weak self] in
            let status: GitStatus? = await withCheckedContinuation { cont in
                DispatchQueue.global(qos: .utility).async {
                    cont.resume(returning: SessionState.queryGitStatus(at: path))
                }
            }
            guard !Task.isCancelled else { return }
            self?.gitStatus = status
        }
    }

    nonisolated private static func queryGitStatus(at path: String) -> GitStatus? {
        func run(_ args: [String]) -> String? {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            p.arguments = ["-C", path] + args
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = Pipe()
            try? p.run()
            p.waitUntilExit()
            guard p.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let branch = run(["rev-parse", "--abbrev-ref", "HEAD"]) else { return nil }
        let porcelain = run(["status", "--porcelain"]) ?? ""
        let changedFiles = porcelain.components(separatedBy: .newlines).filter { !$0.isEmpty }.count
        return GitStatus(branch: branch, isDirty: changedFiles > 0, uncommittedCount: changedFiles)
    }

    func navigateShellTo(_ path: String) {
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        sendToShell?("cd '\(escaped)'\n")
    }

    @ObservationIgnored private var pendingUndo: (command: String, plan: UndoPlan)?

    func executeCommand(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if interceptDeletion(trimmed) { return }
        pendingUndo = UndoPlanner.plan(command: trimmed, cwd: cwd).map { (trimmed, $0) }

        let cmd = command.hasSuffix("\n") ? command : command + "\n"
        sendToShell?(cmd)
    }

    func attachUndoPlan(exitCode: Int32) {
        defer { pendingUndo = nil }
        guard exitCode == 0, let block = blockStore.lastFinishedBlock else { return }
        if let pending = pendingUndo, pending.command == block.command {
            block.undoPlan = pending.plan
        } else {
            block.undoPlan = UndoPlanner.plan(command: block.command, cwd: block.cwd, allowPreState: false)
        }
    }

    func undoLastCommand() {
        guard let block = blockStore.lastUndoableBlock else { return }
        performUndo(block)
    }

    func performUndo(_ block: CommandBlock) {
        guard let plan = block.undoPlan, !block.isUndone else { return }
        let fm = FileManager.default
        for action in plan.actions {
            switch action {
            case .shell(let cmd):
                sendToShell?(cmd + "\n")
            case .trash(let path):
                try? fm.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
            case .restore(let trashed, let original):
                try? fm.moveItem(atPath: trashed, toPath: original)
            }
        }
        block.isUndone = true
        refreshFileItems()
        refreshGitStatus()
    }

    private func interceptDeletion(_ command: String) -> Bool {
        guard let targets = RmInterceptor.safeTargets(command: command, cwd: cwd) else { return false }

        var restores: [UndoAction] = []
        var moved: [String] = []
        for url in targets {
            var trashedURL: NSURL?
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
                moved.append(url.lastPathComponent)
                if let trashedPath = trashedURL?.path {
                    restores.append(.restore(trashed: trashedPath, original: url.path))
                }
            } catch {
            }
        }

        blockStore.startBlock(command: command, cwd: cwd)
        if moved.isEmpty {
            blockStore.appendOutput(plain: "Couldn't move those items to the Trash.\n", attributed: nil)
            blockStore.finishBlock(exitCode: 1)
        } else {
            blockStore.appendOutput(
                plain: "Moved \(moved.count) item\(moved.count == 1 ? "" : "s") to the Trash: \(moved.joined(separator: ", "))\n",
                attributed: nil
            )
            blockStore.finishBlock(exitCode: 0)
            if let block = blockStore.lastFinishedBlock, !restores.isEmpty {
                block.undoPlan = UndoPlan(
                    label: "Undo delete (restore \(restores.count) item\(restores.count == 1 ? "" : "s"))",
                    actions: restores
                )
            }
        }
        refreshFileItems()
        return true
    }

    func refreshFileItems() {
        let url = URL(fileURLWithPath: cwd)
        let keys: [URLResourceKey] = [.nameKey, .isDirectoryKey, .isHiddenKey, .fileSizeKey, .contentModificationDateKey]
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsPackageDescendants]
            )
            fileItems = urls
                .compactMap { FileItem(url: $0) }
                .sorted { lhs, rhs in
                    if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
        } catch {
            fileItems = []
        }
    }
}

struct BreadcrumbItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
}

struct FileItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let isHidden: Bool
    let size: Int64
    let modifiedAt: Date

    init?(url: URL) {
        guard let resources = try? url.resourceValues(forKeys: [
            .nameKey, .isDirectoryKey, .isHiddenKey, .fileSizeKey, .contentModificationDateKey
        ]) else { return nil }

        name = resources.name ?? url.lastPathComponent
        path = url.path
        isDirectory = resources.isDirectory ?? false
        isHidden = resources.isHidden ?? false
        size = Int64(resources.fileSize ?? 0)
        modifiedAt = resources.contentModificationDate ?? Date.distantPast
    }

    var systemImage: String {
        if isDirectory { return "folder.fill" }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "py": return "terminal"
        case "js", "ts", "jsx", "tsx": return "curlybraces"
        case "json", "yaml", "yml", "toml": return "doc.text"
        case "md", "txt": return "doc.plaintext"
        case "png", "jpg", "jpeg", "gif", "webp", "heic": return "photo"
        case "pdf": return "doc.richtext"
        case "zip", "gz", "tar", "xz": return "archivebox"
        case "sh", "zsh", "bash": return "terminal"
        default: return "doc"
        }
    }

    var sizeFormatted: String {
        guard !isDirectory else { return "--" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: size)
    }
}
