# Behavior spec

This folder is the cross-platform contract for FriendlyTerminal. It describes
*what the app does* in platform-neutral terms, so the macOS (Swift), Linux
(TypeScript), and Windows (C#) apps converge on the same behavior.

The macOS app is the current reference implementation; where these docs and the
Swift code disagree, update whichever is wrong and keep them in sync.

| Doc | What it pins down | macOS source of truth |
| --- | --- | --- |
| [command-catalog.md](command-catalog.md) | The friendly help catalog: groups, commands, hidden search keywords | `macos/App/CommandHelpView.swift` |
| [output-detectors.md](output-detectors.md) | Turning command output into clickable "next step" lists | `macos/OutputRendering/Detectors.swift` |
| [undo-rules.md](undo-rules.md) | Which commands are undoable and how undo is performed | `macos/Models/UndoPlan.swift`, `SessionState.swift` |
| [shell-integration.md](shell-integration.md) | The block model (command start/end/exit code) via OSC markers | `macos/Terminal/*`, zsh integration |
| [platform-mapping.md](platform-mapping.md) | macOS API → Windows equivalent for every OS touchpoint | n/a |

## How to use this during platform work

1. Implement the rule against the spec in the relevant platform directory.
2. Write a unit test that encodes the spec's examples.
3. If the macOS app does something the spec doesn't mention, add it here first.
