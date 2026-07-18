export interface HelpCommandItem {
  command: string;
  detail: string;
  dangerous?: boolean;
  keywords?: string;
}

export interface HelpCategory {
  id: string;
  name: string;
  icon: string;
  commands: HelpCommandItem[];
}

export interface HelpSearchHit {
  category: HelpCategory;
  item: HelpCommandItem;
}

export interface CommandDefinition {
  command: string;
  description: string;
  category: string;
  keywords: string;
  dangerous?: boolean;
}

export const defaultEnabledHelpCategoryIds = [
  "Navigate", "Files", "GitHub", "AI", "Search", "System", "Network", "npm", "pip"
];

export const helpCategories: HelpCategory[] = [
  {
    id: "Navigate",
    name: "Navigate",
    icon: '<path d="M1.5 4a1 1 0 0 1 1-1h3l1.2 1.5H13.5a1 1 0 0 1 1 1v7a1 1 0 0 1-1 1h-11a1 1 0 0 1-1-1V4z"/>',
    commands: [
      { command: "ls", detail: "List files in the current folder", keywords: "list show files directory contents dir" },
      { command: "ls -la", detail: "List all files, including hidden ones, with details", keywords: "browse hidden folder contents long permissions dotfiles" },
      { command: "cd foldername", detail: "Go into a folder", keywords: "change directory enter open into go navigate move" },
      { command: "cd ..", detail: "Move up one folder", keywords: "back parent directory previous" },
      { command: "cd ~", detail: "Go to your home folder", keywords: "home reset user tilde" },
      { command: "pwd", detail: "Show the folder you are currently in", keywords: "location directory where current path print working" }
    ]
  },
  {
    id: "Files",
    name: "Files",
    icon: '<path d="M5.5 2.5h5l2 2v8a1 1 0 0 1-1 1h-6a1 1 0 0 1-1-1v-9a1 1 0 0 1 1-1z"/><path d="M3 5v8a1 1 0 0 0 1 1h5.5"/>',
    commands: [
      { command: "cat file.txt", detail: "Show a file's contents", keywords: "show print view read contents display concatenate output" },
      { command: "mkdir new-folder", detail: "Create a new folder", keywords: "directory make create new" },
      { command: "touch new-file.txt", detail: "Create an empty file", keywords: "make document new empty blank" },
      { command: "cp -r source destination", detail: "Copy a file or folder", keywords: "duplicate clone recursive" },
      { command: "mv old-name new-name", detail: "Move or rename something", keywords: "rename relocate move" },
      { command: "rm -i file", detail: "Delete a file after confirmation", dangerous: true, keywords: "remove delete erase trash" },
      { command: "rm -rf folder", detail: "Delete a folder and everything in it, permanently", dangerous: true, keywords: "remove delete recursive force folder directory erase wipe destroy" },
      { command: "xdg-open .", detail: "Open the current folder in your file manager", keywords: "open reveal folder gui files nautilus show" }
    ]
  },
  {
    id: "GitHub",
    name: "GitHub",
    icon: '<circle cx="4" cy="3.5" r="1.8"/><circle cx="4" cy="12.5" r="1.8"/><circle cx="12" cy="6.5" r="1.8"/><path d="M4 5.3V10.7M4 7c0 2 1.5 3 4 3h2.2M12 8.3V6.5"/>',
    commands: [
      { command: "git status", detail: "See changed files and repository state", keywords: "changes modified state diff version control" },
      { command: "git add -p", detail: "Choose changes to stage interactively", keywords: "stage select add index version control" },
      { command: "git commit -m \"message\"", detail: "Save a snapshot with a message", keywords: "commit save snapshot message record version control" },
      { command: "git diff", detail: "Review unstaged changes", keywords: "compare patch changes version control" },
      { command: "git log --oneline --graph -20", detail: "See recent commit history", keywords: "history commits recent past version control" },
      { command: "git switch -c new-branch", detail: "Create and switch to a branch", keywords: "checkout branch create version control" },
      { command: "git restore --staged file", detail: "Unstage a file without losing changes", keywords: "undo add unstage version control" },
      { command: "git push", detail: "Upload your commits to the remote", keywords: "upload push send publish remote sync version control" },
      { command: "git pull", detail: "Download the latest changes", keywords: "download pull fetch update sync remote version control" },
      { command: "git push --force", detail: "Overwrite the remote history — can erase others' work", dangerous: true, keywords: "force overwrite push rewrite history version control" }
    ]
  },
  {
    id: "AI",
    name: "AI",
    icon: '<path d="M8 1.5l1.1 3.4L12.5 6l-3.4 1.1L8 10.5l-1.1-3.4L3.5 6l3.4-1.1z"/><path d="M12.5 10l.6 1.9 1.9.6-1.9.6-.6 1.9-.6-1.9-1.9-.6 1.9-.6z"/>',
    commands: [
      { command: "claude", detail: "Start Claude Code in this folder", keywords: "claude ai code assistant anthropic start chat llm" },
      { command: "claude \"fix this bug\"", detail: "Start Claude Code with a request to work on", keywords: "claude ai request task prompt ask llm" },
      { command: "claude -p \"explain this code\"", detail: "Get a one-shot answer without the chat UI", keywords: "claude print oneshot one-shot query headless pipe ai llm" },
      { command: "claude --continue", detail: "Pick up your most recent conversation", keywords: "claude continue resume recent conversation last session ai" },
      { command: "claude --resume", detail: "Choose a past conversation to resume", keywords: "claude resume choose conversation past history session ai" },
      { command: "claude --dangerously-skip-permissions", detail: "Let Claude act without asking permission each time — fast, but it can change or delete files on its own. Use only when you trust the task.", dangerous: true, keywords: "claude yolo skip permissions dangerous auto unattended bypass ai" },
      { command: "claude mcp", detail: "Manage connected tools (MCP servers)", keywords: "claude mcp tools servers integrations connect ai" },
      { command: "claude update", detail: "Update Claude Code to the latest version", keywords: "claude update upgrade version latest ai" }
    ]
  },
  {
    id: "Search",
    name: "Search",
    icon: '<circle cx="6.5" cy="6.5" r="4"/><line x1="9.5" y1="9.5" x2="13.5" y2="13.5"/>',
    commands: [
      { command: "rg 'text'", detail: "Search file contents quickly with ripgrep", keywords: "grep text code find search match contains lookup" },
      { command: "grep -rn 'text' .", detail: "Search every file in this folder", keywords: "grep recursive text find search match contains lookup" },
      { command: "find . -iname '*name*'", detail: "Find files by name below this folder", keywords: "locate filename find files search lookup" },
      { command: "command -v program", detail: "Check where a program is installed", keywords: "which where path missing command find locate" }
    ]
  },
  {
    id: "System",
    name: "System",
    icon: '<circle cx="8" cy="8.5" r="6"/><path d="M8 8.5L10.8 5.7"/><path d="M5 8.5h.01M8 3.5v.01M11 8.5h.01"/>',
    commands: [
      { command: "top", detail: "Live view of running programs", keywords: "processes activity monitor cpu memory running performance" },
      { command: "df -h", detail: "Check free disk space", keywords: "storage drive full free available capacity" },
      { command: "free -h", detail: "Check memory usage", keywords: "ram memory available" },
      { command: "du -sh * | sort -h", detail: "Compare folder sizes", keywords: "storage large files size how big space" },
      { command: "journalctl -xe", detail: "Review recent system service errors", keywords: "logs failure systemd errors service" },
      { command: "uptime", detail: "See how long the system has been on", keywords: "uptime how long running load boot" },
      { command: "whoami", detail: "Show your username", keywords: "user username who identity account" }
    ]
  },
  {
    id: "Network",
    name: "Network",
    icon: '<circle cx="8" cy="8" r="6"/><path d="M2 8h12M8 2c1.8 1.7 1.8 10.3 0 12M8 2c-1.8 1.7-1.8 10.3 0 12"/>',
    commands: [
      { command: "ip address", detail: "Show network addresses", keywords: "wifi ethernet ip local network ipconfig address" },
      { command: "ping example.com", detail: "Check if a site is reachable", keywords: "ping reachable connection network test online latency" },
      { command: "curl -I https://example.com", detail: "Check whether a website responds", keywords: "http headers website curl fetch request" },
      { command: "curl -O https://example.com/file", detail: "Download a file from a URL", keywords: "download curl file url save get fetch" },
      { command: "ss -tulpn", detail: "Show programs listening on network ports", keywords: "port server process listening socket" }
    ]
  },
  {
    id: "Permissions",
    name: "Permissions",
    icon: '<rect x="3.5" y="7" width="9" height="6.5" rx="1.2"/><path d="M5.5 7V4.8a2.5 2.5 0 0 1 5 0V7"/>',
    commands: [
      { command: "ls -l", detail: "See who can read or change each file", keywords: "permissions owner access rights list mode" },
      { command: "chmod +x script.sh", detail: "Make a script runnable", keywords: "executable run permission chmod script allow" },
      { command: "sudo command", detail: "Run a command as administrator", dangerous: true, keywords: "admin root superuser administrator privilege sudo elevated" },
      { command: "chmod 777 file", detail: "Let anyone read, write, and run a file — rarely a good idea", dangerous: true, keywords: "permissions chmod all access open insecure mode" }
    ]
  },
  {
    id: "Processes",
    name: "Processes",
    icon: '<rect x="4" y="4" width="8" height="8" rx="1"/><path d="M6.5 1.5v2.5M9.5 1.5v2.5M6.5 12v2.5M9.5 12v2.5M1.5 6.5H4M1.5 9.5H4M12 6.5h2.5M12 9.5h2.5"/>',
    commands: [
      { command: "ps aux --sort=-%mem | head", detail: "Show processes using the most memory", keywords: "tasks performance ram processes running list ps" },
      { command: "jobs", detail: "List programs running in this terminal", keywords: "jobs background running tasks" },
      { command: "kill -15 PID", detail: "Ask a process to stop safely", keywords: "quit process kill stop terminate end signal" },
      { command: "kill -9 PID", detail: "Force a process to stop immediately", dangerous: true, keywords: "kill force stop terminate end process signal sigkill" },
      { command: "killall name", detail: "Stop every program with this name", dangerous: true, keywords: "kill stop terminate all process name quit force" }
    ]
  },
  {
    id: "Archives",
    name: "Archives",
    icon: '<path d="M1.5 5l1-2.5h11l1 2.5"/><rect x="1.5" y="5" width="13" height="9" rx="1"/><line x1="6.3" y1="8" x2="9.7" y2="8"/>',
    commands: [
      { command: "zip -r archive.zip folder", detail: "Zip up a folder", keywords: "zip compress archive folder package bundle" },
      { command: "unzip archive.zip", detail: "Extract a .zip file", keywords: "unzip extract decompress zip unpack open" },
      { command: "tar -czf archive.tar.gz folder", detail: "Make a compressed .tar.gz", keywords: "tar compress archive gzip tarball package backup" },
      { command: "tar -xzf archive.tar.gz", detail: "Extract a .tar.gz", keywords: "tar extract decompress unpack gzip unzip open" }
    ]
  },
  {
    id: "Text",
    name: "Text",
    icon: '<line x1="2" y1="4" x2="14" y2="4"/><line x1="2" y1="8" x2="11" y2="8"/><line x1="2" y1="12" x2="13" y2="12"/>',
    commands: [
      { command: "echo \"hello\"", detail: "Print some text", keywords: "echo print output text display say" },
      { command: "head file.txt", detail: "Show the first lines of a file", keywords: "head first top lines beginning preview" },
      { command: "tail file.txt", detail: "Show the last lines of a file", keywords: "tail last end lines bottom" },
      { command: "tail -f log.txt", detail: "Watch a file update live", keywords: "follow watch live log monitor tail stream" },
      { command: "wc -l file.txt", detail: "Count the lines in a file", keywords: "count lines words characters wc total" },
      { command: "sort file.txt", detail: "Sort lines alphabetically", keywords: "sort order alphabetical arrange organize" }
    ]
  },
  {
    id: "Editors",
    name: "Editors",
    icon: '<path d="M10.5 2.5l3 3-8 8-3.5.5.5-3.5z"/>',
    commands: [
      { command: "nano file.txt", detail: "Edit a file with a simple editor", keywords: "edit editor nano text simple write modify" },
      { command: "vim file.txt", detail: "Edit a file with Vim", keywords: "edit editor vim vi text write modify" },
      { command: "code .", detail: "Open this folder in VS Code", keywords: "vscode vs code editor open ide" },
      { command: "xdg-open file.txt", detail: "Open a file in your default editor", keywords: "open edit gui default application write" }
    ]
  },
  {
    id: "npm",
    name: "npm",
    icon: '<path d="M8 1.5l6 3.2v6.6L8 14.5l-6-3.2V4.7z"/><path d="M2 4.7L8 8l6-3.3M8 8v6.5"/>',
    commands: [
      { command: "npm install", detail: "Install all dependencies listed in package.json", keywords: "npm install dependencies packages node modules setup i" },
      { command: "npm install package", detail: "Add a package to your project", keywords: "npm install add package dependency library i" },
      { command: "npm install -g package", detail: "Install a package globally (available everywhere)", keywords: "npm install global system-wide tool cli -g" },
      { command: "npm install --save-dev package", detail: "Add a development-only dependency", keywords: "npm install dev devdependency save-dev -D testing build tooling" },
      { command: "npm uninstall package", detail: "Remove a package from your project", keywords: "npm uninstall remove delete package dependency" },
      { command: "npm update", detail: "Update packages to their latest allowed versions", keywords: "npm update upgrade packages latest" },
      { command: "npm outdated", detail: "See which packages have newer versions", keywords: "npm outdated old updates versions check" },
      { command: "npm run dev", detail: "Start the development server", keywords: "npm run dev server development localhost start" },
      { command: "npm run build", detail: "Build the project for production", keywords: "npm run build production compile bundle" },
      { command: "npm start", detail: "Run the project", keywords: "npm start run launch node" },
      { command: "npm test", detail: "Run the project's tests", keywords: "npm test tests testing check run" },
      { command: "npm run script", detail: "Run a script defined in package.json", keywords: "npm run script task command package.json" },
      { command: "npm init -y", detail: "Create a new package.json with default settings", keywords: "npm init create package.json new project setup" },
      { command: "npm ci", detail: "Clean install exactly from package-lock.json", keywords: "npm ci clean install lockfile reproducible reliable" },
      { command: "npm list", detail: "Show the packages you've installed", keywords: "npm list ls installed packages dependencies show" },
      { command: "npm audit", detail: "Check dependencies for security issues", keywords: "npm audit security vulnerabilities check safety" },
      { command: "npm audit fix", detail: "Automatically fix vulnerable dependencies", keywords: "npm audit fix security vulnerabilities repair" },
      { command: "npm cache clean --force", detail: "Clear npm's cache when things act up", keywords: "npm cache clean clear reset force fix" },
      { command: "npx create-vite", detail: "Run a tool once without installing it", keywords: "npx scaffold create run vite generator bootstrap" }
    ]
  },
  {
    id: "pip",
    name: "pip",
    icon: '<path d="M8 1.5l5.5 3.2v6.6L8 14.5l-5.5-3.2V4.7z"/><path d="M8 8v6.5M2.5 4.7L8 8l5.5-3.3"/>',
    commands: [
      { command: "pip install package", detail: "Install a Python package", keywords: "pip install package python dependency module library add" },
      { command: "pip install -r requirements.txt", detail: "Install everything listed in requirements.txt", keywords: "pip install requirements dependencies all batch file" },
      { command: "pip install --upgrade package", detail: "Upgrade a package to the latest version", keywords: "pip install upgrade update latest newer package -U" },
      { command: "pip install package==1.2.3", detail: "Install a specific version of a package", keywords: "pip install version specific pin exact package" },
      { command: "pip uninstall package", detail: "Remove a package", keywords: "pip uninstall remove delete package" },
      { command: "pip list", detail: "List the packages you've installed", keywords: "pip list installed packages show" },
      { command: "pip show package", detail: "Show details about a package", keywords: "pip show details info package version" },
      { command: "pip freeze", detail: "List installed packages with exact versions", keywords: "pip freeze list versions requirements export" },
      { command: "pip freeze > requirements.txt", detail: "Save your dependencies to requirements.txt", keywords: "pip freeze requirements save export dependencies lock" },
      { command: "pip check", detail: "Check that installed packages are compatible", keywords: "pip check verify compatible dependencies conflicts" },
      { command: "python3 -m pip install --upgrade pip", detail: "Update pip itself to the latest version", keywords: "pip upgrade update self latest python module" },
      { command: "pip cache purge", detail: "Clear pip's download cache", keywords: "pip cache purge clear clean reset" }
    ]
  },
  {
    id: "Python",
    name: "Python",
    icon: '<path d="M5.5 3.5L1.5 8l4 4.5M10.5 3.5l4 4.5-4 4.5"/>',
    commands: [
      { command: "python3 file.py", detail: "Run a Python script", keywords: "python run script execute py" },
      { command: "python3 -m venv venv", detail: "Create a virtual environment", keywords: "venv virtual environment python isolate create" },
      { command: "source venv/bin/activate", detail: "Turn on the virtual environment", keywords: "activate venv virtual environment enable source python" },
      { command: "python3 -m http.server", detail: "Start a simple local web server", keywords: "python server http localhost serve web" }
    ]
  },
  {
    id: "Node",
    name: "Node",
    icon: '<path d="M8 1.5l6 3.5v6l-6 3.5-6-3.5v-6z"/>',
    commands: [
      { command: "node file.js", detail: "Run a JavaScript file", keywords: "node run javascript js execute" },
      { command: "node --version", detail: "Check which Node version is installed", keywords: "node version check installed" },
      { command: "npx tool", detail: "Run a command-line tool without installing it", keywords: "npx run tool once execute" }
    ]
  },
  {
    id: "Packages",
    name: "Packages",
    icon: '<path d="M8 1.5v7.5M8 9l-2.5-2.5M8 9l2.5-2.5"/><path d="M2 9.5v3.5a1 1 0 0 0 1 1h10a1 1 0 0 0 1-1V9.5"/>',
    commands: [
      { command: "sudo apt install name", detail: "Install an app or tool", keywords: "apt install package app tool add dnf yum pacman software" },
      { command: "sudo apt update", detail: "Refresh the list of available packages", keywords: "apt update refresh catalog dnf yum pacman" },
      { command: "sudo apt upgrade", detail: "Update everything you've installed", keywords: "apt upgrade update packages newer dnf yum pacman" },
      { command: "apt list --installed", detail: "See what you've installed", keywords: "apt list installed packages show dnf yum pacman" },
      { command: "apt search name", detail: "Search for a package", keywords: "apt search find package lookup dnf yum pacman" }
    ]
  },
  {
    id: "Docker",
    name: "Docker",
    icon: '<rect x="1.5" y="6.5" width="4" height="4" rx="0.5"/><rect x="6" y="6.5" width="4" height="4" rx="0.5"/><rect x="3.75" y="2.5" width="4" height="4" rx="0.5"/><path d="M10.5 8.5c1.5 0 3.2.8 3.7 2.3.3.9-.2 1.7-1.2 1.7H8"/>',
    commands: [
      { command: "docker ps", detail: "List running containers", keywords: "docker containers running list ps" },
      { command: "docker images", detail: "List downloaded images", keywords: "docker images list downloaded" },
      { command: "docker compose up", detail: "Start the services in this folder", keywords: "docker compose services start up run" },
      { command: "docker system prune -a", detail: "Delete all unused containers and images", dangerous: true, keywords: "docker prune clean delete remove cleanup unused" }
    ]
  },
  {
    id: "Environment",
    name: "Environment",
    icon: '<circle cx="8" cy="8" r="2.2"/><path d="M8 2v1.6M8 12.4V14M14 8h-1.6M3.6 8H2M12.1 3.9l-1.1 1.1M5 9.9l-1.1 1.1M12.1 12.1l-1.1-1.1M5 6.1L3.9 5"/>',
    commands: [
      { command: "echo $PATH", detail: "Show where the shell looks for commands", keywords: "path environment variable lookup commands" },
      { command: "export NAME=value", detail: "Set an environment variable", keywords: "export environment variable set env" },
      { command: "env", detail: "List all environment variables", keywords: "env environment variables list show" },
      { command: "source ~/.bashrc", detail: "Reload your shell settings (or ~/.zshrc if you use zsh)", keywords: "source reload shell config bashrc zshrc settings refresh" }
    ]
  },
  {
    id: "Remote",
    name: "Remote",
    icon: '<circle cx="8" cy="8" r="1.4"/><path d="M5.3 5.3a3.8 3.8 0 0 0 0 5.4M10.7 5.3a3.8 3.8 0 0 1 0 5.4M3 3a7.5 7.5 0 0 0 0 10M13 3a7.5 7.5 0 0 1 0 10"/>',
    commands: [
      { command: "ssh user@host", detail: "Connect to another machine", keywords: "ssh remote connect login server shell" },
      { command: "scp file user@host:/path", detail: "Copy a file to another machine", keywords: "scp copy transfer remote file secure upload" },
      { command: "ssh-keygen", detail: "Create an SSH key pair", keywords: "ssh key keygen generate keypair authentication" }
    ]
  },
  {
    id: "Disk",
    name: "Disk",
    icon: '<rect x="1.5" y="3.5" width="13" height="9" rx="1.2"/><line x1="1.5" y1="9.5" x2="14.5" y2="9.5"/><circle cx="11.7" cy="11" r="0.6" fill="currentColor" stroke="none"/>',
    commands: [
      { command: "df -h", detail: "Show free space on each drive", keywords: "disk free space storage available drive capacity" },
      { command: "du -sh *", detail: "Show how big each item here is", keywords: "size disk usage folder how big space" },
      { command: "lsblk", detail: "List drives and partitions", keywords: "disk drives partitions lsblk list volumes block" }
    ]
  },
  {
    id: "Misc",
    name: "Misc",
    icon: '<circle cx="8" cy="8" r="6"/><circle cx="5.3" cy="8" r="0.7" fill="currentColor" stroke="none"/><circle cx="8" cy="8" r="0.7" fill="currentColor" stroke="none"/><circle cx="10.7" cy="8" r="0.7" fill="currentColor" stroke="none"/>',
    commands: [
      { command: "date", detail: "Show the current date and time", keywords: "date time clock today now" },
      { command: "cal", detail: "Show a calendar", keywords: "calendar cal month dates" },
      { command: "history | tail -30", detail: "See your recent commands", keywords: "history previous past commands recall" },
      { command: "xclip -selection clipboard < file.txt", detail: "Copy a file's contents to the clipboard (use wl-copy on Wayland)", keywords: "clipboard copy xclip wl-copy wayland paste" },
      { command: "clear", detail: "Clear the screen", keywords: "clear clean screen reset cls wipe" }
    ]
  }
];

