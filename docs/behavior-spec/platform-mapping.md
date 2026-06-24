# Platform mapping

Every place the macOS app touches the OS, and its Windows equivalent. This is the
checklist of platform-injected dependencies the `FriendlyTerminal.Core` library
must abstract behind interfaces so the logic stays portable and testable.

| Concern | macOS (current) | Windows (planned) |
| --- | --- | --- |
| UI framework | SwiftUI + AppKit | WinUI 3 + C# |
| Terminal widget | SwiftTerm (`LocalProcessTerminalView`) | xterm.js in WebView2 |
| PTY / process | fork zsh via SwiftTerm | ConPTY pseudo-console |
| Default shell | zsh | PowerShell (WSL/bash later) |
| Shell integration | zsh script emitting OSC 133/633/7 | PowerShell profile emitting OSC 133 + cwd |
| Delete → recoverable | `FileManager.trashItem` | Recycle Bin (`Microsoft.VisualBasic.FileIO`) |
| Restore a delete | move back from Trash | Recycle Bin restore (shell API) |
| List a directory | `FileManager.contentsOfDirectory` | `System.IO.Directory` |
| Open a file/folder | `open` | `Invoke-Item` / `start` / `explorer` |
| Run git | `Process` → `/usr/bin/git` | `Process` → `git.exe` |
| Process / port monitor | `ps` / `lsof` | `Get-Process` / `Get-NetTCPConnection` |
| Package manager (help+undo) | Homebrew (`brew`) | winget or scoop |
| Path quoting | POSIX single-quote | PowerShell quoting rules |
| On-device AI | FoundationModels (Apple Intelligence) | Anthropic API; Phi Silica on Copilot+ |
| Project build | xcodegen + xcodebuild | `dotnet` / MSBuild (WinUI) |
| Packaging | ad-hoc signed `.dmg` | MSIX + winget; code-signing cert |
| Release CI | GitHub Actions `macos-26` | GitHub Actions `windows-latest` |

## Interfaces the Core should expose (so logic is testable on macOS)

- `IFileSystem` — exists/isDirectory/list/trash/restore. (Detectors and the undo
  planner depend only on this, never on real OS calls in tests.)
- `IShellQuoter` — quote a path/argument for the target shell.
- `IShellRunner` — run an inverse command (undo's `shell` action).
- `IClock` / ambient — only where needed.

Everything in `FriendlyTerminal.Core` (detectors, undo planner, help catalog,
block/marker parser) takes these as constructor dependencies. The real
implementations live in the Windows app; fakes live in the test project.
