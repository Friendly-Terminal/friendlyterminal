# Repository structure

FriendlyTerminal is becoming a multi-platform project: a shipping macOS app and
an in-progress Windows app. The two apps cannot share UI code — SwiftUI is
Apple-only — so the thing they share is **behavior**, captured as a spec rather
than as a compiled library.

```
friendlyterminal/
├── FriendlyTerminal/          macOS app sources (SwiftUI + AppKit + SwiftTerm)
├── project.yml                xcodegen project definition for the macOS app
├── scripts/                   macOS build/package scripts
├── .github/workflows/         macOS release pipeline
│
├── docs/
│   ├── architecture/          layout + stack decisions (this folder)
│   └── behavior-spec/         the cross-platform source of truth (see below)
│
└── windows/
    ├── src/FriendlyTerminal.Core/   headless C# logic, no UI, no Windows deps
    ├── tests/                        unit tests for the core
    └── README.md                     how to build/test (works on macOS too)
```

## Why the macOS app stays at the repo root

The macOS app, its `xcodegen` project, its packaging script, and its release
workflow all assume the app lives at the root. Moving it into `macos/` would
break the working release pipeline (v1.0.0, v1.1.0) for no functional gain. The
Windows work lives in its own `windows/` subtree alongside it. If we ever retire
or rewrite the macOS app, we can revisit a symmetric `macos/` + `windows/`
split then.

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
contract; the Swift app and the C# core are two implementations of it.
