import Foundation

enum CatImageDetector: OutputDetector {
    static let priority = 5

    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "tiff", "tif", "bmp"
    ]

    static func detect(output: String, command: String, cwd: String) -> RenderKind? {
        let parts = command.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        guard parts.first == "cat", parts.count >= 2 else { return nil }

        let filePath = parts.last!
        let ext = (filePath as NSString).pathExtension.lowercased()
        guard imageExtensions.contains(ext) else { return nil }

        let url: URL
        if filePath.hasPrefix("/") {
            url = URL(fileURLWithPath: filePath)
        } else if filePath.hasPrefix("~") {
            url = URL(fileURLWithPath: NSString(string: filePath).expandingTildeInPath)
        } else {
            url = URL(fileURLWithPath: cwd, isDirectory: true).appendingPathComponent(filePath)
        }

        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return .imageFile(url)
    }
}

enum ImagePathDetector: OutputDetector {
    static let priority = 10

    private static let imageExtensions = Set([
        "png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "tiff", "tif", "bmp", "svg"
    ])

    static func detect(output: String, command: String, cwd: String) -> RenderKind? {
        let lines = output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard let lastLine = lines.last else { return nil }

        guard lastLine.hasPrefix("/") else { return nil }
        let ext = (lastLine as NSString).pathExtension.lowercased()
        guard imageExtensions.contains(ext) else { return nil }

        guard FileManager.default.fileExists(atPath: lastLine) else { return nil }

        return .imageFile(URL(fileURLWithPath: lastLine))
    }
}

enum JSONDetector: OutputDetector {
    static let priority = 20

    static func detect(output: String, command: String, cwd: String) -> RenderKind? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.hasPrefix("{") || trimmed.hasPrefix("[") else { return nil }

        guard trimmed.components(separatedBy: .newlines).count >= 2 else { return nil }

        guard let data = trimmed.data(using: .utf8),
              let _ = try? JSONSerialization.jsonObject(with: data) else { return nil }

        return .jsonTree
    }
}

enum CSVDetector: OutputDetector {
    static let priority = 25

    static func detect(output: String, command: String, cwd: String) -> RenderKind? {
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count >= 2 else { return nil }

        let firstLine = lines[0]

        let commas = firstLine.filter { $0 == "," }.count
        let tabs   = firstLine.filter { $0 == "\t" }.count
        let sep: Character
        if commas >= 2 { sep = "," }
        else if tabs >= 1 { sep = "\t" }
        else { return nil }

        let expectedCols = firstLine.split(separator: sep, omittingEmptySubsequences: false).count
        guard expectedCols >= 2 else { return nil }

        let sample = min(lines.count, 20)
        let consistent = lines.prefix(sample).filter {
            $0.split(separator: sep, omittingEmptySubsequences: false).count == expectedCols
        }.count
        guard Double(consistent) / Double(sample) >= 0.8 else { return nil }

        let rows = lines.map {
            $0.split(separator: sep, omittingEmptySubsequences: false).map {
                $0.trimmingCharacters(in: .whitespaces)
                  .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }
        return .csvTable(rows)
    }
}

enum TableDetector: OutputDetector {
    static let priority = 30

    static let minCols = 3
    static let minRows = 3
    static let maxRows = 500

    static func detect(output: String, command: String, cwd: String) -> RenderKind? {
        let lines = output.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard lines.count >= minRows else { return nil }

        let rows = lines.prefix(maxRows).map { line -> [String] in
            splitIntoColumns(line)
        }

        let colCounts = rows.map(\.count)
        let medianCols = colCounts.sorted()[colCounts.count / 2]
        guard medianCols >= minCols else { return nil }

        let consistent = colCounts.filter { abs($0 - medianCols) <= 2 }.count
        guard Double(consistent) / Double(colCounts.count) > 0.7 else { return nil }

        return .table(rows.map { Array($0) })
    }

