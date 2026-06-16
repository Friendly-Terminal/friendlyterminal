import Foundation
import Observation

@Observable
@MainActor
final class SessionState: Identifiable {
    let id = UUID()

    var windowTitle: String = "FriendlyTerminal"

    var cwd: String = FileManager.default.homeDirectoryForCurrentUser.path

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

    // Interactivity signals from the running command, used to decide when to
    // switch to the live terminal (see TerminalContainerView).
    var altScreenOn: Bool = false
    var bracketedPasteOn: Bool = false

    var pendingCommandText: String = ""

    /// Text the command bar should adopt, plus a token the bar watches so the
    /// same command can be requested twice in a row.
    private(set) var commandBarDraft: String = ""
    private(set) var commandBarRequestToken: Int = 0

    var sendToShell: ((String) -> Void)?

    func prefillCommand(_ command: String) {
        commandBarDraft = command
        commandBarRequestToken += 1
    }

    func updateCwd(_ path: String) {
        cwd = path
        refreshFileItems()
    }

    func navigateShellTo(_ path: String) {
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        sendToShell?("cd '\(escaped)'\n")
    }

    func executeCommand(_ command: String) {
        let cmd = command.hasSuffix("\n") ? command : command + "\n"
        sendToShell?(cmd)
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
