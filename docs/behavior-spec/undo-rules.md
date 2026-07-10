# Undo rules

Finished commands can carry an `UndoPlan`. Tapping **Undo** on a block (or
⌘Z / Shell → Undo Last Command) runs the plan's actions to put things back.

Reference: `macos/Models/UndoPlan.swift`, `SessionState.swift`.

## Action types

- `shell(cmd)` — run an inverse command (`git reset --soft HEAD~1`, `mv b a`…).
- `trash(path)` — move an absolute path to the Trash (recoverable).
- `restore(trashed, original)` — move a trashed item back (undo of a delete).

## Safety gate

`UndoPlanner.plan` refuses anything with shell metacharacters
(`' " * ? [ ] { } | & ; < > $ ` `` ` ``) — quoting/globbing/piping/chaining is too
hard to reverse safely, so those commands get no undo.

## `allowPreState`

Some inverses depend on state captured *before* the command runs (e.g. did the
file already exist?). Those plans are only produced when `allowPreState` is true
— which is at `executeCommand` time, not when reconstructed after the fact at
`commandEnd`. The `allowPreState`-only commands are `touch`, `cp`, `mv`.

## Per-command plans

| Command | Undo | Pre-state? |
| --- | --- | --- |
| `cd` | `cd <previous cwd>` | no |
| `mkdir <name>` | trash the created folder | no |
| `touch <files>` | trash only the files that didn't already exist | yes |
| `cp <src> <dest>` | trash the created copy (refuses if it would overwrite) | yes |
| `mv <src> <dest>` | `mv` it back (refuses if it would overwrite) | yes |
| `git add <x>` | `git restore --staged <x>` | no |
| `git commit` | `git reset --soft HEAD~1` (keeps changes) | no |
| `git checkout/switch <branch>` | `git checkout -` (single branch operand only) | no |
| `export NAME=…` | `unset NAME` | no |
| `zip <archive> …` | trash the archive | no |
| `tar -c…f <archive>` | trash the archive | no |
| `curl -o <file>` / `curl -O <url>` | trash the downloaded file | no |
| `brew install <pkgs>` | `brew uninstall <pkgs>` | no |

Read-only and irreversible commands return `nil` (no Undo button).

## `rm` → Trash interception

`RmInterceptor.safeTargets` recognizes a *safe* `rm` (only flags `r f R d i v`,
no metacharacters, every target exists) and FriendlyTerminal moves those targets
to the Trash itself instead of letting `rm` permanently delete them — recording a
`restore` plan so the delete is undoable. Anything it can't vet safely falls
through to the real `rm`.

## Windows port notes

- **Trash → Recycle Bin.** Replace `FileManager.trashItem` /
  `restore` with `Microsoft.VisualBasic.FileIO.FileSystem.Delete*(…, RecycleBin)`
  and a restore via the Recycle Bin shell API. This is the platform-injected
  side of undo; the *planning* logic is pure and portable.
- **Command set.** `rm`/`mv`/`cp`/`touch` map to PowerShell `Remove-Item` /
  `Move-Item` / `Copy-Item` / `New-Item`; `export`→`$env:` / `Set-Item env:`;
  `brew`→`winget`/`scoop`. `git` is the same.
- **Quoting.** The unsafe-character gate and the `q()` single-quote helper are
  POSIX. PowerShell needs its own quoting and its own metacharacter set.
- Keep `UndoPlanner` as pure logic in `FriendlyTerminal.Core/Undo` with the
  filesystem and shell injected, so the table above is unit-testable on macOS.
