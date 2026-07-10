import Foundation
import FoundationModels

@available(macOS 26.0, *)
@Generable
struct GeneratedCommandSuggestion {
    @Guide(description: "The exact shell command to run, ready to copy-paste")
    var command: String

    @Guide(description: "One-sentence plain-English explanation of what the command does, for a non-technical user")
    var explanation: String

    @Guide(description: "true if this command could delete files, overwrite data, or requires elevated privileges")
    var isDangerous: Bool
}

@available(macOS 26.0, *)
@Generable
struct GeneratedErrorFix {
    @Guide(description: "The corrected shell command that should fix the error")
    var fixedCommand: String

    @Guide(description: "Short plain-English explanation of what went wrong and how this command fixes it")
    var why: String

    @Guide(description: "true if this command could delete files, overwrite data, requires sudo, or is otherwise risky")
    var isDangerous: Bool
}