export const commandCatalog: CommandDefinition[] = helpCategories.flatMap((category) =>
  category.commands.map((item) => ({
    command: item.command,
    description: item.detail,
    category: category.name,
    keywords: item.keywords ?? "",
    ...(item.dangerous ? { dangerous: true as const } : {})
  }))
);

export function searchCommands(query: string): CommandDefinition[] {
  const normalizedQuery = query.trim().toLocaleLowerCase();
  if (normalizedQuery.length === 0) {
    return commandCatalog;
  }
  return commandCatalog.filter((item) =>
    `${item.category} ${item.command} ${item.description} ${item.keywords}`.toLocaleLowerCase().includes(normalizedQuery)
  );
}

export function searchHelpCatalog(query: string): HelpSearchHit[] {
  const normalizedQuery = query.trim().toLocaleLowerCase();
  if (normalizedQuery.length === 0) {
    return [];
  }
  const hits: HelpSearchHit[] = [];
  for (const category of helpCategories) {
    const categoryMatches = category.name.toLocaleLowerCase().includes(normalizedQuery);
    for (const item of category.commands) {
      if (
        categoryMatches ||
        item.command.toLocaleLowerCase().includes(normalizedQuery) ||
        item.detail.toLocaleLowerCase().includes(normalizedQuery) ||
        (item.keywords ?? "").toLocaleLowerCase().includes(normalizedQuery)
      ) {
        hits.push({ category, item });
      }
    }
  }
  return hits;
}
