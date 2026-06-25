# FriendlyTerminal.App (WinUI 3)

The Windows app shell. **This project requires Windows to build and run** — it
uses the Windows App SDK, WebView2, and the ConPTY Win32 API. It is intentionally
excluded from `windows/FriendlyTerminal.sln` (the macOS-buildable Core solution).

## What works in this skeleton

A single window hosting an xterm.js terminal (in WebView2) wired to a real
PowerShell session over a ConPTY pseudo-console. Bytes flow both ways:

```
xterm.js  ──onData──▶ WebView2 postMessage ──▶ PtyConnection.WriteInput ──▶ ConPTY ──▶ powershell.exe
powershell.exe ──▶ ConPTY ──▶ PtyConnection.OutputReceived ──▶ ExecuteScriptAsync ──▶ term.write
```

None of the "friendly" features are here yet — those come from
`FriendlyTerminal.Core` (output detectors, undo, help catalog) in a later phase.

## Build (on Windows)

Prerequisites: the **.NET 8 SDK**, plus the Visual Studio **MSIX packaging**
MSBuild tasks. The bare .NET SDK can compile the C#/XAML (it produces
`FriendlyTerminal.App.dll`) but the Windows App SDK's resource/layout pipeline
(`MrtCore.PriGen.targets`) loads `Microsoft.Build.AppxPackage.dll` /
`Microsoft.Build.Packaging.Pri.Tasks.dll`, which ship **only** with Visual Studio
or its build-tools MSIX/UWP component — not with the standalone .NET SDK. Without
them the build fails at `RemovePayloadDuplicates` / `ExpandPriContent` with
`MSB4062` even though the code itself is fine.

So build with one of:

- **Visual Studio 2022** (Desktop + Windows App SDK workloads): open
  `FriendlyTerminal.App.csproj` and press F5, or use the VS Developer prompt's
  `msbuild`.
- **VS Build Tools** with the MSIX packaging component installed, then:

```powershell
cd windows\app\FriendlyTerminal.App
dotnet build -r win-x64
dotnet run -r win-x64
```

The project is configured unpackaged and self-contained
(`WindowsPackageType=None`, `WindowsAppSDKSelfContained=true`) so the produced
exe runs without separately installing the Windows App Runtime.

## Files

- `App.xaml` / `MainWindow.xaml` — WinUI app + the window hosting `WebView2`.
- `MainWindow.xaml.cs` — the WebView2 ↔ ConPTY bridge.
- `Pty/PseudoConsole.cs`, `Pty/PtyConnection.cs`, `Pty/NativeMethods.cs` — the
  ConPTY pseudo-console and process plumbing.
- `Assets/terminal.html` — xterm.js front end (loads from CDN for now; vendor it
  for offline use later).

## Status

Compiled on Windows with the .NET 8 SDK: NuGet restore succeeds and the C#/XAML
build produces `FriendlyTerminal.App.dll`. The `STARTUPINFO`/`STARTUPINFOEX`
P/Invoke structs were given `CharSet.Unicode` to match the Unicode `CreateProcess`.
The only step that does not complete on a machine without the Visual Studio MSIX
packaging tasks is the final Windows App SDK resource/layout pass (see Build
above) — a toolchain gap, not a code issue.

Not exercised at runtime yet: actually launching the window and confirming bytes
flow between xterm.js and ConPTY, and wiring the PowerShell profile in
`windows/shell/` for the per-command block markers.
