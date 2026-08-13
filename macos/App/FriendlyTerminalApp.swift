import SwiftUI

@main
struct FriendlyTerminalApp: App {
    @State private var workspace = Workspace()

    var body: some Scene {
        // ponytail: single Window scene — the shared Workspace can't back two
        // windows; make it a WindowGroup only once sessions are per-window.
        Window("FriendlyTerminal", id: "main") {
            MainWindowView()
                .environment(workspace)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
            FriendlyTerminalCommands()
        }

        Settings {
            SettingsView()
        }
    }
}
