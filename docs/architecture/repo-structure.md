# Repository structure

FriendlyTerminal is a multi-platform project with separate macOS, Linux, and
Windows applications. The apps do not share UI code, so they share **behavior**
through a platform-neutral specification rather than forcing unrelated desktop
stacks into a single abstraction.

```
friendlyterminal/
├── project.yml                xcodegen project definition for the macOS app
├── scripts/                   macOS build/package scripts
├── .github/workflows/         validation and release pipelines
│
├── docs/
│   ├── architecture/          layout + stack decisions (this folder)
│   └── behavior-spec/         the cross-platform source of truth (see below)
│
├── macos/                     macOS app sources (SwiftUI + AppKit + SwiftTerm)
│
├── linux/
│   ├── src/main/              Electron main process, PTY and OS services
│   ├── src/preload/           context-isolated renderer API
│   ├── src/renderer/          xterm.js terminal and application UI
│   ├── src/shared/            typed IPC contracts
│   └── resources/shell/       bash and zsh integration
│
└── windows/
    ├── src/FriendlyTerminal.Core/   headless C# logic, no UI, no Windows deps
    ├── tests/                        unit tests for the core
    └── README.md                     how to build/test (works on macOS too)
```

## Why the macOS app moved into `macos/`

The macOS app used to live at the repo root, from before the Linux and Windows
apps existed. Now that all three platforms are under active development, it
lives in `macos/` alongside `linux/` and `windows/` for a consistent layout.
`project.yml` (the `xcodegen` project definition) and `scripts/build-and-package.sh`
were updated to point at the new path; the generated Xcode project, scheme, and
app name are unaffected, so the release pipeline (`FriendlyTerminal.dmg`) is
unchanged.

## Stack decision (Linux)

- **Application shell:** Electron with a context-isolated renderer.
- **Terminal widget:** xterm.js with fit, search, and web-link addons.
- **PTY / process:** node-pty using the host's Unix PTY implementation.
- **Default shell:** the user's `$SHELL`, with bash, zsh, fish, and POSIX shell
  fallbacks.
- **Shell integration:** bundled bash and zsh profiles emitting OSC 133, 633,
  and 7 markers.
- **Packaging:** electron-builder producing AppImage, Debian, and RPM artifacts.

Electron is scoped to Linux and does not replace the native macOS or Windows
apps. Its mature PTY and terminal ecosystem provides reliable full-screen
terminal behavior, while the preload boundary keeps filesystem and process
capabilities out of renderer code.

## Stack decision (Windows)

- **UI:** WinUI 3 + C#. Native, modern, best Windows-native feel.
- **Terminal widget:** xterm.js hosted in WebView2 (the approach VS Code uses),
  backed by a ConPTY pseudo-console. This is the most mature path; a native
  WinUI terminal control is a possible later swap.
- **Default shell:** PowerShell. WSL/bash is a later option.
- **AI:** `FoundationModels` (Apple Intelligence) is Apple-only. Windows will
  call the Anthropic API, or Phi Silica on Copilot+ PCs. Stubbed for now.

Rejected alternatives: a web/Electron/Tauri rewrite (would mean retiring the
polished macOS app), and Swift-on-Windows (no SwiftUI; immature UI bindings).

## The key reason the core is C#

The "brain" of the app — command help catalog, output detectors, undo planning,
next-step hints — is plain logic with no UI. Written as a netstandard/net `Core`
library, it **builds and unit-tests on macOS via the `dotnet` CLI**, so most of
this can be developed and verified before switching to a Windows machine. Only
the terminal widget, ConPTY, and WinUI views genuinely require Windows.

The macOS app remains the reference implementation. `docs/behavior-spec/` is the
contract; the Swift, C#, and TypeScript implementations should update it when a
cross-platform behavior changes.
