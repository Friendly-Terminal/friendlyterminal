import Foundation

/// A reversible action attached to a finished command. Tapping "Undo" on the
/// block runs these actions to put things back the way they were.
struct UndoPlan {
    /// Short, human label for the Undo button (e.g. "Undo: delete folder “build”").
    let label: String
    let actions: [UndoAction]
}

enum UndoAction {
    /// Run this command in the shell (e.g. `mv b a`, `git restore --staged .`).
    case shell(String)
    /// Move this absolute path to the Trash (recoverable in Finder).
    case trash(path: String)
    /// Move a trashed item back to its original location (undo of a delete).
    case restore(trashed: String, original: String)
}

/// Works out how to undo a command. Pure logic: given the command text and the
/// folder it ran in, it returns an `UndoPlan` for the commands that have a clear,
/// safe inverse — or `nil` for read-only or irreversible ones.
///
/// `allowPreState` must be true when called *before* the command runs (so it can
/// check whether a file already existed); commands that need that — touch, cp,
/// mv — only produce a plan in that case.
enum UndoPlanner {
    static func plan(command: String, cwd: String, allowPreState: Bool = true) -> UndoPlan? {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Parsing shell quoting/expansion safely is hard — bail on anything with
        // quotes, globs, pipes, redirects, or chained commands.
        let unsafe = CharacterSet(charactersIn: "'\"*?[]{}|&;<>$`")
        if trimmed.rangeOfCharacter(from: unsafe) != nil { return nil }

        let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let cmd = parts.first else { return nil }
        let args = Array(parts.dropFirst())
        let operands = args.filter { !$0.hasPrefix("-") }

        func resolve(_ p: String) -> URL {
            if p.hasPrefix("/") { return URL(fileURLWithPath: p) }
            if p.hasPrefix("~") { return URL(fileURLWithPath: (p as NSString).expandingTildeInPath) }
            return URL(fileURLWithPath: cwd, isDirectory: true).appendingPathComponent(p)
        }
        let fm = FileManager.default

        switch cmd {
        case "cd":
            // Undo: return to the folder we were in before (this block's cwd).
            return UndoPlan(
                label: "Undo: go back to “\(URL(fileURLWithPath: cwd).lastPathComponent)”",
                actions: [.shell("cd \(q(cwd))")]
            )

        case "mkdir":
            guard let name = operands.last else { return nil }
            let url = resolve(name)
            return UndoPlan(label: "Undo: delete folder “\(url.lastPathComponent)”",
                            actions: [.trash(path: url.path)])

        case "touch":
            guard allowPreState else { return nil }
            let newFiles = operands.map(resolve).filter { !fm.fileExists(atPath: $0.path) }
            guard !newFiles.isEmpty else { return nil } // only undo files we create
            let label = newFiles.count == 1
                ? "Undo: delete “\(newFiles[0].lastPathComponent)”"
                : "Undo: delete \(newFiles.count) new files"
            return UndoPlan(label: label, actions: newFiles.map { .trash(path: $0.path) })

        case "cp":
            guard allowPreState, operands.count >= 2,
                  let src = operands.first, let dest = operands.last else { return nil }
            let destURL = resolve(dest)
            var destIsDir: ObjCBool = false
            let destExists = fm.fileExists(atPath: destURL.path, isDirectory: &destIsDir)
            let created: URL
            if destExists && destIsDir.boolValue {
                created = destURL.appendingPathComponent((src as NSString).lastPathComponent)
                guard !fm.fileExists(atPath: created.path) else { return nil } // would overwrite
            } else if !destExists {
                created = destURL
            } else {
                return nil // overwriting an existing file — original is lost, can't undo
            }
            return UndoPlan(label: "Undo: delete the copy “\(created.lastPathComponent)”",
                            actions: [.trash(path: created.path)])

        case "mv":
            guard allowPreState, operands.count == 2,
                  let src = operands.first, let dest = operands.last else { return nil }
            let srcURL = resolve(src)
            let destURL = resolve(dest)
            var destIsDir: ObjCBool = false
            let movedInto = fm.fileExists(atPath: destURL.path, isDirectory: &destIsDir) && destIsDir.boolValue
            let finalDest = movedInto ? destURL.appendingPathComponent(srcURL.lastPathComponent) : destURL
            if movedInto && fm.fileExists(atPath: finalDest.path) { return nil } // would overwrite
            return UndoPlan(label: "Undo: move “\(srcURL.lastPathComponent)” back",
                            actions: [.shell("mv \(q(finalDest.path)) \(q(srcURL.path))")])

        case "git":
            guard let sub = args.first else { return nil }
            switch sub {
            case "add":
                let rest = args.dropFirst().joined(separator: " ")
                guard !rest.isEmpty else { return nil }
                return UndoPlan(label: "Undo: unstage", actions: [.shell("git restore --staged \(rest)")])
            case "commit":
                return UndoPlan(label: "Undo: undo last commit (keep the changes)",
                                actions: [.shell("git reset --soft HEAD~1")])
            case "checkout", "switch":
                let branchOps = args.dropFirst().filter { !$0.hasPrefix("-") }
                guard branchOps.count == 1 else { return nil } // a branch switch, not a file restore
                return UndoPlan(label: "Undo: switch back to the previous branch",
                                actions: [.shell("git checkout -")])
            default:
                return nil
            }

        case "export":
            guard let first = args.first, let eq = first.firstIndex(of: "="), first.startIndex != eq else { return nil }
            let name = String(first[..<eq])
            return UndoPlan(label: "Undo: unset \(name)", actions: [.shell("unset \(name)")])

        case "zip":
            guard let archive = operands.first else { return nil }
            let url = resolve(archive)
            return UndoPlan(label: "Undo: delete “\(url.lastPathComponent)”",
                            actions: [.trash(path: url.path)])

        case "tar":
            guard let flags = args.first, flags.hasPrefix("-"),
                  flags.contains("c"), flags.contains("f"),
                  let archive = args.dropFirst().first(where: { !$0.hasPrefix("-") }) else { return nil }
            let url = resolve(archive)
            return UndoPlan(label: "Undo: delete “\(url.lastPathComponent)”",
                            actions: [.trash(path: url.path)])

        case "curl":
            if let oIdx = args.firstIndex(of: "-o"), oIdx + 1 < args.count {
                let url = resolve(args[oIdx + 1])
                return UndoPlan(label: "Undo: delete “\(url.lastPathComponent)”",
                                actions: [.trash(path: url.path)])
            }
            if args.contains("-O"), let lastURL = operands.last {
                let name = (lastURL as NSString).lastPathComponent
                guard !name.isEmpty else { return nil }
                let url = resolve(name)
                return UndoPlan(label: "Undo: delete “\(name)”", actions: [.trash(path: url.path)])
            }
            return nil

        case "brew":
            guard args.first == "install" else { return nil }
            let pkgs = args.dropFirst().filter { !$0.hasPrefix("-") }
            guard !pkgs.isEmpty else { return nil }
            return UndoPlan(label: "Undo: uninstall \(pkgs.joined(separator: ", "))",
                            actions: [.shell("brew uninstall \(pkgs.joined(separator: " "))")])

        default:
            return nil
        }
    }

    /// Single-quote a path for safe pasting into the shell.
    private static func q(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

/// Recognizes a *safe* `rm` so we can route it to the Trash (and thus make it
/// undoable) instead of permanently deleting. Returns the resolved targets, or
/// `nil` if the `rm` is too complex to handle safely (globs, quotes, sudo,
/// pipes, missing files…), in which case the real `rm` should run as normal.
enum RmInterceptor {
    static func safeTargets(command: String, cwd: String) -> [URL]? {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let unsafe = CharacterSet(charactersIn: "'\"*?[]{}|&;<>$`~")
        if trimmed.rangeOfCharacter(from: unsafe) != nil { return nil }

        let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard parts.first == "rm" else { return nil }

        let allowedFlags = Set("rfRdiv")
        var targets: [URL] = []
        for arg in parts.dropFirst() {
            if arg.hasPrefix("-") {
                guard Set(arg.dropFirst()).isSubset(of: allowedFlags) else { return nil }
                continue
            }
            let url = arg.hasPrefix("/")
                ? URL(fileURLWithPath: arg)
                : URL(fileURLWithPath: cwd, isDirectory: true).appendingPathComponent(arg)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            targets.append(url)
        }
        return targets.isEmpty ? nil : targets
    }
}
