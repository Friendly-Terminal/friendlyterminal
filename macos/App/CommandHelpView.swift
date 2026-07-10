import SwiftUI

struct CommandHelpView: View {
    @Environment(SessionState.self) private var session
    @State private var selected: CommandCategory?
    @State private var showingTutorial = false
    @State private var showingSettings = false
    @State private var searchText = ""
    private let settings = CommandHelpSettings.shared

    private var visibleCategories: [CommandCategory] {
        CommandCategory.all.filter { settings.isEnabled($0.id) }
    }

    private var isDrilledIn: Bool { selected != nil || showingTutorial }
    private var hasAnyEntries: Bool { settings.tutorialVisible || !visibleCategories.isEmpty }

    private struct SearchHit: Identifiable {
        let id = UUID()
        let category: CommandCategory
        let item: CommandHelpItem
    }

    private var searchHits: [SearchHit] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return [] }
        var hits: [SearchHit] = []
        for category in CommandCategory.all {
            let categoryMatches = category.name.lowercased().contains(query)
            for item in category.commands
            where categoryMatches
                || item.command.lowercased().contains(query)
                || item.detail.lowercased().contains(query)
                || item.keywords.lowercased().contains(query) {
                hits.append(SearchHit(category: category, item: item))
            }
        }
        return hits
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if showingTutorial {
                TerminalTutorialView(onHide: hideTutorial)
            } else if let category = selected {
                commandList(category)
            } else {
                searchField
                if !searchText.isEmpty {
                    searchResults
                } else if hasAnyEntries {
                    categoryGrid
                } else {
                    emptyState
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .controlBackgroundColor))
        .sheet(isPresented: $showingSettings) {
            HelpCategorySettingsView()
        }
        .onChange(of: showingSettings) { _, isOpen in
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

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("Search commands", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.4))
        )
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }

    @ViewBuilder
    private var searchResults: some View {
        if searchHits.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
                Text("No commands match \"\(searchText)\".")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(searchHits) { hit in
                        commandButton(hit.item, categoryName: hit.category.name)
                    }
                }
                .padding(12)
            }
        }
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
                Text(category.name == "AI"
                     ? "Tap to fill the command bar, or tap ▶ to run instantly."
                     : "Tap a command to drop it into the command bar.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)

                ForEach(category.commands) { item in
                    commandButton(item, launchAction: directLaunchAction(for: item, in: category))
                }
            }
            .padding(12)
        }
    }

    private func directLaunchAction(
        for item: CommandHelpItem,
        in category: CommandCategory
    ) -> (() -> Void)? {
        guard category.name == "AI",
              !item.isDangerous,
              !item.command.contains("\"")
        else { return nil }
        return { [session] in
            session.executeCommand(item.command)
        }
    }

    private func commandButton(
        _ item: CommandHelpItem,
        categoryName: String? = nil,
        launchAction: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 6) {
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
                        if let categoryName {
                            Spacer(minLength: 4)
                            Text(categoryName)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule().fill(Color(nsColor: .quaternaryLabelColor).opacity(0.5))
                                )
                        }
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

            if let launchAction {
                Button(action: launchAction) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Run this command now")
            }
        }
    }
}

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

    static let defaultEnabledNames = ["Navigate", "Files", "GitHub", "AI", "Search", "System", "Network", "npm", "pip"]

    static let all: [CommandCategory] = [
        CommandCategory(name: "Navigate", icon: "folder", commands: [
            CommandHelpItem("ls", "List files in the current folder", keywords: "list show files directory contents dir"),
            CommandHelpItem("ls -la", "List everything, including hidden files, with details", keywords: "list all hidden detailed long permissions dotfiles"),
            CommandHelpItem("cd foldername", "Go into a folder", keywords: "change directory enter open into go navigate move"),
            CommandHelpItem("cd ..", "Go up one folder", keywords: "up parent back previous directory"),
            CommandHelpItem("cd ~", "Go to your home folder", keywords: "home user directory tilde"),
            CommandHelpItem("pwd", "Show the current folder's full path", keywords: "where current path location directory print working"),
        ]),
        CommandCategory(name: "Files", icon: "doc.on.doc", commands: [
            CommandHelpItem("cat file.txt", "Show a file's contents", keywords: "show print view read contents display concatenate output"),
            CommandHelpItem("cp file copy", "Copy a file", keywords: "copy duplicate clone"),
            CommandHelpItem("mv file newname", "Move or rename a file", keywords: "move rename relocate"),
            CommandHelpItem("mkdir name", "Make a new folder", keywords: "make create directory folder new"),
            CommandHelpItem("touch file.txt", "Create an empty file", keywords: "create new empty file make blank"),
            CommandHelpItem("rm file.txt", "Delete a file — it does not go to the Trash", dangerous: true, keywords: "remove delete erase trash destroy"),
            CommandHelpItem("rm -rf folder", "Delete a folder and everything in it, permanently", dangerous: true, keywords: "remove delete recursive force folder directory erase wipe destroy"),
            CommandHelpItem("open .", "Open the current folder in Finder", keywords: "finder reveal open folder gui show"),
        ]),
        CommandCategory(name: "GitHub", icon: "arrow.triangle.branch", commands: [
            CommandHelpItem("git status", "See what has changed", keywords: "changes status modified state diff version control"),
            CommandHelpItem("git add .", "Stage all your changes", keywords: "stage add track all index version control"),
            CommandHelpItem("git commit -m \"message\"", "Save a snapshot with a message", keywords: "commit save snapshot message record version control"),
            CommandHelpItem("git push", "Upload your commits to GitHub", keywords: "upload push send publish remote sync version control"),
            CommandHelpItem("git pull", "Download the latest changes", keywords: "download pull fetch update sync remote version control"),
            CommandHelpItem("git log --oneline", "See recent commits", keywords: "history log commits recent past version control"),
            CommandHelpItem("git push --force", "Overwrite the remote history — can erase others' work", dangerous: true, keywords: "force overwrite push rewrite history version control"),
        ]),
        CommandCategory(name: "AI", icon: "sparkles", commands: [
            CommandHelpItem("claude", "Start Claude Code in this folder", keywords: "claude ai code assistant anthropic start chat llm"),
            CommandHelpItem("claude \"fix this bug\"", "Start Claude Code with a request to work on", keywords: "claude ai request task prompt ask llm"),
            CommandHelpItem("claude -p \"explain this code\"", "Get a one-shot answer without the chat UI", keywords: "claude print oneshot one-shot query headless pipe ai llm"),
            CommandHelpItem("claude --continue", "Pick up your most recent conversation", keywords: "claude continue resume recent conversation last session ai"),
            CommandHelpItem("claude --resume", "Choose a past conversation to resume", keywords: "claude resume choose conversation past history session ai"),
            CommandHelpItem(
                "claude --dangerously-skip-permissions",
                "Let Claude act without asking permission each time — fast, but it can change or delete files on its own. Use only when you trust the task.",
                dangerous: true,
                keywords: "claude yolo skip permissions dangerous auto unattended bypass ai"
            ),
            CommandHelpItem("claude mcp", "Manage connected tools (MCP servers)", keywords: "claude mcp tools servers integrations connect ai"),
            CommandHelpItem("claude update", "Update Claude Code to the latest version", keywords: "claude update upgrade version latest ai"),
        ]),
        CommandCategory(name: "Search", icon: "magnifyingglass", commands: [
            CommandHelpItem("grep \"text\" file.txt", "Find text inside a file", keywords: "find search text pattern grep match contains lookup"),
            CommandHelpItem("grep -r \"text\" .", "Search every file in this folder", keywords: "find search recursive all files grep match lookup"),
            CommandHelpItem("find . -name \"*.txt\"", "Find files by name", keywords: "find locate files name search lookup"),
            CommandHelpItem("which command", "Show where a command lives", keywords: "which where locate path command find"),
        ]),
        CommandCategory(name: "System", icon: "gauge.with.dots.needle.67percent", commands: [
            CommandHelpItem("top", "Live view of running programs", keywords: "processes activity monitor cpu memory running performance"),
            CommandHelpItem("df -h", "Show free disk space", keywords: "disk space free storage available capacity"),
            CommandHelpItem("du -sh *", "Show the size of each item here", keywords: "size usage disk folder how big space"),
            CommandHelpItem("uptime", "How long the Mac has been on", keywords: "uptime how long running load boot"),
            CommandHelpItem("whoami", "Show your username", keywords: "user username who identity account"),
        ]),
        CommandCategory(name: "Network", icon: "network", commands: [
            CommandHelpItem("ping example.com", "Check if a site is reachable", keywords: "ping reachable connection network test online latency"),
            CommandHelpItem("curl https://example.com", "Fetch a web address", keywords: "curl fetch web http request download url get internet"),
            CommandHelpItem("ipconfig getifaddr en0", "Show your local IP address", keywords: "ip address local network ipconfig wifi"),
            CommandHelpItem("curl -O url", "Download a file from a URL", keywords: "download curl file url save get fetch"),
        ]),
        CommandCategory(name: "Permissions", icon: "lock", commands: [
            CommandHelpItem("ls -l", "See who can read or change each file", keywords: "permissions owner access rights list mode"),
            CommandHelpItem("chmod +x script.sh", "Make a script runnable", keywords: "executable run permission chmod script allow"),
            CommandHelpItem("sudo command", "Run a command as administrator", dangerous: true, keywords: "admin root superuser administrator privilege sudo elevated"),
            CommandHelpItem("chmod 777 file", "Let anyone read, write, and run a file — rarely a good idea", dangerous: true, keywords: "permissions chmod all access open insecure mode"),
        ]),
        CommandCategory(name: "Processes", icon: "cpu", commands: [
            CommandHelpItem("ps aux", "List everything that's running", keywords: "processes running list ps tasks programs"),
            CommandHelpItem("jobs", "List programs running in this terminal", keywords: "jobs background running tasks"),
            CommandHelpItem("kill PID", "Stop a program by its process ID", dangerous: true, keywords: "kill stop terminate end process quit"),
            CommandHelpItem("killall name", "Stop every program with this name", dangerous: true, keywords: "kill stop terminate all process name quit force"),
        ]),
        CommandCategory(name: "Archives", icon: "archivebox", commands: [
            CommandHelpItem("zip -r archive.zip folder", "Zip up a folder", keywords: "zip compress archive folder package bundle"),
            CommandHelpItem("unzip archive.zip", "Unzip a .zip file", keywords: "unzip extract decompress zip unpack open"),
            CommandHelpItem("tar -czf archive.tar.gz folder", "Make a compressed .tar.gz", keywords: "tar compress archive gzip tarball package"),
            CommandHelpItem("tar -xzf archive.tar.gz", "Extract a .tar.gz", keywords: "tar extract decompress unpack gzip open"),
        ]),
        CommandCategory(name: "Text", icon: "text.alignleft", commands: [
            CommandHelpItem("echo \"hello\"", "Print some text", keywords: "echo print output text display say"),
            CommandHelpItem("head file.txt", "Show the first lines of a file", keywords: "head first top lines beginning preview"),
            CommandHelpItem("tail file.txt", "Show the last lines of a file", keywords: "tail last end lines bottom"),
            CommandHelpItem("tail -f log.txt", "Watch a file update live", keywords: "follow watch live log monitor tail stream"),
            CommandHelpItem("wc -l file.txt", "Count the lines in a file", keywords: "count lines words characters wc total"),
            CommandHelpItem("sort file.txt", "Sort lines alphabetically", keywords: "sort order alphabetical arrange organize"),
        ]),
        CommandCategory(name: "Editors", icon: "pencil", commands: [
            CommandHelpItem("nano file.txt", "Edit a file with a simple editor", keywords: "edit editor nano text simple write modify"),
            CommandHelpItem("vim file.txt", "Edit a file with Vim", keywords: "edit editor vim vi text write modify"),
            CommandHelpItem("code .", "Open this folder in VS Code", keywords: "vscode vs code editor open ide"),
            CommandHelpItem("open -e file.txt", "Open a file in TextEdit", keywords: "textedit edit open gui write"),
        ]),
        CommandCategory(name: "npm", icon: "shippingbox", commands: [
            CommandHelpItem("npm install", "Install all dependencies listed in package.json", keywords: "npm install dependencies packages node modules setup i"),
            CommandHelpItem("npm install package", "Add a package to your project", keywords: "npm install add package dependency library i"),
            CommandHelpItem("npm install -g package", "Install a package globally (available everywhere)", keywords: "npm install global system-wide tool cli -g"),
            CommandHelpItem("npm install --save-dev package", "Add a development-only dependency", keywords: "npm install dev devdependency save-dev -D testing build tooling"),
            CommandHelpItem("npm uninstall package", "Remove a package from your project", keywords: "npm uninstall remove delete package dependency"),
            CommandHelpItem("npm update", "Update packages to their latest allowed versions", keywords: "npm update upgrade packages latest"),
            CommandHelpItem("npm outdated", "See which packages have newer versions", keywords: "npm outdated old updates versions check"),
            CommandHelpItem("npm run dev", "Start the development server", keywords: "npm run dev server development localhost start"),
            CommandHelpItem("npm run build", "Build the project for production", keywords: "npm run build production compile bundle"),
            CommandHelpItem("npm start", "Run the project", keywords: "npm start run launch node"),
            CommandHelpItem("npm test", "Run the project's tests", keywords: "npm test tests testing check run"),
            CommandHelpItem("npm run script", "Run a script defined in package.json", keywords: "npm run script task command package.json"),
            CommandHelpItem("npm init -y", "Create a new package.json with default settings", keywords: "npm init create package.json new project setup"),
            CommandHelpItem("npm ci", "Clean install exactly from package-lock.json", keywords: "npm ci clean install lockfile reproducible reliable"),
            CommandHelpItem("npm list", "Show the packages you've installed", keywords: "npm list ls installed packages dependencies show"),
            CommandHelpItem("npm audit", "Check dependencies for security issues", keywords: "npm audit security vulnerabilities check safety"),
            CommandHelpItem("npm audit fix", "Automatically fix vulnerable dependencies", keywords: "npm audit fix security vulnerabilities repair"),
            CommandHelpItem("npm cache clean --force", "Clear npm's cache when things act up", keywords: "npm cache clean clear reset force fix"),
            CommandHelpItem("npx create-vite", "Run a tool once without installing it", keywords: "npx scaffold create run vite generator bootstrap"),
        ]),
        CommandCategory(name: "pip", icon: "cube.box", commands: [
            CommandHelpItem("pip install package", "Install a Python package", keywords: "pip install package python dependency module library add"),
            CommandHelpItem("pip install -r requirements.txt", "Install everything listed in requirements.txt", keywords: "pip install requirements dependencies all batch file"),
            CommandHelpItem("pip install --upgrade package", "Upgrade a package to the latest version", keywords: "pip install upgrade update latest newer package -U"),
            CommandHelpItem("pip install package==1.2.3", "Install a specific version of a package", keywords: "pip install version specific pin exact package"),
            CommandHelpItem("pip uninstall package", "Remove a package", keywords: "pip uninstall remove delete package"),
            CommandHelpItem("pip list", "List the packages you've installed", keywords: "pip list installed packages show"),
            CommandHelpItem("pip show package", "Show details about a package", keywords: "pip show details info package version"),
            CommandHelpItem("pip freeze", "List installed packages with exact versions", keywords: "pip freeze list versions requirements export"),
            CommandHelpItem("pip freeze > requirements.txt", "Save your dependencies to requirements.txt", keywords: "pip freeze requirements save export dependencies lock"),
            CommandHelpItem("pip check", "Check that installed packages are compatible", keywords: "pip check verify compatible dependencies conflicts"),
            CommandHelpItem("python3 -m pip install --upgrade pip", "Update pip itself to the latest version", keywords: "pip upgrade update self latest python module"),
            CommandHelpItem("pip cache purge", "Clear pip's download cache", keywords: "pip cache purge clear clean reset"),
        ]),
        CommandCategory(name: "Python", icon: "chevron.left.forwardslash.chevron.right", commands: [
            CommandHelpItem("python3 file.py", "Run a Python script", keywords: "python run script execute py"),
            CommandHelpItem("python3 -m venv venv", "Create a virtual environment", keywords: "venv virtual environment python isolate create"),
            CommandHelpItem("source venv/bin/activate", "Turn on the virtual environment", keywords: "activate venv virtual environment enable source python"),
            CommandHelpItem("python3 -m http.server", "Start a simple local web server", keywords: "python server http localhost serve web"),
        ]),
        CommandCategory(name: "Node", icon: "hexagon", commands: [
            CommandHelpItem("node file.js", "Run a JavaScript file", keywords: "node run javascript js execute"),
            CommandHelpItem("node --version", "Check which Node version is installed", keywords: "node version check installed"),
            CommandHelpItem("npx tool", "Run a command-line tool without installing it", keywords: "npx run tool once execute"),
        ]),
        CommandCategory(name: "Homebrew", icon: "mug", commands: [
            CommandHelpItem("brew install name", "Install an app or tool", keywords: "brew homebrew install package app tool add"),
            CommandHelpItem("brew update", "Refresh Homebrew's catalog", keywords: "brew update refresh catalog homebrew"),
            CommandHelpItem("brew upgrade", "Update everything you installed", keywords: "brew upgrade update packages homebrew newer"),
            CommandHelpItem("brew list", "See what you've installed", keywords: "brew list installed packages homebrew show"),
            CommandHelpItem("brew search name", "Search for a package", keywords: "brew search find package homebrew lookup"),
        ]),
        CommandCategory(name: "Docker", icon: "cube.box", commands: [
            CommandHelpItem("docker ps", "List running containers", keywords: "docker containers running list ps"),
            CommandHelpItem("docker images", "List downloaded images", keywords: "docker images list downloaded"),
            CommandHelpItem("docker compose up", "Start the services in this folder", keywords: "docker compose services start up run"),
            CommandHelpItem("docker system prune -a", "Delete all unused containers and images", dangerous: true, keywords: "docker prune clean delete remove cleanup unused"),
        ]),
        CommandCategory(name: "Environment", icon: "gearshape", commands: [
            CommandHelpItem("echo $PATH", "Show where the shell looks for commands", keywords: "path environment variable lookup commands"),
            CommandHelpItem("export NAME=value", "Set an environment variable", keywords: "export environment variable set env"),
            CommandHelpItem("env", "List all environment variables", keywords: "env environment variables list show"),
            CommandHelpItem("source ~/.zshrc", "Reload your shell settings", keywords: "source reload shell config zshrc settings refresh"),
        ]),
        CommandCategory(name: "Remote", icon: "antenna.radiowaves.left.and.right", commands: [
            CommandHelpItem("ssh user@host", "Connect to another machine", keywords: "ssh remote connect login server shell"),
            CommandHelpItem("scp file user@host:/path", "Copy a file to another machine", keywords: "scp copy transfer remote file secure upload"),
            CommandHelpItem("ssh-keygen", "Create an SSH key pair", keywords: "ssh key keygen generate keypair authentication"),
        ]),
        CommandCategory(name: "Disk", icon: "internaldrive", commands: [
            CommandHelpItem("df -h", "Show free space on each drive", keywords: "disk free space storage available drive capacity"),
            CommandHelpItem("du -sh *", "Show how big each item here is", keywords: "size disk usage folder how big space"),
            CommandHelpItem("diskutil list", "List drives and partitions", keywords: "disk drives partitions diskutil list volumes"),
        ]),
        CommandCategory(name: "Misc", icon: "ellipsis.circle", commands: [
            CommandHelpItem("date", "Show the current date and time", keywords: "date time clock today now"),
            CommandHelpItem("cal", "Show a calendar", keywords: "calendar cal month dates"),
            CommandHelpItem("history", "Show commands you've run before", keywords: "history previous past commands recall"),
            CommandHelpItem("pbcopy < file.txt", "Copy a file's contents to the clipboard", keywords: "clipboard copy pbcopy paste"),
            CommandHelpItem("clear", "Clear the screen", keywords: "clear clean screen reset cls wipe"),
        ]),
    ]
}

struct CommandHelpItem: Identifiable {
    let id = UUID()
    let command: String
    let detail: String
    let isDangerous: Bool
    let keywords: String

    init(_ command: String, _ detail: String, dangerous: Bool = false, keywords: String = "") {
        self.command = command
        self.detail = detail
        self.isDangerous = dangerous
        self.keywords = keywords
    }
}

#Preview {
    CommandHelpView()
        .environment(SessionState())
        .frame(width: 220, height: 360)
}
