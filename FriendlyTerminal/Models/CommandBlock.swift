import Foundation

@Observable
final class CommandBlock: Identifiable {
    let id: UUID
    let sessionID: UUID

    var command: String
    var cwd: String
    var startedAt: Date

    var outputText: AttributedString = AttributedString()
    var plainText: String = ""

    var exitCode: Int32?
    var finishedAt: Date?

    var isRunning: Bool { exitCode == nil }
    var succeeded: Bool { exitCode == 0 }
    var failed: Bool { exitCode != nil && exitCode != 0 }

    var renderKind: RenderKind = .plainText

    var aiState: AIBlockState = .idle

    init(command: String, cwd: String, sessionID: UUID) {
        self.id = UUID()
        self.sessionID = sessionID
        self.command = command
        self.cwd = cwd
        self.startedAt = Date()
    }
}

enum RenderKind: Equatable {
    case plainText
    case table([[String]])
    case csvTable([[String]])
    case jsonTree
    case imageFile(URL)
    case imageData(Data)
    case fileTree
    case errorHighlighted
    /// Output rendered as clickable items; tapping one drops its `followUp`
    /// command into the command bar (e.g. an `ls` entry → `cd folder`).
    case commandList([CommandListItem])
}

/// One clickable element of a "list" command's output (a folder from `ls`, a
/// branch from `git branch`, …) plus the command to suggest when it's tapped.
struct CommandListItem: Identifiable, Equatable {
    var id: String { label }
    let label: String
    let detail: String?
    let systemImage: String
    /// Command dropped into the command bar when this item is clicked.
    let followUp: String
}

enum AIBlockState: Equatable {
    case idle
    case fetchingExplanation
    case explanation(String)
    case fetchingFix
    case fix(CommandFix)
    case fetchingCommand
    case unavailable
    case error(String)

    static func == (lhs: AIBlockState, rhs: AIBlockState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.fetchingExplanation, .fetchingExplanation),
             (.fetchingFix, .fetchingFix), (.fetchingCommand, .fetchingCommand),
             (.unavailable, .unavailable): return true
        case (.explanation(let a), .explanation(let b)): return a == b
        case (.fix(let a), .fix(let b)): return a == b
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

struct CommandFix: Equatable {
    let fixedCommand: String
    let why: String
    let isDangerous: Bool
}
