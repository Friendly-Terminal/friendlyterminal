# FriendlyTerminal.App for Windows

The Windows desktop app uses WinUI 3, WebView2 with xterm.js, and a real
PowerShell session backed by ConPTY. It references `FriendlyTerminal.Core` for
shell parsing, output detection, undo planning, and command help.

This project requires Windows to build and run. It is intentionally excluded
from `windows/FriendlyTerminal.sln`, which keeps the core and its tests buildable
on macOS and Linux.

## Implemented interface

- ConPTY and xterm.js terminal input, output, and resize handling.
- OSC shell-integration stream parsing and command blocks.
- File browser, breadcrumb navigation, and configurable command help.
- Clickable rich output and command-bar follow-up actions.
- Split terminal panes and first-launch tutorial.
- Git, project command, process, interactive-program, and Claude Code panels.
- Windows filesystem adapters and PowerShell-aware undo behavior.

## Build on Windows

Install the .NET 8 SDK and Visual Studio 2022 or later with the Windows App SDK,
WinUI, and MSIX/UWP build components. Open
`FriendlyTerminal.App.csproj` directly in Visual Studio, or use a Visual Studio
developer prompt:

```powershell
cd windows\app\FriendlyTerminal.App
msbuild FriendlyTerminal.App.csproj -restore -p:Platform=x64 -p:Configuration=Debug
```

The project is unpackaged and self-contained through
`WindowsPackageType=None` and `WindowsAppSDKSelfContained=true`. The standalone
.NET SDK can compile much of the project, but final Windows App SDK resource
generation requires the Visual Studio packaging tasks.

## Packaging a release

`windows/scripts/package.ps1` publishes the app self-contained for x64 Release
and produces two artifacts in `windows/release/`:

- `FriendlyTerminal-<version>-x64.zip` — the portable publish output.
- `FriendlyTerminal-Setup-<version>-x64.exe` — a per-user Inno Setup installer
  (`windows/scripts/installer.iss`) that needs no administrator rights.

Run it from a Visual Studio developer prompt with `msbuild` on the `PATH` and
[Inno Setup 6](https://jrsoftware.org/isinfo.php) installed:

```powershell
windows\scripts\package.ps1
```

The version comes from the current git tag (leading `v` stripped) when one is
present, otherwise a default; pass `-Version` to override. The
[`release.yml`](../../.github/workflows/release.yml) `windows` job runs this
script on `windows-latest` for tagged releases, and
[`ci.yml`](../../.github/workflows/ci.yml) exercises the same publish and
installer-compile path on every pull request.

## Key directories

- `Pty/` — ConPTY handles, process startup, input, output, resize, and disposal.
- `Views/` — terminal panes, blocks, command bar, sidebar, and contextual panels.
- `Models/` — Windows session, process, project, Git, block, and filesystem state.
- `Assets/terminal.html` — xterm.js WebView terminal host.
- `../../shell/` — bundled PowerShell OSC integration profile.

## Verification status

The headless core is covered by the tests in `windows/tests`. The WinUI app must
be built and exercised on Windows before publishing. Tagged releases publish a
per-user installer and a portable archive through the `windows` job in
[`release.yml`](../../.github/workflows/release.yml); see
[Packaging a release](#packaging-a-release).
