# FriendlyTerminal

A friendlier terminal for macOS and Windows. FriendlyTerminal wraps a real shell
(zsh on macOS, PowerShell on Windows) in a native app that adds command "blocks"
(each command and its output grouped together), a file sidebar and breadcrumb
navigation, a built-in command help menu, first-class support for interactive
programs (vim, less, top, man, Claude Code...), split panes, undo for common
commands, and, on macOS, optional on-device AI for translating plain English
into commands and explaining errors.

## Install

### macOS

**No coding required.** Just download the app:

1. Go to the **[Releases page](https://github.com/aaditaggarwal26/friendlyterminal/releases/latest)**
   and download **`FriendlyTerminal.dmg`**.
2. Open the downloaded file and drag **FriendlyTerminal** into your **Applications** folder.
3. The first time you open it, **right-click** (or Control-click) the app icon and
   choose **Open**, then click **Open** in the dialog that appears.

> **Why the right-click the first time?** macOS shows a warning for apps that
> aren't signed by a paid Apple Developer account. Right-click, then Open tells
> macOS you trust it. You only have to do this once; after that it opens with a
> normal double-click.

### Windows

There's no prebuilt installer yet, so for now you build it from source (see
[Building from source](#building-from-source-for-developers) below). A packaged
release is planned.

## Features

- **Command blocks** - each command and its output are grouped, with exit status,
  so scrollback reads like a transcript instead of a wall of text. Failed
  commands are marked, and any block can be collapsed, copied, or re-run.
- **Clickable output** - listings become buttons: `ls` shows your files as chips
  that fill in `cd` or open the file, `git log --oneline` offers `git show`,
  `git status` offers `git add`, and so on. JSON renders as a collapsible tree,
  CSV and column output as tables.
- **File sidebar & breadcrumbs** - browse the current directory and jump around
  the filesystem by clicking. The sidebar can rename, reveal, and trash files.
- **Undo** - `rm` is quietly rerouted to the Trash (Recycle Bin on Windows) so
  it can be undone, and commands like `mkdir`, `cp`, `mv`, `git add`, and
  `git commit` get an Undo button on their block.
- **Interactive program support** - full-screen TUIs (vim, less, top, htop, man,
  nano) and raw-mode inline programs (Claude Code, REPLs) work correctly. While
  one is running, the sidebar shows what the program is and one-tap buttons for
  getting out of it.
- **Claude Code integration** - a toolbar button starts or resumes a session, a
  setup checker verifies Node, the CLI, and login, and while Claude runs the
  sidebar becomes a control panel (pick options 1-4, Enter, Stop, slash commands).
- **Source control & processes** - a mini Git panel to stage, commit, and push
  without memorizing commands, and a "What's Running" panel listing everything
  listening on a port, with one-click open-in-browser or kill.
- **Command help menu** - a built-in cheat sheet of ~20 categories (Navigate,
  Files, GitHub, AI, Search, System, Network...), each listing common commands.
  Dangerous commands are flagged, and you can choose which categories to show.
- **Project commands** - the sidebar detects your project type (npm scripts,
  Python, Rust, Go, Make, Docker...) and offers its usual commands as buttons.
- **Split panes** - open up to six terminals side by side; keyboard input follows
  the focused pane.
- **Get-started tutorial and welcome tour** - a dismissible in-app guide for
  newcomers, plus a short first-launch tour of the interface.
- **On-device AI (macOS only, optional)** - on supported hardware, translate
  natural language into shell commands and get plain-English explanations of
  errors, powered by Apple's on-device Foundation Models. No data leaves your
  machine. There is no Windows equivalent of this feature.

## System requirements

### macOS

- **macOS 15.0 (Sequoia) or later** to run the app.
- **macOS 26 (Tahoe) or later with Apple Intelligence enabled** for the optional
  AI features. Everything else works without them.

### Windows

- **Windows 10 version 1809 (build 17763) or later**; Windows 11 recommended.
- The **WebView2 runtime**, which is preinstalled on Windows 11 and most
  up-to-date Windows 10 machines.

---

## Building from source (for developers)

You only need this section if you want to modify the code or build it yourself.

### macOS

Requirements:

- **Xcode 16** (Swift 6 toolchain).
- **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** - the Xcode project is
  generated from `project.yml` and is intentionally not checked into git:
  ```sh
  brew install xcodegen
  ```
  SwiftTerm (the terminal emulator) is fetched automatically by Swift Package
  Manager when you build.

Clone the repo and run the packaging script, which generates the project, builds
a Release app, and produces `build/FriendlyTerminal.dmg`:

```sh
git clone https://github.com/aaditaggarwal26/friendlyterminal.git
cd friendlyterminal
./scripts/build-and-package.sh
```

To work on the code interactively, generate the project and open it (re-run
`xcodegen generate` whenever `project.yml` changes), then press Cmd+R:

```sh
xcodegen generate
open FriendlyTerminal.xcodeproj
```

### Windows

Requirements:

- **.NET 8 SDK**.
- **Visual Studio 2022 or later** (or the Build Tools) with the
  **Windows App SDK / WinUI** workload. The app project needs MSBuild from
  Visual Studio; a plain `dotnet build` can't package WinUI apps.

The shared logic (`FriendlyTerminal.Core`) has no Windows dependencies, so its
tests run anywhere the .NET SDK does, including macOS:

```sh
cd windows
dotnet test
```

To build and run the app itself, open `windows\FriendlyTerminal.sln` in Visual
Studio and run the `FriendlyTerminal.App` project (x64), or from a developer
prompt:

```sh
cd windows\app\FriendlyTerminal.App
msbuild FriendlyTerminal.App.csproj -restore -p:Platform=x64 -p:Configuration=Debug
```

The executable lands in `bin\x64\Debug\net8.0-windows10.0.19041.0\FriendlyTerminal.App.exe`.

### Cutting a release (macOS)

Pushing a version tag triggers the GitHub Actions workflow in
`.github/workflows/release.yml`, which builds the macOS app and attaches a
downloadable `.dmg` to a new GitHub Release:

```sh
git tag v1.0.0
git push origin v1.0.0
```

### Project structure

- `FriendlyTerminal/App/` - SwiftUI views and the AppKit terminal bridge (macOS).
- `FriendlyTerminal/Models/` - session, workspace, block-store, and the
  shell-integration parser (macOS).
- `FriendlyTerminal/AIKit/` - the optional on-device AI layer (gated to macOS 26).
- `windows/src/FriendlyTerminal.Core/` - shared headless logic for the Windows
  app: shell-integration parsing, output detectors, undo rules, help catalog.
  Plain `net8.0`, fully unit-tested, no UI dependencies.
- `windows/app/FriendlyTerminal.App/` - the WinUI 3 app: ConPTY backend,
  xterm.js terminal host in WebView2, blocks UI, sidebar, and panels.
- `windows/tests/` - tests for the Core library.
- `docs/behavior-spec/` - the platform-neutral spec both apps implement.
- `project.yml` - the XcodeGen spec the `.xcodeproj` is generated from.

### How it works

FriendlyTerminal spawns a normal shell (a login zsh on macOS, PowerShell in a
ConPTY on Windows) and sources a small shell-integration profile that emits
standard OSC escape sequences: `133;A/B/C/D` for prompt/command/output/exit,
`633;E` for the command text, and the working directory via OSC 7 or 9;9. The
app parses those out of the PTY stream to build command blocks and track the
cwd, while the raw bytes still flow to the terminal emulator (SwiftTerm on
macOS, xterm.js on Windows) for rendering. Interactive programs are detected
from the alternate-screen (`?1049h`) and bracketed-paste (`?2004h`) mode
switches, so the UI knows when to hand the keyboard straight to the running
program.

## License

Released under the [GNU General Public License v3.0](LICENSE).
