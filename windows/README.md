# FriendlyTerminal for Windows

The Windows app and its shared "brain". See
[`docs/architecture/repo-structure.md`](../docs/architecture/repo-structure.md)
for the stack decision and
[`docs/behavior-spec/`](../docs/behavior-spec/) for what the app must do.

## Layout

```
windows/
├── src/
│   └── FriendlyTerminal.Core/   headless logic — no UI, no Windows-only deps
│       ├── Help/                command help catalog + search
│       ├── Output/              output detectors (clickable next-step lists)
│       ├── ShellIntegration/    OSC/PTY stream parser (blocks, cwd, TUI state)
│       ├── Undo/                undo planner + rm-interception rules
│       └── Platform/            interfaces the OS implements (IFileSystem, …)
├── app/
│   └── FriendlyTerminal.App/    WinUI 3 app: ConPTY backend, xterm.js in
│                                WebView2, blocks UI, sidebar, panels
├── shell/                       PowerShell shell-integration profile
├── tests/
│   └── FriendlyTerminal.Core.Tests/
└── FriendlyTerminal.sln
```

The app project (`app/`) requires Windows to build and run; everything under
`src/` and `tests/` builds anywhere the .NET SDK does.

## Building and testing — works on macOS

`FriendlyTerminal.Core` targets `net8.0` with no Windows dependencies, so it
builds and unit-tests on macOS with the .NET SDK. This is the point: most of the
logic can be written and verified before switching to a Windows machine.

```bash
# one-time: install the .NET SDK
brew install --cask dotnet-sdk

cd windows
dotnet build
dotnet test
```

The WinUI app, ConPTY, and terminal widget are the only parts that genuinely
need Windows; they live in projects added later and are excluded from the
macOS-buildable set.

## Principle

`Core` never calls the OS directly. Filesystem, shell quoting, and command
execution come in through interfaces in `Core/Platform`; real implementations
live in the Windows app, fakes live in the test project. See
[`docs/behavior-spec/platform-mapping.md`](../docs/behavior-spec/platform-mapping.md).
