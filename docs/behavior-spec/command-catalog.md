# Command help catalog

The help panel is a searchable, categorized cheat sheet of friendly command
explanations. Each command has plain-language detail, a danger flag, and hidden
search keywords so non-technical users find it by intent, not exact name.

Reference: `FriendlyTerminal/App/CommandHelpView.swift`.

## Data shape

```
CommandHelpItem:
  command     the command text (e.g. "git status")
  detail      one-line plain-language explanation
  isDangerous flags destructive commands (shown with a warning)
  keywords    hidden synonyms — searched but not displayed
```

```
CommandCategory:
  name        e.g. "Navigate", "GitHub"
  icon        SF Symbol (macOS) — map to an icon set on Windows
  commands    [CommandHelpItem]
```

## Search

Matches against, case-insensitively: category name, command text, detail text,
and hidden `keywords`. The keywords field is what lets "download a website" find
`curl`, or "throw away" find `rm`.

## Categories

Order and current set (macOS):

`Navigate, Files, GitHub, AI, Search, System, Network, Permissions, Processes,
Archives, Text, Editors, npm, pip, Python, Node, Homebrew, Docker, Environment,
Remote, Disk, Misc`.

Enabled by default: `Navigate, Files, GitHub, AI, Search, System, Network, npm,
pip`. The rest are opt-in via settings.

## Windows port notes

- The catalog is **content/data**, not logic — ideally lift it into a shared data
  file (JSON/YAML in `docs/behavior-spec/` or a resource) that both apps load, so
  the friendly explanations and keywords don't drift between platforms.
- Several commands are Unix-specific (`chmod`, `ls`, `brew`, `man`…). The Windows
  catalog needs a parallel set (`icacls`, `Get-ChildItem`, `winget`/`scoop`,
  `Get-Help`…) while keeping the same plain-language `detail` and `keywords`.
- SF Symbol icon names won't exist on Windows; map category icons separately.
- Danger flags (`isDangerous`) and the search behavior are pure and portable.
