import Foundation
import Observation

@Observable
@MainActor
final class AIManager {
    static let shared = AIManager()

    private(set) var isAvailable: Bool = false
    private(set) var unavailabilityReason: String = ""

    private init() {
        checkAvailability()
    }

    private func checkAvailability() {
        if #available(macOS 26.0, *) {
            let provider = FoundationModelsProvider()
            isAvailable = provider.isAvailable
            if !isAvailable {
                unavailabilityReason = "Enable Apple Intelligence in System Settings → Apple Intelligence & Siri."
            }
        } else {
            isAvailable = false
            unavailabilityReason = "Apple Intelligence requires macOS Tahoe (26.0) or later."
        }
    }

    func explainError(for block: CommandBlock) {
        guard isAvailable else {
            block.aiState = .unavailable
            return
        }

        guard block.failed, let exitCode = block.exitCode else { return }

        block.aiState = .fetchingExplanation

        Task {
            if #available(macOS 26.0, *) {
                let provider = FoundationModelsProvider()

                for await chunk in provider.explainError(
                    command: block.command,
                    output: block.plainText,
                    exitCode: exitCode
                ) {
                    block.aiState = .explanation(chunk)
                }
            }
        }
    }

    func suggestFix(for block: CommandBlock) {
        guard isAvailable else {
            block.aiState = .unavailable
            return
        }

        guard block.failed, let exitCode = block.exitCode else { return }

        block.aiState = .fetchingFix

        Task {
            if #available(macOS 26.0, *) {
                let provider = FoundationModelsProvider()
                do {
                    let fix = try await provider.suggestFix(
                        command: block.command,
                        output: block.plainText,
                        exitCode: exitCode
                    )
                    block.aiState = .fix(fix.commandFix)
                } catch {
                    block.aiState = .error(error.localizedDescription)
                }
            }
        }
    }

    func translateToCommand(
        _ text: String,
        cwd: String,
        recentCommands: [String],
        completion: @escaping (Result<AICommandSuggestion, Error>) -> Void
    ) {
        guard isAvailable else {
            completion(.failure(AIError.unavailable))
            return
        }

        Task {
            if #available(macOS 26.0, *) {
                let provider = FoundationModelsProvider()
                do {
                    let suggestion = try await provider.commandFromNaturalLanguage(
                        text,
                        cwd: cwd,
                        recentCommands: recentCommands
                    )
                    completion(.success(suggestion))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }
}
