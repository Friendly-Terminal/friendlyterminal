import Foundation
import FoundationModels

@available(macOS 26.0, *)
final class FoundationModelsProvider: AIProvider, @unchecked Sendable {

    var isAvailable: Bool {
        switch SystemLanguageModel.default.availability {
        case .available: return true
        case .unavailable: return false
        @unknown default: return false
        }
    }

    func explainError(
        command: String,
        output: String,
        exitCode: Int32
    ) -> AsyncStream<String> {
        AsyncStream<String> { continuation in
            Task {
                guard self.isAvailable else {
                    continuation.yield("Apple Intelligence is not available on this device.")
                    continuation.finish()
                    return
                }

                let session = LanguageModelSession(instructions: """
                    You are a friendly helper inside a macOS terminal app for non-technical users.
                    Explain shell errors in simple, plain English — no jargon, no markdown formatting, no bullet points.
                    Keep your answer to 1-3 sentences maximum.
                    """)

                let prompt = """
                The user ran: \(command)
                It exited with code \(exitCode). Output:
                \(output.prefix(800))

                Explain what went wrong in plain English. No fix suggestions — just explain the error.
                """

                do {
                    let stream = session.streamResponse(to: prompt)
                    for try await snapshot in stream {
                        continuation.yield(snapshot.content)
                    }
                } catch {
                    continuation.yield("Could not generate explanation: \(error.localizedDescription)")
                }
                continuation.finish()
            }
        }
    }

    func suggestFix(
        command: String,
        output: String,
        exitCode: Int32
    ) async throws -> AIErrorFix {
        guard isAvailable else { throw AIError.unavailable }

        let session = LanguageModelSession(instructions: """
            You are a shell command expert helping a non-technical macOS user fix errors.
            Provide the minimal corrected command. Never suggest destructive changes as the first option.
            """)

        let prompt = """
        The user ran: \(command)
        Failed with exit code \(exitCode). Output:
        \(output.prefix(800))

        Provide the corrected command.
        """

        let response = try await session.respond(
            to: prompt,
            generating: GeneratedErrorFix.self
        )

        return AIErrorFix(
            fixedCommand: response.content.fixedCommand,
            why: response.content.why,
            isDangerous: response.content.isDangerous
        )
    }

    func commandFromNaturalLanguage(
        _ text: String,
        cwd: String,
        recentCommands: [String]
    ) async throws -> AICommandSuggestion {
        guard isAvailable else { throw AIError.unavailable }

        let history = recentCommands.suffix(5).joined(separator: "\n  ")

        let session = LanguageModelSession(instructions: """
            You are a shell command generator for macOS zsh.
            The user is not technical — translate their plain-English request into a single shell command.
            Prefer safe, reversible commands. Mark anything that deletes, overwrites, or needs sudo as dangerous.
            """)

        let prompt = """
        Current directory: \(cwd)
        Recent commands:
          \(history.isEmpty ? "(none)" : history)

        The user wants to: \(text)
        """

        let response = try await session.respond(
            to: prompt,
            generating: GeneratedCommandSuggestion.self
        )

        return AICommandSuggestion(
            command: response.content.command,
            explanation: response.content.explanation,
            isDangerous: response.content.isDangerous
        )
    }
}

enum AIError: LocalizedError {
    case unavailable
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Apple Intelligence is not available. Enable it in System Settings → Apple Intelligence & Siri."
        case .generationFailed(let reason):
            return "AI generation failed: \(reason)"
        }
    }
}
