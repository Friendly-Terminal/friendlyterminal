# FriendlyTerminal for Linux

The Linux application combines Electron, xterm.js, and node-pty to provide a
real PTY with a discoverable desktop interface. It uses the user's configured
shell and includes enhanced integration for bash and zsh. Fish and other POSIX
shells still work as normal interactive shells, without enhanced command-status
history.

## Features

- Real PTY behavior for SSH, vim, nano, htop, less, REPLs, and other interactive
  programs.
- Tabs and up to four independent split panes per workspace.
- Sidebar with the file browser on top and searchable command help below,
  matching the macOS and Windows layout.
- File browser with hidden-file controls, breadcrumb navigation, file opening,
  and reveal-in-file-manager actions.
- Live Git branch, changed-file, ahead, and behind context in a popover on the
  location-bar branch button.
- Searchable plain-language command guide with destructive-command warnings.
- Command history with success and failure state for bash and zsh, shown as
  recent commands in the command guide.
- GNOME-style dark interface using the default GNOME Terminal color palette.
- Find in terminal, automatic link detection, copy-on-select, and familiar
  keyboard shortcuts.
- Persistent font size, hidden-file, and close-confirmation preferences.
- First-launch guide and responsive layouts for smaller windows.

## Run locally

Requirements:

- Node.js 22 or later
- npm
- A C/C++ compiler, Python 3, and make for the native PTY module

```sh
cd linux
npm ci
npm test
npm run dev
```

## Build installers

Run the packaging command on Linux:

```sh
cd linux
npm ci
npm run package
```

The finished AppImage, Debian package, and RPM package are written to
`linux/release/`. Native modules make the packaged output platform-specific, so
Linux installers must be produced on Linux. The release workflow does this on
x86_64 Ubuntu.

## Architecture

```text
src/main/       Electron lifecycle, validated IPC, PTY and OS services
src/preload/    Narrow context-isolated renderer API
src/renderer/   xterm.js panes and the desktop interface
src/shared/     IPC contracts shared by all Electron processes
resources/      bash and zsh shell integration
scripts/        deterministic build and cleanup entry points
```

The renderer has `nodeIntegration` disabled and cannot access Node.js directly.
All filesystem, process, Git, link-opening, and PTY operations are handled in the
main process through the typed preload API. Terminal sessions are owned by the
renderer that created them and are closed when that renderer exits.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| `Ctrl+Shift+T` | New tab |
| `Ctrl+Shift+D` | Split pane |
| `Ctrl+Shift+W` | Close active pane |
| `Ctrl+Shift+P` | Open command guide |
| `Ctrl+Shift+F` | Find in active terminal |
| `Ctrl+K` | Focus command bar |
| `Ctrl+B` | Toggle sidebar |
| `Ctrl++` / `Ctrl+-` | Change terminal text size |
| `Ctrl+Shift+C` / `Ctrl+Shift+V` | Copy / paste in terminal |
