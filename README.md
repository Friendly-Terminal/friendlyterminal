# FriendlyTerminal

FriendlyTerminal is a friendlier terminal for macOS, Linux, and Windows. It
keeps a real shell at the center, then adds the navigation, discoverability,
context, and safety expected from a modern desktop app.

Each platform uses a mature platform-specific terminal stack and follows the
shared behavior contract in [`docs/behavior-spec`](docs/behavior-spec/README.md).

## Install

### macOS

1. Download `FriendlyTerminal.dmg` from the
   [latest release](https://github.com/aaditaggarwal26/friendlyterminal/releases/latest).
2. Open it and drag FriendlyTerminal into Applications.
3. On first launch, right-click the app, choose **Open**, then confirm **Open**.

The first-launch step is required because current releases are not notarized by
a paid Apple Developer account.

### Linux

Download the package for your distribution from the
[latest release](https://github.com/aaditaggarwal26/friendlyterminal/releases/latest):

- **Ubuntu, Debian, Linux Mint, Pop!_OS:** open the `.deb` in your software
  installer.
- **Fedora, RHEL-family, openSUSE:** open the `.rpm` in your software installer.
- **Other distributions:** download the `.AppImage`, allow it to run as a
  program in the file's Properties dialog, then open it.

The packaged app does not require Node.js or development tools.

### Windows

1. Download `FriendlyTerminal-Setup-<version>-x64.exe` from the
   [latest release](https://github.com/aaditaggarwal26/friendlyterminal/releases/latest).
2. Run it. Because the installer is unsigned, SmartScreen may show **Windows
   protected your PC**; click **More info**, then **Run anyway**.
3. It installs per-user with no administrator prompt and adds a Start Menu
   shortcut.

Prefer no installer? Download `FriendlyTerminal-<version>-x64.zip`, extract it,
and run `FriendlyTerminal.App.exe` from the extracted `FriendlyTerminal` folder.

## Features

- **Real terminal behavior** for SSH, vim, nano, less, htop, REPLs, Claude Code,
  and other interactive programs.
- **Tabs and split panes** for independent shells in one window.
- **File sidebar and breadcrumbs** for browsing and changing the working folder.
- **Command discovery** with plain-language descriptions and danger indicators.
- **Git context** showing the current branch and working-tree state.
- **Command blocks and clickable output** on macOS and Windows, including rich
  JSON, CSV, table, file, branch, tag, commit, and history rendering.
- **Recoverable deletion and command undo** on macOS and Windows for supported
  filesystem, Git, archive, download, and package operations.
- **Project and process panels** on macOS and Windows for common project tasks,
  listening ports, browser launch, and process control.
- **Claude Code controls** on macOS and Windows for setup diagnostics, launch,
  session controls, and interactive shortcuts.
- **Optional on-device AI on macOS** using Apple's Foundation Models to turn
  plain language into commands and explain errors without sending data away.

Linux currently includes the real PTY, tabs, four-way split workspaces, file and
breadcrumb navigation, live Git context, command history, command guide,
terminal search, link detection, onboarding, and persistent preferences. Block
rendering, undo, Claude controls, project detection, and process panels remain
Linux parity work.

## System requirements

### macOS

- macOS 15.0 or later.
- macOS 26 with Apple Intelligence enabled for optional AI features.

### Linux

- A current x86_64 Linux desktop with GTK 3 and standard desktop utilities.
- bash, zsh, fish, or another interactive POSIX shell. bash and zsh receive
  enhanced command-status and working-directory integration.

### Windows

- Windows 10 version 1809 or later; Windows 11 recommended.
- WebView2, which is included with Windows 11 and current Windows 10 systems.

## Building from source

Clone the repository first:

```sh
git clone https://github.com/aaditaggarwal26/friendlyterminal.git
cd friendlyterminal
```

### macOS

Install Xcode 16 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen),
then run:

```sh
./scripts/build-and-package.sh
```

The release application and `build/FriendlyTerminal.dmg` are generated from
`project.yml`. For interactive development, run `xcodegen generate`, open
`FriendlyTerminal.xcodeproj`, and build the `FriendlyTerminal` scheme.

### Linux

Install Node.js 22 or later, npm, a C/C++ compiler, Python 3, and make:

```sh
cd linux
npm ci
npm test
npm run dev
```

Build the AppImage, Debian package, and RPM package on Linux with:

```sh
npm run package
```

Artifacts are written to `linux/release/`. See
[`linux/README.md`](linux/README.md) for architecture and keyboard shortcuts.

### Windows

Install the .NET 8 SDK and Visual Studio 2022 or later with the Windows App SDK
and WinUI workloads. The platform-neutral core tests run anywhere with .NET:

```sh
cd windows
dotnet test
```

Build the app in a Visual Studio developer prompt:

```powershell
cd windows\app\FriendlyTerminal.App
msbuild FriendlyTerminal.App.csproj -restore -p:Platform=x64 -p:Configuration=Debug
```

Produce the installer and portable archive with `windows\scripts\package.ps1`;
artifacts are written to `windows/release/`. See
[`windows/app/README.md`](windows/app/README.md) for details.

## Repository structure

- `macos/` — SwiftUI, AppKit, SwiftTerm, models, and AI code for macOS.
- `project.yml` and `scripts/` — macOS project generation and packaging.
- `linux/src/main/` — Electron lifecycle, PTY ownership, validated IPC, Git,
  filesystem, and desktop services.
- `linux/src/preload/` — narrow context-isolated renderer API.
- `linux/src/renderer/` — xterm.js panes, tabs, sidebar, command guide, and UI.
- `linux/resources/shell/` — bash and zsh OSC shell integration.
- `windows/src/FriendlyTerminal.Core/` — testable headless Windows logic.
- `windows/app/FriendlyTerminal.App/` — WinUI, ConPTY, and WebView2 application.
- `windows/tests/` — Windows core tests.
- `windows/scripts/` — Windows release packaging (publish, portable zip, and
  Inno Setup installer).
- `docs/behavior-spec/` — platform-neutral behavior contract.
- `.github/workflows/` — continuous integration and release packaging.

## How it works

FriendlyTerminal spawns a real shell: login zsh on macOS, the user's POSIX shell
in a Linux PTY, and PowerShell in a Windows ConPTY. Small shell profiles emit
standard OSC escape sequences for prompt, command, exit, and working-directory
state. The app observes those markers while raw bytes continue to the terminal
emulator: SwiftTerm on macOS and xterm.js on Linux and Windows. Full-screen and
raw-mode programs continue to control the terminal normally.

## Releases

Pushing a version tag runs `.github/workflows/release.yml`, which builds the
macOS disk image, the Linux AppImage, Debian, and RPM packages, and the Windows
per-user installer and portable archive, then attaches them to a GitHub Release:

```sh
git tag v1.2.0
git push origin v1.2.0
```

## Contributing and security

Start with [CONTRIBUTING.md](CONTRIBUTING.md), follow the
[Code of Conduct](CODE_OF_CONDUCT.md), and report vulnerabilities through the
private process in [SECURITY.md](SECURITY.md).

FriendlyTerminal is released under the [GNU General Public License v3.0](LICENSE).
