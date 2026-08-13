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
    var lastError: String?

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
        mutate(["commit", "-m", message]) { [weak self] in
            self?.commitMessage = ""
        }
    }

    private func mutate(_ args: [String], onSuccess: (() -> Void)? = nil) {
        let p = path
        isBusy = true
        Task {
            let result = await Self.run(args, at: p)
            if result.ok {
                lastError = nil
                onSuccess?()
            } else {
                let err = result.err?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                lastError = err.isEmpty ? "git \(args.first ?? "") failed" : err
            }
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
            path = unescapePath(path)
            guard !path.isEmpty else { continue }
            result.append(GitFileChange(path: path, index: chars[0], workTree: chars[1]))
        }
        return result
    }

    /// Undoes git's C-style quoting (octal escapes, \", \\) so non-ASCII paths stage correctly.
    nonisolated private static func unescapePath(_ raw: String) -> String {
        guard raw.count >= 2, raw.hasPrefix("\""), raw.hasSuffix("\"") else { return raw }
        let inner = Array(raw.dropFirst().dropLast().utf8)
        var bytes: [UInt8] = []
        var i = 0
        while i < inner.count {
            let b = inner[i]
            guard b == UInt8(ascii: "\\"), i + 1 < inner.count else {
                bytes.append(b)
                i += 1
                continue
            }
            let n = inner[i + 1]
            i += 2
            switch n {
            case UInt8(ascii: "t"): bytes.append(0x09)
            case UInt8(ascii: "n"): bytes.append(0x0A)
            case UInt8(ascii: "r"): bytes.append(0x0D)
            case UInt8(ascii: "0")...UInt8(ascii: "7"):
                var value = Int(n - UInt8(ascii: "0"))
                var digits = 1
                while digits < 3, i < inner.count,
                      (UInt8(ascii: "0")...UInt8(ascii: "7")).contains(inner[i]) {
                    value = value * 8 + Int(inner[i] - UInt8(ascii: "0"))
                    i += 1
                    digits += 1
                }
                bytes.append(UInt8(value & 0xFF))
            default: bytes.append(n)
            }
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    nonisolated private static func run(_ args: [String], at path: String) async -> (ok: Bool, err: String?) {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = runSync(args, at: path)
                cont.resume(returning: (result.ok, result.err))
            }
        }
    }

    nonisolated private static func runSync(_ args: [String], at path: String) -> (ok: Bool, out: String?, err: String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", path] + args
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        do { try process.run() } catch { return (false, nil, error.localizedDescription) }
        // Drain both pipes before waiting so a full pipe buffer can't deadlock.
        var errData = Data()
        let group = DispatchGroup()
        DispatchQueue.global(qos: .userInitiated).async(group: group) {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        }
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        group.wait()
        process.waitUntilExit()
        let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let err = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (process.terminationStatus == 0, out, err)
    }
}
