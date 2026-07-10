# Output detectors

After a command finishes, its output is run through an ordered list of detectors.
The first one that matches assigns the block a *render kind* — a richer display
than plain text. The most distinctive friendly behavior is the **command list**:
output turned into clickable chips that each fill the command bar with an obvious
next step.

Reference: `macos/OutputRendering/Detectors.swift`.

## Render kinds

- `plainText` — fallback.
- `table(rows)` — whitespace-aligned columns (≥3 cols, ≥3 rows, ≥70% consistent).
- `csvTable(rows)` — comma/tab separated (header has ≥2 commas or ≥1 tab, ≥80% of
  first 20 lines have the same column count).
- `jsonTree` — output starts with `{`/`[`, is ≥2 lines, and parses as JSON.
- `imageFile(path)` — `cat <image>` of an existing image file, or output whose
  last line is an absolute path to an existing image.
- `commandList(hint, items)` — clickable next-step chips (see below).

## Detector priority

Generic structural detectors run in priority order (lower first):
`CatImage 5 → ImagePath 10 → JSON 20 → CSV 25 → Table 30 → FileTree 40`.
The command-specific list detectors (ls, git, brew, history) are checked first,
ahead of the generic ones, because they key off the *command* not the output
shape.

## Command list detectors

Each chip has: `label`, optional `detail` (sub-label), an icon, and a `followUp`
string that gets loaded into the command bar (not auto-run — the user presses
Return). All path/name arguments are shell-quoted.

| Trigger command | Lists | Chip → fills in | Hint |
| --- | --- | --- | --- |
| `ls` (no `-R`; `-a`/`-A` shows hidden) | dir entries | folder → `cd <name>`, file → `open <name>` | "Click a folder to fill in cd … or a file to fill in open" |
| `git branch` (not `-d/-D/-m`) | branches, current marked ● | `git checkout <branch>` | "Click a branch to fill in git checkout" |
| `git status` (not `-s/--short/--porcelain`) | changed files (deduped) | `git add <file>` | "Click a file to fill in git add" |
| `git log --oneline` | commits (hash + subject) | `git show <hash>` | "Click a commit to fill in git show" |
| `git tag` / `git tag -l` / `--list` | tags | `git checkout <tag>` | "Click a tag to fill in git checkout" |
| `brew list`/`ls` (not `--versions`) | packages (deduped) | `brew info <pkg>` | "Click a package to fill in brew info" |
| `history` | past commands | loads that command verbatim | "Click a past command to load it" (capped at last 200) |

### Notes for the Windows port

- These are macOS/Unix-shell assumptions. On Windows/PowerShell the equivalents
  differ: `ls`→`Get-ChildItem`/`dir`, `open`→`Invoke-Item`/`start`, `history`→
  `Get-History`. `git` and `brew`→`winget`/`scoop` need their own mappings. Keep
  the *shape* (list → clickable next step), retarget the commands.
- The detection logic (parsing the command, parsing the output, building chips)
  is pure and belongs in `FriendlyTerminal.Core/Output`. Quoting must follow the
  target shell's rules (PowerShell quoting ≠ POSIX single-quote), so quoting is a
  platform-injected helper, not hardcoded.
- `ls`/`brew` detectors read the real filesystem to classify entries; that's an
  injected dependency in Core so it stays testable.
