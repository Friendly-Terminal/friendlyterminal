# FriendlyTerminal

A friendlier macOS terminal. FriendlyTerminal wraps a real zsh shell in a native
SwiftUI app that adds command "blocks" (each command and its output grouped
together), a file sidebar and breadcrumb navigation, a built-in command help menu,
first-class support for interactive programs (vim, less, top, man, Claude Code…),
split panes, and optional on-device AI for translating plain English into commands
and explaining errors.

## Install

**No coding required.** Just download the app:

1. Go to the **[Releases page](https://github.com/aaditaggarwal26/friendlyterminal/releases/latest)**
   and download **`FriendlyTerminal.dmg`**.
2. Open the downloaded file and drag **FriendlyTerminal** into your **Applications** folder.
3. The first time you open it, **right-click** (or Control-click) the app icon and
   choose **Open**, then click **Open** in the dialog that appears.

> **Why the right-click the first time?** macOS shows a warning for apps that
> aren't signed by a paid Apple Developer account. Right-click → Open tells macOS
> you trust it. You only have to do this once; after that it opens with a normal
> double-click.

That's it — no terminal commands, no Xcode.

## Features

- **Command blocks** — each command and its output are grouped, with exit status,
  so scrollback reads like a transcript instead of a wall of text.
- **File sidebar & breadcrumbs** — browse the current directory and jump around
  the filesystem by clicking.
- **Interactive program support** — full-screen TUIs (vim, less, top, htop, man,
  nano) and raw-mode inline programs (Claude Code, REPLs) work correctly,
  including arrow keys and two-finger / scroll-wheel scrolling.
- **Command help menu** — a built-in cheat sheet of ~20 categories (Navigate,
  Files, GitHub, AI, Search, System, Network…), each listing common commands.
  Dangerous commands are flagged, and you can choose which categories to show.
- **Split panes** — open up to six terminals side by side; keyboard input follows
  the focused pane.
- **Get-started tutorial** — a dismissible in-app guide for newcomers.
- **On-device AI (optional)** — on supported hardware, translate natural language
  into shell commands and get plain-English explanations of errors, powered by
  Apple's on-device Foundation Models. No data leaves your machine.

## System requirements

- **macOS 15.0 (Sequoia) or later** to run the app.
- **macOS 26 (Tahoe) or later with Apple Intelligence enabled** for the optional
  AI features. Everything else works without them.

---

## Building from source (for developers)

You only need this section if you want to modify the code or build it yourself.

### Requirements

- **Xcode 16** (Swift 6 toolchain).
- **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** — the Xcode project is
  generated from `project.yml` and is intentionally not checked into git:
  ```sh
  brew install xcodegen
  ```
  SwiftTerm (the terminal emulator) is fetched automatically by Swift Package
  Manager when you build.

### Quick build

Clone the repo and run the packaging script, which generates the project, builds
a Release app, and produces `build/FriendlyTerminal.dmg`:

```sh
git clone https://github.com/aaditaggarwal26/friendlyterminal.git
cd friendlyterminal
./scripts/build-and-package.sh
```

### Developing in Xcode

To work on the code interactively, generate the project and open it (re-run
`xcodegen generate` whenever `project.yml` changes):

```sh
xcodegen generate
open FriendlyTerminal.xcodeproj
```

Then press **⌘R** to build and run.

### Cutting a release

Pushing a version tag triggers the GitHub Actions workflow in
`.github/workflows/release.yml`, which builds the app and attaches a downloadable
`.dmg` to a new GitHub Release:

```sh
git tag v1.0.0
git push origin v1.0.0
```

### Project structure

- `FriendlyTerminal/App/` — SwiftUI views and the AppKit terminal bridge.
- `FriendlyTerminal/Models/` — session, workspace, block-store, and the
  shell-integration parser.
- `FriendlyTerminal/AIKit/` — the optional on-device AI layer (gated to macOS 26).
- `FriendlyTerminal/Resources/` — bundled shell-integration script and assets.
- `project.yml` — the XcodeGen spec the `.xcodeproj` is generated from.

### How it works

FriendlyTerminal spawns a normal login zsh and sources a small shell-integration
script that emits standard OSC escape sequences (`133;A/B/C/D` for prompt/command/
output/exit, `633;E` for the command text, OSC 7 for the working directory). The
app parses those out of the PTY stream to build command blocks and track the cwd,
while the raw bytes still flow to the SwiftTerm emulator for rendering. Interactive
programs are detected from the alternate-screen (`?1049h`) and bracketed-paste
(`?2004h`) mode switches, so the UI knows when to hand the keyboard straight to the
running program.

## License

Released under the [GNU General Public License v3.0](LICENSE).
