import SwiftUI

@main
struct FriendlyTerminalApp: App {
    @State private var workspace = Workspace()

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(workspace)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1100, height: 720)
        .commands {
            FriendlyTerminalCommands()
        }
    }
}
