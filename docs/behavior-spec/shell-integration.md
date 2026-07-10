# Shell integration (the block model)

FriendlyTerminal groups terminal output into **blocks** — one per command, each
with its command text, working directory, output, and exit code. This is what
makes per-command Undo buttons, output detectors, and the AI "explain/fix"
features possible. It depends on the shell emitting marker escape sequences
around each prompt and command.

## macOS today

A zsh integration script (sourced into the spawned shell) emits OSC sequences,
which the terminal view parses:

- `OSC 133 ; A` — prompt start
- `OSC 133 ; B` — command start (end of prompt)
- `OSC 133 ; C` — command output start
- `OSC 133 ; D ; <exit>` — command end + exit code
- `OSC 633 ; E ; <cmdline>` — the command line being run (VS Code extension)
- `OSC 7 ; file://…` — current working directory

From these the app knows when a command begins/ends, its exit status, and the
cwd (which drives the breadcrumb bar and git status).

`SessionState` consumes this: on `commandEnd` it finalizes the block and calls
`attachUndoPlan(exitCode:)`; cwd changes call `updateCwd` → refresh files + git.

## Windows port notes

- The marker contract is shell-agnostic; the **emitter** changes. Provide a
  PowerShell profile (and optionally a cmd hook / WSL bash script) that emits the
  same OSC 133 markers around the prompt and reports `$LASTEXITCODE` in `133;D`.
  Windows Terminal already defines shell-integration markers for PowerShell —
  reuse that convention.
- cwd reporting: emit `OSC 9 ; 9 ; <path>` (the Windows Terminal convention) or
  `OSC 7`, and parse whichever the profile sends.
- The **parser** that turns marker sequences into block boundaries is pure and
  belongs in `FriendlyTerminal.Core`; the PTY/terminal widget feeds it bytes.
- Backing PTY is **ConPTY**; the terminal widget is **xterm.js in WebView2**,
  which already understands these OSC sequences.

## Linux implementation

- bash and zsh wrappers under `linux/resources/shell/` preserve the user's
  startup files and emit OSC 133, 633, and 7 markers.
- The Electron main process owns each node-pty session and buffers initial
  output until the renderer signals that its xterm.js pane is ready.
- zsh emits command-start and command-end events through `preexec` and `precmd`.
  bash records the completed command and exit status through `PROMPT_COMMAND`
  without replacing the user's DEBUG trap.
- fish and other shells retain normal PTY behavior but do not yet provide the
  enhanced command-status history.
