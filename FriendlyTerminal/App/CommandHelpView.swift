import SwiftUI

/// Shown in the sidebar while in normal (block) mode: a friendly menu of common
/// command categories. Picking a category lists its commands; picking a command
/// drops it into the command bar so the user can run or tweak it. Which
/// categories appear is user-configurable via the gear button.
struct CommandHelpView: View {
    @Environment(SessionState.self) private var session
    @State private var selected: CommandCategory?
    @State private var showingTutorial = false
    @State private var showingSettings = false
    private let settings = CommandHelpSettings.shared

    private var visibleCategories: [CommandCategory] {
        CommandCategory.all.filter { settings.isEnabled($0.id) }
    }

    private var isDrilledIn: Bool { selected != nil || showingTutorial }
    private var hasAnyEntries: Bool { settings.tutorialVisible || !visibleCategories.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if showingTutorial {
                TerminalTutorialView(onHide: hideTutorial)
            } else if let category = selected {
                commandList(category)
            } else if hasAnyEntries {
                categoryGrid
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .controlBackgroundColor))
        .sheet(isPresented: $showingSettings) {
            HelpCategorySettingsView()
        }
        .onChange(of: showingSettings) { _, isOpen in
            // If the open item got hidden while in settings, pop back out.
            if !isOpen {
                if let s = selected, !settings.isEnabled(s.id) { selected = nil }
                if showingTutorial, !settings.tutorialVisible { showingTutorial = false }
            }
        }
    }

    private func hideTutorial() {
        settings.setTutorialVisible(false)
        withAnimation(.easeInOut(duration: 0.15)) { showingTutorial = false }
    }

    private var headerTitle: String {
        if showingTutorial { return "Get started" }
        return selected?.name ?? "Help with…"
    }

    private var header: some View {
        HStack(spacing: 6) {
            if isDrilledIn {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selected = nil
                        showingTutorial = false
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            Text(headerTitle)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Choose which command groups to show")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var categoryGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8
            ) {
                if settings.tutorialVisible {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { showingTutorial = true }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.accentColor)
                            Text("Get started")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.14))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                ForEach(visibleCategories) { category in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { selected = category }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: category.icon)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.accentColor)
                            Text(category.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.4))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "square.dashed")
                .font(.system(size: 20))
                .foregroundStyle(.tertiary)
            Text("No command groups shown.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Button("Choose groups…") { showingSettings = true }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
    }

    private func commandList(_ category: CommandCategory) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tap a command to drop it into the command bar.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)

                ForEach(category.commands) { item in
                    Button {
                        session.prefillCommand(item.command)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                if item.isDangerous {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.orange)
                                }
                                Text(item.command)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.primary)
                            }
                            Text(item.detail)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(item.isDangerous
                                      ? Color.orange.opacity(0.12)
                                      : Color(nsColor: .quaternaryLabelColor).opacity(0.25))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(item.isDangerous ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
    }
}

/// Persists which command categories the user wants to see in the help menu.
@Observable
@MainActor
final class CommandHelpSettings {
    static let shared = CommandHelpSettings()

    private let storageKey = "enabledHelpCategories"
    private let tutorialKey = "tutorialVisible"
    private(set) var enabledNames: Set<String>
    private(set) var tutorialVisible: Bool

    private init() {
        if let saved = UserDefaults.standard.array(forKey: storageKey) as? [String] {
            enabledNames = Set(saved)
        } else {
            enabledNames = Set(CommandCategory.defaultEnabledNames)
        }
        // Defaults to shown (including for existing users, since the key is new).
        tutorialVisible = UserDefaults.standard.object(forKey: tutorialKey) as? Bool ?? true
    }

    func isEnabled(_ name: String) -> Bool { enabledNames.contains(name) }

    func toggle(_ name: String) {
        if enabledNames.contains(name) {
            enabledNames.remove(name)
        } else {
            enabledNames.insert(name)
        }
        UserDefaults.standard.set(Array(enabledNames), forKey: storageKey)
    }

    func setTutorialVisible(_ visible: Bool) {
        tutorialVisible = visible
        UserDefaults.standard.set(visible, forKey: tutorialKey)
    }
}

