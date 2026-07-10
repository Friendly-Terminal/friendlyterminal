export interface CommandDefinition {
  command: string;
  description: string;
  category: string;
  keywords: string;
  dangerous?: boolean;
}

export const commandCatalog: CommandDefinition[] = [
  { command: "pwd", description: "Show the folder you are currently in", category: "Navigate", keywords: "location directory where" },
  { command: "ls -la", description: "List all files with details", category: "Navigate", keywords: "browse hidden folder contents" },
  { command: "cd ..", description: "Move up one folder", category: "Navigate", keywords: "back parent directory" },
  { command: "cd ~", description: "Go to your home folder", category: "Navigate", keywords: "home reset" },
  { command: "mkdir new-folder", description: "Create a new folder", category: "Files", keywords: "directory make" },
  { command: "touch new-file.txt", description: "Create an empty file", category: "Files", keywords: "make document" },
  { command: "cp -r source destination", description: "Copy a file or folder", category: "Files", keywords: "duplicate" },
  { command: "mv old-name new-name", description: "Move or rename something", category: "Files", keywords: "rename relocate" },
  { command: "rm -i file", description: "Delete a file after confirmation", category: "Files", keywords: "remove trash", dangerous: true },
  { command: "find . -iname '*name*'", description: "Find files by name below this folder", category: "Search", keywords: "locate filename" },
  { command: "rg 'text'", description: "Search file contents quickly with ripgrep", category: "Search", keywords: "grep text code" },
  { command: "git status", description: "See changed files and repository state", category: "Git", keywords: "changes modified" },
  { command: "git diff", description: "Review unstaged changes", category: "Git", keywords: "compare patch" },
  { command: "git add -p", description: "Choose changes to stage interactively", category: "Git", keywords: "stage select" },
  { command: "git log --oneline --graph -20", description: "See recent commit history", category: "Git", keywords: "history commits" },
  { command: "git switch -c new-branch", description: "Create and switch to a branch", category: "Git", keywords: "checkout branch" },
  { command: "git restore --staged file", description: "Unstage a file without losing changes", category: "Git", keywords: "undo add" },
  { command: "ps aux --sort=-%mem | head", description: "Show processes using the most memory", category: "System", keywords: "tasks performance ram" },
  { command: "df -h", description: "Check free disk space", category: "System", keywords: "storage drive full" },
  { command: "free -h", description: "Check memory usage", category: "System", keywords: "ram" },
  { command: "du -sh * | sort -h", description: "Compare folder sizes", category: "System", keywords: "storage large files" },
  { command: "kill -15 PID", description: "Ask a process to stop safely", category: "System", keywords: "quit process" },
  { command: "ip address", description: "Show network addresses", category: "Network", keywords: "wifi ethernet ip" },
  { command: "curl -I https://example.com", description: "Check whether a website responds", category: "Network", keywords: "http headers website" },
  { command: "ss -tulpn", description: "Show programs listening on network ports", category: "Network", keywords: "port server process" },
  { command: "tar -czf archive.tar.gz folder", description: "Compress a folder", category: "Archives", keywords: "zip backup" },
  { command: "tar -xzf archive.tar.gz", description: "Extract a compressed archive", category: "Archives", keywords: "unzip unpack" },
  { command: "python3 -m http.server", description: "Serve this folder on a local web server", category: "Development", keywords: "localhost website" },
  { command: "npm run dev", description: "Start a JavaScript development server", category: "Development", keywords: "node frontend" },
  { command: "docker compose up", description: "Start services from a Compose file", category: "Development", keywords: "containers" },
  { command: "journalctl -xe", description: "Review recent system service errors", category: "Troubleshoot", keywords: "logs failure systemd" },
  { command: "command -v program", description: "Check where a program is installed", category: "Troubleshoot", keywords: "which path missing" },
  { command: "history | tail -30", description: "See your recent commands", category: "Troubleshoot", keywords: "past previous" }
];

export function searchCommands(query: string): CommandDefinition[] {
  const normalizedQuery = query.trim().toLocaleLowerCase();
  if (normalizedQuery.length === 0) {
    return commandCatalog;
  }
  return commandCatalog.filter((item) =>
    `${item.category} ${item.command} ${item.description} ${item.keywords}`.toLocaleLowerCase().includes(normalizedQuery)
  );
}
