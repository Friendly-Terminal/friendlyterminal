import SwiftUI

struct MainWindowView: View {
    @Environment(Workspace.self) private var workspace
    @State private var onboarding = OnboardingCoordinator()

    var body: some View {
        VStack(spacing: 0) {
            BreadcrumbBarView()
                .environment(workspace.focused)

            Divider()

            HSplitView {
                if workspace.sidebarVisible {
                    SidebarColumnView()
                        .environment(workspace.focused)
                        .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)
                }

                HSplitView {
                    ForEach(workspace.sessions) { session in
                        TerminalPaneView(session: session)
                            .frame(minWidth: 140, maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 700, minHeight: 400)
        .background(Color(nsColor: .textBackgroundColor))
        .overlayPreferenceValue(CoachmarkAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if let step = onboarding.currentStep {
                    CoachmarkOverlay(
                        step: step,
                        targetRect: step.targetID.flatMap { anchors[$0] }.map { proxy[$0] },
                        stepIndex: onboarding.stepIndex,
                        stepCount: onboarding.steps.count,
                        isLastStep: onboarding.isLastStep,
                        onNext: { onboarding.next() },
                        onBack: { onboarding.back() },
                        onSkip: { onboarding.finish() }
                    )
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sendToShell)) { note in
            if let text = note.object as? String {
                workspace.focused.sendToShell?(text)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) { workspace.sidebarVisible.toggle() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newPane)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) { workspace.addPane() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .startOnboarding)) { _ in
            workspace.sidebarVisible = true
            onboarding.start()
        }
        .onReceive(NotificationCenter.default.publisher(for: .undoLastCommand)) { _ in
            workspace.focused.undoLastCommand()
        }
        .onAppear {
            workspace.focused.refreshFileItems()
            onboarding.startIfFirstLaunch()
        }
    }
}

#Preview {
    MainWindowView()
        .environment(Workspace())
        .frame(width: 1100, height: 720)
}