    private static func splitIntoColumns(_ line: String) -> [String] {
        let pattern = "  +"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(line.startIndex..., in: line)
            let result = regex.stringByReplacingMatches(in: line, range: range, withTemplate: "\t")
            return result.components(separatedBy: "\t")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        return line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    }
}

/// Wraps a name in single quotes (escaping any embedded quotes) so it's safe to
/// paste into the command bar even when it contains spaces or special characters.
private func shellQuote(_ name: String) -> String {
    "'" + name.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

/// Picks an SF Symbol for a file based on its extension (folders are handled
/// separately). Mirrors the sidebar's iconography.
private func fileIcon(for name: String) -> String {
    switch (name as NSString).pathExtension.lowercased() {
    case "swift": return "swift"
    case "js", "ts", "jsx", "tsx": return "curlybraces"
    case "json", "yaml", "yml", "toml": return "doc.text"
    case "md", "txt": return "doc.plaintext"
    case "png", "jpg", "jpeg", "gif", "webp", "heic": return "photo"
    case "pdf": return "doc.richtext"
    case "zip", "gz", "tar", "xz": return "archivebox"
    case "sh", "zsh", "bash", "py": return "terminal"
    default: return "doc"
    }
}

/// Turns a plain `ls` of the current folder into clickable entries: folders
/// suggest `cd folder`, files suggest `open file`. Only handles listings of the
/// current directory (no path argument, not recursive); anything else falls
/// through to normal text rendering. Uses the live filesystem for accurate
/// folder-vs-file detection rather than parsing ls's columns.
enum LsListingDetector: OutputDetector {
    static func detect(output: String, command: String, cwd: String) -> RenderKind? {
        let parts = command.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        guard parts.first == "ls" else { return nil }

        // Every extra argument must be an option flag — a path operand means the
        // listing isn't of `cwd`, so we can't map names to clickable actions.
        let operands = parts.dropFirst()
        for arg in operands {
            guard arg.hasPrefix("-") else { return nil }
            if arg.contains("R") { return nil } // recursive listing — skip
        }
        let showHidden = operands.contains { $0.contains("a") || $0.contains("A") }

        let dir = URL(fileURLWithPath: cwd, isDirectory: true)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: []
        ) else { return nil }

        var items: [CommandListItem] = []
        for url in entries {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey])
            let isDir = values?.isDirectory ?? false
            let isHidden = values?.isHidden ?? url.lastPathComponent.hasPrefix(".")
            if isHidden && !showHidden { continue }

            let name = url.lastPathComponent
            items.append(CommandListItem(
                label: name,
                detail: isDir ? "Open this folder (cd)" : "Open this file",
                systemImage: isDir ? "folder.fill" : fileIcon(for: name),
                followUp: isDir ? "cd \(shellQuote(name))" : "open \(shellQuote(name))"
            ))
        }
        guard !items.isEmpty else { return nil }

        items.sort { lhs, rhs in
            let lhsDir = lhs.systemImage == "folder.fill"
            let rhsDir = rhs.systemImage == "folder.fill"
            if lhsDir != rhsDir { return lhsDir }
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }
        return .commandList(
            hint: "Click a folder to fill in “cd” (go into it) or a file to fill in “open” — then press Return.",
            items: items
        )
    }
}

/// Turns `git branch` into clickable branches: tapping one suggests
/// `git checkout branch`. Skips management forms (`-d`, `-m`, naming a branch).
enum GitBranchDetector: OutputDetector {
    static func detect(output: String, command: String, cwd: String) -> RenderKind? {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        guard trimmed == "git branch" || trimmed.hasPrefix("git branch ") else { return nil }

        let rest = trimmed.dropFirst("git branch".count).trimmingCharacters(in: .whitespaces)
        if !rest.isEmpty {
            // Allow only listing-style flags (e.g. -a, -vv); bail on a branch
            // name operand or destructive flags.
            for arg in rest.components(separatedBy: .whitespaces) where !arg.isEmpty {
                guard arg.hasPrefix("-") else { return nil }
                if arg.contains("d") || arg.contains("D") || arg.contains("m") { return nil }
            }
        }

        var items: [CommandListItem] = []
        for rawLine in output.components(separatedBy: .newlines) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            let isCurrent = line.hasPrefix("* ")
            if isCurrent || line.hasPrefix("+ ") {
                line = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
            let name = line.components(separatedBy: .whitespaces).first ?? line
            // Skip detached-HEAD lines and tracking arrows.
            if name.isEmpty || name.hasPrefix("(") || name.contains("->") { continue }

            items.append(CommandListItem(
                label: isCurrent ? "\(name)  ●" : name,
                detail: isCurrent ? "Current branch" : "Switch to this branch",
                systemImage: "arrow.triangle.branch",
                followUp: "git checkout \(shellQuote(name))"
            ))
        }
        guard !items.isEmpty else { return nil }
        return .commandList(
            hint: "Click a branch to fill in “git checkout” — then press Return to switch to it.",
            items: items
        )
    }
}

/// Turns `git status` into clickable changed files: tapping one suggests
/// `git add file` to stage it. Handles the default (verbose) output; the short
/// / porcelain forms fall through to text.
enum GitStatusDetector: OutputDetector {
    private static let statusKeywords = [
        "modified:", "new file:", "deleted:", "renamed:", "copied:",
        "typechange:", "both modified:", "both added:", "added by us:",
        "deleted by us:", "added by them:", "deleted by them:", "unmerged:"
    ]

