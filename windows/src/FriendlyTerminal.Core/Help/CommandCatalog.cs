namespace FriendlyTerminal.Core.Help;

/// <summary>
/// The friendly command cheat sheet, Windows/PowerShell-adapted. Mirrors the macOS
/// catalog (see docs/behavior-spec/command-catalog.md) but uses PowerShell-native
/// commands. Plain-language Detail and hidden Keywords stay aligned so intent-based
/// search works the same way on both platforms.
/// </summary>
public static class CommandCatalog
{
    public static IReadOnlyList<string> DefaultEnabledIds { get; } =
    [
        "Navigate", "Files", "GitHub", "AI", "Search", "System", "Network", "npm", "pip"
    ];

    public static IReadOnlyList<CommandCategory> All { get; } =
    [
        new CommandCategory("Navigate", "Navigate", "folder",
        [
            new CommandItem("ls", "List files in the current folder", Keywords: "list show files directory contents dir Get-ChildItem gci"),
            new CommandItem("ls -Force", "List everything, including hidden files", Keywords: "list all hidden detailed dotfiles force Get-ChildItem gci"),
            new CommandItem("cd foldername", "Go into a folder", Keywords: "change directory enter open into go navigate move Set-Location sl chdir"),
            new CommandItem("cd ..", "Go up one folder", Keywords: "up parent back previous directory Set-Location"),
            new CommandItem("cd ~", "Go to your home folder", Keywords: "home user directory tilde Set-Location"),
            new CommandItem("pwd", "Show the current folder's full path", Keywords: "where current path location directory print working Get-Location gl"),
        ]),
        new CommandCategory("Files", "Files", "file",
        [
            new CommandItem("cat file.txt", "Show a file's contents", Keywords: "show print view read contents display Get-Content type gc"),
            new CommandItem("cp file copy", "Copy a file", Keywords: "copy duplicate clone Copy-Item"),
            new CommandItem("mv file newname", "Move or rename a file", Keywords: "move rename relocate Move-Item"),
            new CommandItem("mkdir name", "Make a new folder", Keywords: "make create directory folder new New-Item ni"),
            new CommandItem("New-Item file.txt", "Create an empty file", Keywords: "create new empty file make blank touch ni"),
            new CommandItem("rm file.txt", "Delete a file - it does not go to the Recycle Bin", IsDangerous: true, Keywords: "remove delete erase destroy Remove-Item del ri"),
            new CommandItem("rm -r folder", "Delete a folder and everything in it, permanently", IsDangerous: true, Keywords: "remove delete recursive force folder directory erase wipe destroy Remove-Item ri"),
            new CommandItem("start .", "Open the current folder in Explorer", Keywords: "explorer reveal open folder gui show Invoke-Item ii"),
        ]),
        new CommandCategory("GitHub", "GitHub", "github",
        [
            new CommandItem("git status", "See what has changed", Keywords: "changes status modified state diff version control"),
            new CommandItem("git add .", "Stage all your changes", Keywords: "stage add track all index version control"),
            new CommandItem("git commit -m \"message\"", "Save a snapshot with a message", Keywords: "commit save snapshot message record version control"),
            new CommandItem("git push", "Upload your commits to GitHub", Keywords: "upload push send publish remote sync version control"),
            new CommandItem("git pull", "Download the latest changes", Keywords: "download pull fetch update sync remote version control"),
            new CommandItem("git log --oneline", "See recent commits", Keywords: "history log commits recent past version control"),
            new CommandItem("git push --force", "Overwrite the remote history - can erase others' work", IsDangerous: true, Keywords: "force overwrite push rewrite history version control"),
        ]),
        new CommandCategory("AI", "AI", "ai",
        [
            new CommandItem("claude", "Start Claude Code in this folder", Keywords: "claude ai code assistant anthropic start chat llm"),
            new CommandItem("claude \"fix this bug\"", "Start Claude Code with a request to work on", Keywords: "claude ai request task prompt ask llm"),
            new CommandItem("claude -p \"explain this code\"", "Get a one-shot answer without the chat UI", Keywords: "claude print oneshot one-shot query headless pipe ai llm"),
            new CommandItem("claude --continue", "Pick up your most recent conversation", Keywords: "claude continue resume recent conversation last session ai"),
            new CommandItem("claude --resume", "Choose a past conversation to resume", Keywords: "claude resume choose conversation past history session ai"),
            new CommandItem(
                "claude --dangerously-skip-permissions",
                "Let Claude act without asking permission each time - fast, but it can change or delete files on its own. Use only when you trust the task.",
                IsDangerous: true,
                Keywords: "claude yolo skip permissions dangerous auto unattended bypass ai"),
            new CommandItem("claude mcp", "Manage connected tools (MCP servers)", Keywords: "claude mcp tools servers integrations connect ai"),
            new CommandItem("claude update", "Update Claude Code to the latest version", Keywords: "claude update upgrade version latest ai"),
        ]),
        new CommandCategory("Search", "Search", "search",
        [
            new CommandItem("Select-String -Pattern \"text\" file.txt", "Find text inside a file", Keywords: "find search text pattern grep match contains lookup sls"),
            new CommandItem("Get-ChildItem -Recurse | Select-String -Pattern \"text\"", "Search every file in this folder", Keywords: "find search recursive all files grep match lookup sls"),
            new CommandItem("Get-ChildItem -Recurse -Filter *.txt", "Find files by name", Keywords: "find locate files name search lookup filter"),
            new CommandItem("Get-Command name", "Show where a command lives", Keywords: "which where locate path command find"),
        ]),
        new CommandCategory("System", "System", "system",
        [
            new CommandItem("Get-Process", "List everything that's running", Keywords: "processes activity task cpu memory running performance ps"),
            new CommandItem("Get-PSDrive", "Show your drives and free space", Keywords: "disk space free storage available capacity drive volume"),
            new CommandItem("Get-ComputerInfo", "Show details about this PC", Keywords: "system info computer details specs"),
            new CommandItem("$env:USERNAME", "Show your username", Keywords: "user username who identity account"),
        ]),
        new CommandCategory("Network", "Network", "network",
        [
            new CommandItem("Test-Connection example.com", "Check if a site is reachable (ping)", Keywords: "ping reachable connection network test online latency"),
            new CommandItem("Invoke-WebRequest https://example.com", "Fetch a web address", Keywords: "curl fetch web http request download url get internet iwr wget"),
            new CommandItem("ipconfig", "Show your network and IP address", Keywords: "ip address local network wifi ipconfig"),
            new CommandItem("Invoke-WebRequest -OutFile file url", "Download a file from a URL", Keywords: "download file url save get fetch iwr wget"),
        ]),
        new CommandCategory("Permissions", "Permissions", "lock",
        [
            new CommandItem("Get-Acl file", "See who can read or change a file", Keywords: "permissions owner access rights acl list"),
            new CommandItem("icacls file", "View or change file permissions", Keywords: "permissions icacls access rights change"),
            new CommandItem("Start-Process -Verb RunAs powershell", "Run a new shell as administrator", IsDangerous: true, Keywords: "admin root superuser administrator privilege runas elevated sudo"),
        ]),
        new CommandCategory("Processes", "Processes", "cpu",
        [
            new CommandItem("Get-Process", "List everything that's running", Keywords: "processes running list ps tasks programs"),
            new CommandItem("Get-Job", "List background jobs", Keywords: "jobs background running tasks"),
            new CommandItem("Stop-Process -Id PID", "Stop a program by its process ID", IsDangerous: true, Keywords: "stop terminate end process quit kill"),
            new CommandItem("Stop-Process -Name name", "Stop every program with this name", IsDangerous: true, Keywords: "stop terminate process name quit force kill"),
        ]),
        new CommandCategory("Archives", "Archives", "archive",
        [
            new CommandItem("Compress-Archive -Path folder -DestinationPath out.zip", "Zip up a folder", Keywords: "zip compress archive folder package bundle"),
            new CommandItem("Expand-Archive out.zip", "Unzip a .zip file", Keywords: "unzip extract decompress zip unpack open"),
            new CommandItem("Compress-Archive -Path * -Update -DestinationPath out.zip", "Add files to an existing .zip", Keywords: "zip update add archive append"),
        ]),
        new CommandCategory("Text", "Text", "text",
        [
            new CommandItem("Write-Output \"hello\"", "Print some text", Keywords: "echo print output text display say write"),
            new CommandItem("Get-Content file.txt | Select-Object -First 10", "Show the first lines of a file", Keywords: "head first top lines beginning preview"),
            new CommandItem("Get-Content file.txt | Select-Object -Last 10", "Show the last lines of a file", Keywords: "tail last end lines bottom"),
            new CommandItem("Get-Content log.txt -Wait", "Watch a file update live", Keywords: "follow watch live log monitor tail stream wait"),
            new CommandItem("(Get-Content file.txt | Measure-Object -Line).Lines", "Count the lines in a file", Keywords: "count lines words characters wc total measure"),
            new CommandItem("Get-Content file.txt | Sort-Object", "Sort lines alphabetically", Keywords: "sort order alphabetical arrange organize"),
        ]),
        new CommandCategory("Editors", "Editors", "edit",
        [
            new CommandItem("notepad file.txt", "Edit a file with Notepad", Keywords: "edit editor notepad text simple write modify"),
            new CommandItem("code .", "Open this folder in VS Code", Keywords: "vscode vs code editor open ide"),
            new CommandItem("Invoke-Item file.txt", "Open a file with its default app", Keywords: "open default app editor ii start"),
        ]),
        new CommandCategory("npm", "npm", "package",
        [
            new CommandItem("npm install", "Install all dependencies listed in package.json", Keywords: "npm install dependencies packages node modules setup i"),
            new CommandItem("npm install package", "Add a package to your project", Keywords: "npm install add package dependency library i"),
            new CommandItem("npm install -g package", "Install a package globally (available everywhere)", Keywords: "npm install global system-wide tool cli -g"),
            new CommandItem("npm install --save-dev package", "Add a development-only dependency", Keywords: "npm install dev devdependency save-dev -D testing build tooling"),
            new CommandItem("npm uninstall package", "Remove a package from your project", Keywords: "npm uninstall remove delete package dependency"),
            new CommandItem("npm update", "Update packages to their latest allowed versions", Keywords: "npm update upgrade packages latest"),
            new CommandItem("npm run dev", "Start the development server", Keywords: "npm run dev server development localhost start"),
            new CommandItem("npm run build", "Build the project for production", Keywords: "npm run build production compile bundle"),
            new CommandItem("npm start", "Run the project", Keywords: "npm start run launch node"),
            new CommandItem("npm test", "Run the project's tests", Keywords: "npm test tests testing check run"),
            new CommandItem("npm list", "Show the packages you've installed", Keywords: "npm list ls installed packages dependencies show"),
            new CommandItem("npm audit", "Check dependencies for security issues", Keywords: "npm audit security vulnerabilities check safety"),
            new CommandItem("npm audit fix", "Automatically fix vulnerable dependencies", Keywords: "npm audit fix security vulnerabilities repair"),
            new CommandItem("npx create-vite", "Run a tool once without installing it", Keywords: "npx scaffold create run vite generator bootstrap"),
        ]),
        new CommandCategory("pip", "pip", "cube",
        [
            new CommandItem("pip install package", "Install a Python package", Keywords: "pip install package python dependency module library add"),
            new CommandItem("pip install -r requirements.txt", "Install everything listed in requirements.txt", Keywords: "pip install requirements dependencies all batch file"),
            new CommandItem("pip install --upgrade package", "Upgrade a package to the latest version", Keywords: "pip install upgrade update latest newer package -U"),
            new CommandItem("pip install package==1.2.3", "Install a specific version of a package", Keywords: "pip install version specific pin exact package"),
            new CommandItem("pip uninstall package", "Remove a package", Keywords: "pip uninstall remove delete package"),
            new CommandItem("pip list", "List the packages you've installed", Keywords: "pip list installed packages show"),
            new CommandItem("pip show package", "Show details about a package", Keywords: "pip show details info package version"),
            new CommandItem("pip freeze", "List installed packages with exact versions", Keywords: "pip freeze list versions requirements export"),
            new CommandItem("pip freeze > requirements.txt", "Save your dependencies to requirements.txt", Keywords: "pip freeze requirements save export dependencies lock"),
            new CommandItem("pip check", "Check that installed packages are compatible", Keywords: "pip check verify compatible dependencies conflicts"),
            new CommandItem("python -m pip install --upgrade pip", "Update pip itself to the latest version", Keywords: "pip upgrade update self latest python module"),
        ]),
        new CommandCategory("Python", "Python", "python",
        [
            new CommandItem("python file.py", "Run a Python script", Keywords: "python run script execute py"),
            new CommandItem("python -m venv venv", "Create a virtual environment", Keywords: "venv virtual environment python isolate create"),
            new CommandItem(".\\venv\\Scripts\\Activate.ps1", "Turn on the virtual environment", Keywords: "activate venv virtual environment enable python"),
            new CommandItem("python -m http.server", "Start a simple local web server", Keywords: "python server http localhost serve web"),
        ]),
        new CommandCategory("Node", "Node", "node",
        [
            new CommandItem("node file.js", "Run a JavaScript file", Keywords: "node run javascript js execute"),
            new CommandItem("node --version", "Check which Node version is installed", Keywords: "node version check installed"),
            new CommandItem("npx tool", "Run a command-line tool without installing it", Keywords: "npx run tool once execute"),
        ]),
        new CommandCategory("Winget", "Winget", "store",
        [
            new CommandItem("winget install name", "Install an app or tool", Keywords: "winget install package app tool add"),
            new CommandItem("winget upgrade --all", "Update every app at once", Keywords: "winget upgrade update all apps newer"),
            new CommandItem("winget upgrade", "Update the apps you installed", Keywords: "winget upgrade update apps newer"),
            new CommandItem("winget list", "See what you've installed", Keywords: "winget list installed apps show"),
            new CommandItem("winget search name", "Search for an app", Keywords: "winget search find app lookup"),
        ]),
        new CommandCategory("Docker", "Docker", "docker",
        [
            new CommandItem("docker ps", "List running containers", Keywords: "docker containers running list ps"),
            new CommandItem("docker images", "List downloaded images", Keywords: "docker images list downloaded"),
            new CommandItem("docker compose up", "Start the services in this folder", Keywords: "docker compose services start up run"),
            new CommandItem("docker system prune -a", "Delete all unused containers and images", IsDangerous: true, Keywords: "docker prune clean delete remove cleanup unused"),
        ]),
        new CommandCategory("Environment", "Environment", "env",
        [
            new CommandItem("$env:PATH", "Show where the shell looks for commands", Keywords: "path environment variable lookup commands"),
            new CommandItem("$env:NAME = \"value\"", "Set an environment variable", Keywords: "environment variable set env"),
            new CommandItem("Get-ChildItem env:", "List all environment variables", Keywords: "env environment variables list show"),
            new CommandItem(". $PROFILE", "Reload your PowerShell profile", Keywords: "source reload profile settings refresh"),
        ]),
        new CommandCategory("Remote", "Remote", "remote",
        [
            new CommandItem("ssh user@host", "Connect to another machine", Keywords: "ssh remote connect login server shell"),
            new CommandItem("scp file user@host:/path", "Copy a file to another machine", Keywords: "scp copy transfer remote file secure upload"),
            new CommandItem("ssh-keygen", "Create an SSH key pair", Keywords: "ssh key keygen generate keypair authentication"),
        ]),
        new CommandCategory("Disk", "Disk", "disk",
        [
            new CommandItem("Get-PSDrive", "Show free space on each drive", Keywords: "disk free space storage available drive capacity"),
            new CommandItem("Get-Volume", "List drives and volumes", Keywords: "disk drives volumes list"),
        ]),
        new CommandCategory("Misc", "Misc", "more",
        [
            new CommandItem("Get-Date", "Show the current date and time", Keywords: "date time clock today now"),
            new CommandItem("Clear-Host", "Clear the screen", Keywords: "clear clean screen reset cls wipe"),
            new CommandItem("Get-History", "Show commands you've run before", Keywords: "history previous past commands recall"),
            new CommandItem("Set-Clipboard \"text\"", "Copy text to the clipboard", Keywords: "clipboard copy paste set"),
            new CommandItem("Get-Clipboard", "Paste text from the clipboard", Keywords: "clipboard paste get"),
        ]),
    ];
}
