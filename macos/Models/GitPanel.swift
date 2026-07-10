import Foundation
import Observation

/// One changed file in the working tree, as reported by `git status --porcelain`.
/// `index` is the staged (X) column, `workTree` the unstaged (Y) column.
struct GitFileChange: Identifiable {
    var id: String { path }
    let path: String
    let index: Character
    let workTree: Character

    var isUntracked: Bool { index == "?" }
    var isStaged: Bool { index != " " && index != "?" }

    private var primary: Character { isStaged ? index : workTree }

    var statusLabel: String {
        if isUntracked { return "New" }
        switch primary {
        case "M": return "Modified"
        case "A": return "Added"
        case "D": return "Deleted"
        case "R": return "Renamed"
        case "C": return "Copied"
        case "U": return "Conflict"
        default:  return "Changed"
        }
    }

    var systemImage: String {
        if isUntracked { return "plus.circle" }
        switch primary {
        case "D": return "minus.circle"
        case "R", "C": return "arrow.right.circle"
        case "U": return "exclamationmark.triangle"
        default:  return "pencil.circle"
        }
    }
}

/// Backs the mini Git panel: lists changes, stages/unstages, and commits — each
/// run as a quick `git` subprocess (off the main thread), mirroring the existing
/// git-status query. Pushing is left to the shell so credential prompts surface
/// in the terminal.
@Observable
@MainActor
final class GitPanel {
    private let path: String

    var isRepo: Bool = true
    var branch: String = ""
    var changes: [GitFileChange] = []
    var ahead: Int = 0
    var isBusy: Bool = false
    var commitMessage: String = ""

    init(path: String) { self.path = path }

    var stagedCount: Int { changes.filter(\.isStaged).count }
    var hasChanges: Bool { !changes.isEmpty }
    var canCommit: Bool {
        stagedCount > 0 && !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBusy
    }

    func refresh() {
        let p = path
        isBusy = true
        Task {
            let snap = await Self.load(p)
            apply(snap)
            isBusy = false
        }
    }

    func toggleStage(_ change: GitFileChange) {
        mutate(change.isStaged
               ? ["restore", "--staged", "--", change.path]
               : ["add", "--", change.path])
    }

    func stageAll()   { mutate(["add", "-A"]) }
    func unstageAll() { mutate(["reset", "-q"]) }

    func commit() {
        let message = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        commitMessage = ""
        mutate(["commit", "-m", message])
    }

    private func mutate(_ args: [String]) {
        let p = path
        isBusy = true
        Task {
            _ = await Self.run(args, at: p)
            let snap = await Self.load(p)
            apply(snap)
            isBusy = false
        }
    }

    private func apply(_ snap: Snapshot) {
        isRepo = snap.isRepo
        branch = snap.branch
        changes = snap.changes
        ahead = snap.ahead
    }

    // MARK: - Subprocess plumbing

    private struct Snapshot {
        let isRepo: Bool
        let branch: String
        let changes: [GitFileChange]
        let ahead: Int
    }

    nonisolated private static func load(_ path: String) async -> Snapshot {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                cont.resume(returning: loadSync(path))
            }
        }
    }

    nonisolated private static func loadSync(_ path: String) -> Snapshot {
        guard let branch = runSync(["rev-parse", "--abbrev-ref", "HEAD"], at: path).out else {
            return Snapshot(isRepo: false, branch: "", changes: [], ahead: 0)
        }
        let porcelain = runSync(["status", "--porcelain"], at: path).out ?? ""
        let changes = parse(porcelain)

        var ahead = 0
        if let counts = runSync(["rev-list", "--count", "--left-right", "@{upstream}...HEAD"], at: path).out {
            let parts = counts.split(whereSeparator: { $0 == "\t" || $0 == " " })
            if parts.count == 2 { ahead = Int(parts[1]) ?? 0 }
        }
        return Snapshot(isRepo: true, branch: branch, changes: changes, ahead: ahead)
    }

    nonisolated private static func parse(_ porcelain: String) -> [GitFileChange] {
        var result: [GitFileChange] = []
        for line in porcelain.components(separatedBy: .newlines) {
            let chars = Array(line)
            guard chars.count >= 4 else { continue }
            var path = String(chars[3...]).trimmingCharacters(in: .whitespaces)
            if let arrow = path.range(of: " -> ") { path = String(path[arrow.upperBound...]) }
            path = path.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            guard !path.isEmpty else { continue }
            result.append(GitFileChange(path: path, index: chars[0], workTree: chars[1]))
        }
        return result
    }

    nonisolated private static func run(_ args: [String], at path: String) async -> Bool {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                cont.resume(returning: runSync(args, at: path).ok)
            }
        }
    }

    nonisolated private static func runSync(_ args: [String], at path: String) -> (ok: Bool, out: String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", path] + args
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = Pipe()
        do { try process.run() } catch { return (false, nil) }
        process.waitUntilExit()
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (process.terminationStatus == 0, out)
    }
}