    static func detect(output: String, command: String, cwd: String) -> RenderKind? {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        guard trimmed == "git status" || trimmed.hasPrefix("git status ") else { return nil }
        // Short/porcelain output has a different shape — leave it as text.
        if trimmed.contains("-s") || trimmed.contains("--short") || trimmed.contains("--porcelain") {
            return nil
        }

        var items: [CommandListItem] = []
        var seen = Set<String>()
        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            var path: String?
            if let keyword = statusKeywords.first(where: { line.hasPrefix($0) }) {
                path = String(line.dropFirst(keyword.count)).trimmingCharacters(in: .whitespaces)
            } else if rawLine.hasPrefix("\t") && !line.hasPrefix("(") {
                path = line // untracked file (indented, no status keyword)
            }

            guard var file = path, !file.isEmpty else { continue }
            if let arrow = file.range(of: "-> ") { // "renamed: old -> new"
                file = String(file[arrow.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
            guard seen.insert(file).inserted else { continue }

            items.append(CommandListItem(
                label: file,
                detail: "Stage this file (git add)",
                systemImage: "plus.circle",
                followUp: "git add \(shellQuote(file))"
            ))
        }
        guard !items.isEmpty else { return nil }
        return .commandList(
            hint: "Click a file to fill in “git add” for it — then press Return to stage it.",
            items: items
        )
    }
}

/// Turns `git log --oneline` into clickable commits: tapping one suggests
/// `git show <hash>`.
enum GitLogOnelineDetector: OutputDetector {
    static func detect(output: String, command: String, cwd: String) -> RenderKind? {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("git log"), trimmed.contains("--oneline") else { return nil }

        var items: [CommandListItem] = []
        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let hash = String(line.split(separator: " ", maxSplits: 1).first ?? "")
            guard hash.count >= 4, hash.allSatisfy(\.isHexDigit) else { continue }
            items.append(CommandListItem(
                label: line,
                detail: "Show this commit (git show)",
                systemImage: "clock",
                followUp: "git show \(hash)"
            ))
        }
        guard !items.isEmpty else { return nil }
        return .commandList(
            hint: "Click a commit to fill in “git show” — then press Return to view it.",
            items: items
        )
    }
}

/// Turns `git tag` into clickable tags: tapping one suggests `git checkout tag`.
enum GitTagDetector: OutputDetector {
    static func detect(output: String, command: String, cwd: String) -> RenderKind? {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        guard trimmed == "git tag"
            || trimmed.hasPrefix("git tag -l")
            || trimmed.hasPrefix("git tag --list") else { return nil }

        var items: [CommandListItem] = []
        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.contains(" ") else { continue }
            items.append(CommandListItem(
                label: line,
                detail: "Check out this tag",
                systemImage: "tag",
                followUp: "git checkout \(shellQuote(line))"
            ))
        }
        guard !items.isEmpty else { return nil }
        return .commandList(
            hint: "Click a tag to fill in “git checkout” — then press Return to check it out.",
            items: items
        )
    }
}

/// Turns `brew list` into clickable packages: tapping one suggests `brew info`.
enum BrewListDetector: OutputDetector {
    static func detect(output: String, command: String, cwd: String) -> RenderKind? {
        let parts = command.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        guard parts.first == "brew",
              let sub = parts.dropFirst().first, (sub == "list" || sub == "ls") else { return nil }
        // "--versions" prints "name version" pairs — a different shape.
        if parts.contains("--versions") { return nil }

        var items: [CommandListItem] = []
        var seen = Set<String>()
        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("==>") { continue }
            for token in line.components(separatedBy: .whitespaces) where !token.isEmpty {
                guard seen.insert(token).inserted else { continue }
                items.append(CommandListItem(
                    label: token,
                    detail: "See package details (brew info)",
                    systemImage: "shippingbox",
                    followUp: "brew info \(shellQuote(token))"
                ))
            }
        }
        guard !items.isEmpty else { return nil }
        return .commandList(
            hint: "Click a package to fill in “brew info” — then press Return to see its details.",
            items: items
        )
    }
}

/// Turns `history` into clickable past commands: tapping one drops that command
/// back into the command bar, ready to run or tweak.
enum HistoryDetector: OutputDetector {
    static func detect(output: String, command: String, cwd: String) -> RenderKind? {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        guard trimmed == "history" || trimmed.hasPrefix("history ") else { return nil }

        var items: [CommandListItem] = []
        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            // Lines look like "  123  the command".
            let pieces = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard pieces.count == 2, Int(pieces[0]) != nil else { continue }
            let past = pieces[1].trimmingCharacters(in: .whitespaces)
            guard !past.isEmpty else { continue }
            items.append(CommandListItem(
                label: past,
                detail: "Use this command again",
                systemImage: "clock.arrow.circlepath",
                followUp: past
            ))
        }
        guard !items.isEmpty else { return nil }
        if items.count > 200 { items = Array(items.suffix(200)) }
        return .commandList(
            hint: "Click a past command to load it into the command bar — then press Return to run it again.",
            items: items
        )
    }
}

enum FileTreeDetector: OutputDetector {
    static let priority = 40

    static func detect(output: String, command: String, cwd: String) -> RenderKind? {
        if output.contains("├──") || output.contains("└──") || output.contains("│") {
            return .fileTree
        }
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count >= 3 else { return nil }
        let pathLines = lines.filter { $0.hasPrefix("./") || ($0.hasPrefix("/") && $0.contains("/")) }
        if Double(pathLines.count) / Double(lines.count) > 0.8 {
            return .fileTree
        }
        return nil
    }
}