/// Sheet that lets the user check which command groups appear.
struct HelpCategorySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    private let settings = CommandHelpSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Command groups")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            Text("Choose which groups appear in the help menu. Turn off the ones you don't need to keep it tidy.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 8)

            ScrollView {
                VStack(spacing: 0) {
                    Toggle(isOn: Binding(
                        get: { settings.tutorialVisible },
                        set: { settings.setTutorialVisible($0) }
                    )) {
                        Label {
                            Text("Get started")
                            Text("Beginner tutorial")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "graduationcap.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .toggleStyle(.switch)
                    .padding(.horizontal)
                    .padding(.vertical, 6)

                    Divider()

                    ForEach(CommandCategory.all) { category in
                        Toggle(isOn: Binding(
                            get: { settings.isEnabled(category.id) },
                            set: { _ in settings.toggle(category.id) }
                        )) {
                            Label {
                                Text(category.name)
                                Text("\(category.commands.count) commands")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            } icon: {
                                Image(systemName: category.icon)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .toggleStyle(.switch)
                        .padding(.horizontal)
                        .padding(.vertical, 6)

                        Divider()
                    }
                }
            }
        }
        .frame(width: 360, height: 460)
    }
}

struct CommandCategory: Identifiable {
    var id: String { name }
    let name: String
    let icon: String
    let commands: [CommandHelpItem]

    /// Groups shown by default the first time the app runs.
    static let defaultEnabledNames = ["Navigate", "Files", "GitHub", "AI", "Search", "System", "Network"]

    static let all: [CommandCategory] = [
        CommandCategory(name: "Navigate", icon: "folder", commands: [
            CommandHelpItem("ls", "List files in the current folder"),
            CommandHelpItem("ls -la", "List everything, including hidden files, with details"),
            CommandHelpItem("cd foldername", "Go into a folder"),
            CommandHelpItem("cd ..", "Go up one folder"),
            CommandHelpItem("cd ~", "Go to your home folder"),
            CommandHelpItem("pwd", "Show the current folder's full path"),
        ]),
        CommandCategory(name: "Files", icon: "doc.on.doc", commands: [
            CommandHelpItem("cat file.txt", "Show a file's contents"),
            CommandHelpItem("cp file copy", "Copy a file"),
            CommandHelpItem("mv file newname", "Move or rename a file"),
            CommandHelpItem("mkdir name", "Make a new folder"),
            CommandHelpItem("touch file.txt", "Create an empty file"),
            CommandHelpItem("rm file.txt", "Delete a file — it does not go to the Trash", dangerous: true),
            CommandHelpItem("rm -rf folder", "Delete a folder and everything in it, permanently", dangerous: true),
            CommandHelpItem("open .", "Open the current folder in Finder"),
        ]),
        CommandCategory(name: "GitHub", icon: "arrow.triangle.branch", commands: [
            CommandHelpItem("git status", "See what has changed"),
            CommandHelpItem("git add .", "Stage all your changes"),
            CommandHelpItem("git commit -m \"message\"", "Save a snapshot with a message"),
            CommandHelpItem("git push", "Upload your commits to GitHub"),
            CommandHelpItem("git pull", "Download the latest changes"),
            CommandHelpItem("git log --oneline", "See recent commits"),
            CommandHelpItem("git push --force", "Overwrite the remote history — can erase others' work", dangerous: true),
        ]),
        CommandCategory(name: "AI", icon: "sparkles", commands: [
            CommandHelpItem("claude", "Start Claude Code in this folder"),
            CommandHelpItem("claude \"fix this bug\"", "Start Claude Code with a request to work on"),
            CommandHelpItem("claude -p \"explain this code\"", "Get a one-shot answer without the chat UI"),
            CommandHelpItem("claude --continue", "Pick up your most recent conversation"),
            CommandHelpItem("claude --resume", "Choose a past conversation to resume"),
            CommandHelpItem(
                "claude --dangerously-skip-permissions",
                "Let Claude act without asking permission each time — fast, but it can change or delete files on its own. Use only when you trust the task.",
                dangerous: true
            ),
            CommandHelpItem("claude mcp", "Manage connected tools (MCP servers)"),
            CommandHelpItem("claude update", "Update Claude Code to the latest version"),
        ]),
        CommandCategory(name: "Search", icon: "magnifyingglass", commands: [
            CommandHelpItem("grep \"text\" file.txt", "Find text inside a file"),
            CommandHelpItem("grep -r \"text\" .", "Search every file in this folder"),
            CommandHelpItem("find . -name \"*.txt\"", "Find files by name"),
            CommandHelpItem("which command", "Show where a command lives"),
        ]),
        CommandCategory(name: "System", icon: "gauge.with.dots.needle.67percent", commands: [
            CommandHelpItem("top", "Live view of running programs"),
            CommandHelpItem("df -h", "Show free disk space"),
            CommandHelpItem("du -sh *", "Show the size of each item here"),
            CommandHelpItem("uptime", "How long the Mac has been on"),
            CommandHelpItem("whoami", "Show your username"),
        ]),
        CommandCategory(name: "Network", icon: "network", commands: [
            CommandHelpItem("ping example.com", "Check if a site is reachable"),
            CommandHelpItem("curl https://example.com", "Fetch a web address"),
            CommandHelpItem("ipconfig getifaddr en0", "Show your local IP address"),
            CommandHelpItem("curl -O url", "Download a file from a URL"),
        ]),
        CommandCategory(name: "Permissions", icon: "lock", commands: [
            CommandHelpItem("ls -l", "See who can read or change each file"),
            CommandHelpItem("chmod +x script.sh", "Make a script runnable"),
            CommandHelpItem("sudo command", "Run a command as administrator", dangerous: true),
            CommandHelpItem("chmod 777 file", "Let anyone read, write, and run a file — rarely a good idea", dangerous: true),
        ]),
        CommandCategory(name: "Processes", icon: "cpu", commands: [
            CommandHelpItem("ps aux", "List everything that's running"),
            CommandHelpItem("jobs", "List programs running in this terminal"),
            CommandHelpItem("kill PID", "Stop a program by its process ID", dangerous: true),
            CommandHelpItem("killall name", "Stop every program with this name", dangerous: true),
        ]),
        CommandCategory(name: "Archives", icon: "archivebox", commands: [
            CommandHelpItem("zip -r archive.zip folder", "Zip up a folder"),
            CommandHelpItem("unzip archive.zip", "Unzip a .zip file"),
            CommandHelpItem("tar -czf archive.tar.gz folder", "Make a compressed .tar.gz"),
            CommandHelpItem("tar -xzf archive.tar.gz", "Extract a .tar.gz"),
        ]),
        CommandCategory(name: "Text", icon: "text.alignleft", commands: [
            CommandHelpItem("echo \"hello\"", "Print some text"),
            CommandHelpItem("head file.txt", "Show the first lines of a file"),
            CommandHelpItem("tail file.txt", "Show the last lines of a file"),
            CommandHelpItem("tail -f log.txt", "Watch a file update live"),
            CommandHelpItem("wc -l file.txt", "Count the lines in a file"),
            CommandHelpItem("sort file.txt", "Sort lines alphabetically"),
        ]),
        CommandCategory(name: "Editors", icon: "pencil", commands: [
            CommandHelpItem("nano file.txt", "Edit a file with a simple editor"),
            CommandHelpItem("vim file.txt", "Edit a file with Vim"),
            CommandHelpItem("code .", "Open this folder in VS Code"),
            CommandHelpItem("open -e file.txt", "Open a file in TextEdit"),
        ]),
        CommandCategory(name: "Node", icon: "shippingbox", commands: [
            CommandHelpItem("npm install", "Install a project's dependencies"),
            CommandHelpItem("npm run dev", "Start the dev server"),
            CommandHelpItem("npm start", "Run the project"),
            CommandHelpItem("npx create-vite", "Run a tool without installing it"),
            CommandHelpItem("node file.js", "Run a JavaScript file"),
        ]),
        CommandCategory(name: "Python", icon: "chevron.left.forwardslash.chevron.right", commands: [
            CommandHelpItem("python3 file.py", "Run a Python script"),
            CommandHelpItem("python3 -m venv venv", "Create a virtual environment"),
            CommandHelpItem("source venv/bin/activate", "Turn on the virtual environment"),
            CommandHelpItem("pip install package", "Install a Python package"),
        ]),
        CommandCategory(name: "Homebrew", icon: "mug", commands: [
            CommandHelpItem("brew install name", "Install an app or tool"),
            CommandHelpItem("brew update", "Refresh Homebrew's catalog"),
            CommandHelpItem("brew upgrade", "Update everything you installed"),
            CommandHelpItem("brew list", "See what you've installed"),
            CommandHelpItem("brew search name", "Search for a package"),
        ]),
        CommandCategory(name: "Docker", icon: "cube.box", commands: [
            CommandHelpItem("docker ps", "List running containers"),
            CommandHelpItem("docker images", "List downloaded images"),
            CommandHelpItem("docker compose up", "Start the services in this folder"),
            CommandHelpItem("docker system prune -a", "Delete all unused containers and images", dangerous: true),
        ]),
        CommandCategory(name: "Environment", icon: "gearshape", commands: [
            CommandHelpItem("echo $PATH", "Show where the shell looks for commands"),
            CommandHelpItem("export NAME=value", "Set an environment variable"),
            CommandHelpItem("env", "List all environment variables"),
            CommandHelpItem("source ~/.zshrc", "Reload your shell settings"),
        ]),
        CommandCategory(name: "Remote", icon: "antenna.radiowaves.left.and.right", commands: [
            CommandHelpItem("ssh user@host", "Connect to another machine"),
            CommandHelpItem("scp file user@host:/path", "Copy a file to another machine"),
            CommandHelpItem("ssh-keygen", "Create an SSH key pair"),
        ]),
        CommandCategory(name: "Disk", icon: "internaldrive", commands: [
            CommandHelpItem("df -h", "Show free space on each drive"),
            CommandHelpItem("du -sh *", "Show how big each item here is"),
            CommandHelpItem("diskutil list", "List drives and partitions"),
        ]),
        CommandCategory(name: "Misc", icon: "ellipsis.circle", commands: [
            CommandHelpItem("date", "Show the current date and time"),
            CommandHelpItem("cal", "Show a calendar"),
            CommandHelpItem("history", "Show commands you've run before"),
            CommandHelpItem("pbcopy < file.txt", "Copy a file's contents to the clipboard"),
            CommandHelpItem("clear", "Clear the screen"),
        ]),
    ]
}

struct CommandHelpItem: Identifiable {
    let id = UUID()
    let command: String
    let detail: String
    let isDangerous: Bool

    init(_ command: String, _ detail: String, dangerous: Bool = false) {
        self.command = command
        self.detail = detail
        self.isDangerous = dangerous
    }
}

#Preview {
    CommandHelpView()
        .environment(SessionState())
        .frame(width: 220, height: 360)
}
