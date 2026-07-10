import Foundation

@available(macOS 26.0, *)
protocol AIProvider: Sendable {
    var isAvailable: Bool { get }

    func explainError(
        command: String,
        output: String,
        exitCode: Int32
    ) -> AsyncStream<String>

    func suggestFix(
        command: String,
        output: String,
        exitCode: Int32
    ) async throws -> AIErrorFix

    func commandFromNaturalLanguage(
        _ text: String,
        cwd: String,
        recentCommands: [String]
    ) async throws -> AICommandSuggestion
}

struct AICommandSuggestion: Equatable {
    let command: String
    let explanation: String
    let isDangerous: Bool
}

struct AIErrorFix {
    let fixedCommand: String
    let why: String
    let isDangerous: Bool

    var commandFix: CommandFix {
        CommandFix(fixedCommand: fixedCommand, why: why, isDangerous: isDangerous)
    }
}
