import SwiftUI

struct FriendlyTerminalCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Divider()
        }

        CommandMenu("Shell") {
            Button("Clear Screen") {
                NotificationCenter.default.post(name: .sendToShell, object: "\u{0C}")
            }
            .keyboardShortcut("k", modifiers: .command)

            Button("Split Terminal") {
                NotificationCenter.default.post(name: .newPane, object: nil)
            }
            .keyboardShortcut("d", modifiers: .command)

            Divider()

            Button("Interrupt (Ctrl-C)") {
                NotificationCenter.default.post(name: .sendToShell, object: "\u{03}")
            }
            .keyboardShortcut("c", modifiers: [.command, .control])

            Button("End of File (Ctrl-D)") {
                NotificationCenter.default.post(name: .sendToShell, object: "\u{04}")
            }
            .keyboardShortcut("d", modifiers: [.command, .control])
        }

        CommandGroup(after: .sidebar) {
            Button("Toggle File Sidebar") {
                NotificationCenter.default.post(name: .toggleSidebar, object: nil)
            }
            .keyboardShortcut("\\", modifiers: .command)
        }
    }
}

extension Notification.Name {
    static let sendToShell = Notification.Name("FT.sendToShell")
    static let toggleSidebar = Notification.Name("FT.toggleSidebar")
    static let newPane = Notification.Name("FT.newPane")
}
