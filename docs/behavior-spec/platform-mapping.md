# Platform mapping

Every place the macOS app touches the OS, and its Windows equivalent. This is the
checklist of platform-injected dependencies the `FriendlyTerminal.Core` library
must abstract behind interfaces so the logic stays portable and testable.

| Concern | macOS | Linux | Windows |
| --- | --- | --- | --- |
| UI framework | SwiftUI + AppKit | Electron + TypeScript | WinUI 3 + C# |
| Terminal widget | SwiftTerm | xterm.js | xterm.js in WebView2 |
| PTY / process | SwiftTerm local process | node-pty | ConPTY pseudo-console |
| Default shell | zsh | user `$SHELL` | PowerShell |
| Shell integration | zsh OSC profile | bash/zsh OSC profiles | PowerShell OSC profile |
| Delete → recoverable | macOS Trash | desktop trash planned | Recycle Bin |
| Restore a delete | move from Trash | planned | Recycle Bin restore |
| List a directory | `FileManager` | main-process `fs` | `System.IO.Directory` |
| Open a file/folder | `open` | Electron `shell.openPath` | `Invoke-Item` / Explorer |
| Run git | `/usr/bin/git` | `git` subprocess | `git.exe` |
| Process / port monitor | `ps` / `lsof` | planned | PowerShell process APIs |
| Package manager | Homebrew | distribution-specific | winget or scoop |
| Path quoting | POSIX single-quote | POSIX single-quote | PowerShell quoting |
| On-device AI | FoundationModels | none | none |
| Project build | xcodegen + xcodebuild | npm + esbuild | .NET / MSBuild |
| Packaging | `.dmg` | AppImage, `.deb`, `.rpm` | Inno Setup `.exe`, portable `.zip` |
| Release CI | `macos-26` | `ubuntu-24.04` | `windows-latest` |

## Interfaces the Core should expose (so logic is testable on macOS)

- `IFileSystem` — exists/isDirectory/list/trash/restore. (Detectors and the undo
  planner depend only on this, never on real OS calls in tests.)
- `IShellQuoter` — quote a path/argument for the target shell.
- `IShellRunner` — run an inverse command (undo's `shell` action).
- `IClock` / ambient — only where needed.

Everything in `FriendlyTerminal.Core` (detectors, undo planner, help catalog,
block/marker parser) takes these as constructor dependencies. The real
implementations live in the Windows app; fakes live in the test project.
