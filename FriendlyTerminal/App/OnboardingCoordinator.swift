import SwiftUI

enum Coachmark {
    static let commandBar = "commandBar"
    static let modeToggle = "modeToggle"
    static let fileSidebar = "fileSidebar"
    static let commandHelp = "commandHelp"
    static let breadcrumbs = "breadcrumbs"
    static let addPane = "addPane"
    static let claudeButton = "claudeButton"
}

struct OnboardingStep: Identifiable {
    let id = UUID()
    let targetID: String?
    let symbol: String
    let title: String
    let message: String

    static let all: [OnboardingStep] = [
        OnboardingStep(
            targetID: nil,
            symbol: "hand.wave",
            title: "Welcome to FriendlyTerminal",
            message: "A friendlier way to use the terminal. Here's a quick 30-second tour of the main parts — you can skip it anytime."
        ),
        OnboardingStep(
            targetID: Coachmark.commandBar,
            symbol: "terminal",
            title: "Run commands here",
            message: "Type a command and press Return to run it. Each command and its output are grouped into a tidy block above."
        ),
        OnboardingStep(
            targetID: Coachmark.modeToggle,
            symbol: "sparkles",
            title: "Or just ask in plain English",
            message: "Switch this to \"Ask AI\" and describe what you want — FriendlyTerminal suggests the command, and you decide whether to run it."
        ),
        OnboardingStep(
            targetID: Coachmark.fileSidebar,
            symbol: "folder",
            title: "Browse your files",
            message: "This shows the folder you're currently in. Click a folder to move into it, or a file to preview it — no commands needed."
        ),
        OnboardingStep(
            targetID: Coachmark.commandHelp,
            symbol: "wand.and.stars",
            title: "Find the right command",
            message: "Not sure what to type? Search or browse common commands by category, then tap one to drop it into the command bar."
        ),
        OnboardingStep(
            targetID: Coachmark.breadcrumbs,
            symbol: "rectangle.split.3x1",
            title: "Know where you are",
            message: "This trail shows the folder you're in. Click any part of it to jump straight to that folder."
        ),
        OnboardingStep(
            targetID: Coachmark.addPane,
            symbol: "plus.rectangle.on.rectangle",
            title: "Work side by side",
            message: "Open another terminal next to this one when you want to do two things at once. You can have several at a time."
        ),
        OnboardingStep(
            targetID: Coachmark.claudeButton,
            symbol: "sparkles",
            title: "Chat with Claude AI",
            message: "Click here to start Claude Code — an AI that reads your files, fixes bugs, and builds features. No commands to memorize. When Claude is running, this sidebar becomes a control panel with clickable buttons."
        ),
        OnboardingStep(
            targetID: nil,
            symbol: "checkmark.circle",
            title: "You're all set",
            message: "That's the tour. You can replay it anytime from Help → Show Welcome Tour. Happy exploring!"
        ),
    ]
}

@Observable
@MainActor
final class OnboardingCoordinator {
    private static let completedKey = "FT.hasCompletedOnboarding"

    private(set) var isActive = false
    private(set) var stepIndex = 0
    let steps = OnboardingStep.all

    var currentStep: OnboardingStep? {
        guard isActive, steps.indices.contains(stepIndex) else { return nil }
        return steps[stepIndex]
    }

    var isLastStep: Bool { stepIndex >= steps.count - 1 }

    func startIfFirstLaunch() {
        guard !UserDefaults.standard.bool(forKey: Self.completedKey) else { return }
        start()
    }

    func start() {
        stepIndex = 0
        withAnimation(.easeInOut(duration: 0.25)) { isActive = true }
    }

    func next() {
        if isLastStep {
            finish()
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { stepIndex += 1 }
        }
    }

    func back() {
        guard stepIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.25)) { stepIndex -= 1 }
    }

    func finish() {
        UserDefaults.standard.set(true, forKey: Self.completedKey)
        withAnimation(.easeInOut(duration: 0.25)) { isActive = false }
    }
}
