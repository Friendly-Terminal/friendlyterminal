# AI Agent Profiler — implementation spec

Single source of truth for generalizing the Claude-Code-only control bar into a
data-driven system that recognizes any of a known set of interactive CLI AI coding
agents. macOS (Swift) and Windows (C#) each transcribe this spec into their own
language; the data and behavior must match across both.

## Scope

Ship five profiles: Claude Code (existing reference), OpenAI Codex, Google Gemini CLI,
Qwen Code, Z-code (Zhipu/GLM). Out of scope: Linux, any cloud/remote integration,
network profile updates.

## The AgentProfile model

Introduce one shared concept (Swift `struct AgentProfile`, C# `sealed record AgentProfile`)
plus a registry. A profile is data only.

```
AgentProfile:
  id                     stable key: "claude" | "codex" | "gemini" | "qwen" | "zcode"
  displayName            header text
  binaryNames            [String] basenames that identify the running command
  versionProbe           argv to get version, e.g. "claude --version"
  requiresNode           Bool — whether the tool is npm/Node-based (affects doctor)
  dangerFlags            [String] flags meaning "acts without asking" (may be empty)
  supportsNumberedOptions Bool — show the 1–4 menu-answer row (Claude-style menus)
  slashCommands          [(label, sendText, help)] — may be just /help for baseline
  exitSendText           raw bytes/text that ends the session (see per-tool table)
  exitHint               small caption under the Exit button
  brand                  { symbol/icon, accent } for the header
  authProbe (optional)   home-relative dir + credential file candidates, or nil
  mcpProbe  (optional)   home-relative config file candidates + json key, or nil
```

Registry: an ordered list `AgentRegistry.all` and `AgentRegistry.match(command) -> AgentProfile?`.

## Detection contract (both platforms)

Generalize the current command-matching. Keep the existing token-skipping logic exactly:
take the last pipeline stage (split on `|`), tokenize on whitespace, skip `VAR=value`
tokens and the wrappers `sudo`, `command`, `exec`, `time`, `env`; the first real token's
**basename (lowercased)** is the command name. Then:

- `AgentRegistry.match(command)` returns the first profile whose `binaryNames` contains
  that basename, else nil.
- `activeAgent: AgentProfile?` = `isTUIActive ? AgentRegistry.match(currentBlock.command) : nil`.
- `isAgentRunning: Bool` = `activeAgent != nil`.
- `agentRunsWithDangerousFlag: Bool` = the running command contains any of
  `activeAgent.dangerFlags`.

### Rename map (apply on both platforms)

| Old (Claude-specific)          | New (generic)                 |
|--------------------------------|-------------------------------|
| `isClaudeCommand(_)`           | `AgentRegistry.match(_)`      |
| `isClaudeRunning`              | `isAgentRunning`              |
| `currentClaudeCommand`         | `currentAgentCommand`         |
| `claudeRunsWithDangerousFlag`  | `agentRunsWithDangerousFlag`  |
| `ClaudeControlBarView`         | `AgentControlBarView`         |

Update every call site found for the old names (command bars, terminal hit-testing,
sidebar gating, breadcrumb). To limit churn you MAY keep `isClaudeRunning` as a thin
alias returning `isAgentRunning`, but new code and the control bar must use the generic
names. Behavior for Claude must be byte-for-byte identical.

## Control bar rendering (was ClaudeControlBarView)

Render entirely from `session.activeAgent`:

- Header: `displayName`, brand symbol/accent, green "Running" dot, `versionProbe` result.
- Danger banner: shown when `agentRunsWithDangerousFlag`; text
  `"Auto-approve mode — {displayName} can act without asking"`.
- Navigate & select: arrows (`ESC[A` / `ESC[B`) always; the 1–4 row only when
  `supportsNumberedOptions`.
- Controls: Enter (`\r`), Stop (Ctrl+C, `0x03`), Esc (`0x1B`) — always, generic-safe.
- Slash commands: collapsible grid built from `slashCommands`.
- Exit: sends `exitSendText`; caption is `exitHint`.

If a profile has only the baseline `slashCommands` (just `/help`), the grid still renders
that one entry — never show tool-specific buttons that could misfire.

## Doctor / install checker generalization

Make the checker probe an arbitrary profile instead of hardcoding Claude:

- Install/version: run `profile.versionProbe` (via login shell on macOS, `where.exe` +
  resolved-path invocation on Windows, same fallbacks as today). Keep the extra PATH
  fallbacks for `claude` only; other tools rely on PATH resolution.
- Node: only meaningful when `requiresNode`; otherwise report not-applicable, don't fail.
- Auth: use `profile.authProbe` when present, else report unknown.
- MCP: use `profile.mcpProbe` when present, else report none/unknown.

The doctor view probes `session.activeAgent ?? claudeProfile`. The breadcrumb button may
keep showing Claude status as today; acceptance only requires the generic checker to be
able to report install+version for each tool.

## Per-tool profile data

Confidence: **[V]** verified from docs, **[B]** safe baseline / unverified — do not invent
tool-specific actions for [B] items.

### claude — Claude Code (reference, unchanged)
- binaryNames `["claude"]`; versionProbe `claude --version`; requiresNode `true`
- dangerFlags `["--dangerously-skip-permissions"]`; supportsNumberedOptions `true`
- slash: `/clear`, `/compact`, `/help`, `/init`, `/model`, `/resume` (all `\r`-terminated)
- exitSendText `"/exit\r"`; exitHint `"or press Ctrl+C twice"`
- brand: `sparkles`, accent color
- authProbe `~/.claude` → `.credentials.json`, `auth.json`, `credentials.json`
- mcpProbe `~/.claude/settings.json`, `~/.claude.json` → key `mcpServers`

### codex — OpenAI Codex  [V]
- binaryNames `["codex"]`; versionProbe `codex --version`; requiresNode `false` (Rust)
- dangerFlags `["--dangerously-bypass-approvals-and-sandbox", "--yolo"]`
- supportsNumberedOptions `false`
- slash (conservative, verified): `/status`, `/model`, `/approvals`, `/compact`, `/diff`, `/new`
- exitSendText Ctrl+D (`\u{04}`); exitHint `"or press Ctrl+D"`
- brand: neutral terminal/`chevron.left.forwardslash.chevron.right` icon, accent
- authProbe `~/.codex` (best-effort; else unknown); mcpProbe `~/.codex/config.toml` if
  trivially parseable, else report unknown (TOML — do not add a TOML parser, just unknown)

### gemini — Google Gemini CLI  [V]
- binaryNames `["gemini"]`; versionProbe `gemini --version`; requiresNode `true`
- dangerFlags `["--yolo", "-y"]`; supportsNumberedOptions `false`
- slash: `/help`, `/tools`, `/mcp`, `/memory`, `/stats`, `/clear`
- exitSendText `"/quit\r"`; exitHint `"or press Ctrl+C twice"`
- brand: `sparkle`/diamond icon, accent
- authProbe `~/.gemini` (best-effort); mcpProbe `~/.gemini/settings.json` → key `mcpServers`

### qwen — Qwen Code  [V] (Gemini CLI fork)
- binaryNames `["qwen"]`; versionProbe `qwen --version`; requiresNode `true`
- dangerFlags `["--yolo"]`; supportsNumberedOptions `false`
- slash: `/help`, `/tools`, `/mcp`, `/memory`, `/stats`, `/approval-mode`
- exitSendText `"/quit\r"`; exitHint `"or press Ctrl+C twice"`
- brand: robot/`cpu` icon, accent
- authProbe `~/.qwen` (best-effort); mcpProbe `~/.qwen/settings.json` → key `mcpServers`

### zcode — Z-code (Zhipu/GLM)  [B] SAFE BASELINE — unverified
Research is inconclusive: "ZCode" is primarily a desktop IDE, and the terminal binary
name is ambiguous. Ship a baseline profile and flag it in the report.
- binaryNames `["zcode", "zai"]` (candidates); versionProbe `zcode --version` (best-effort)
- requiresNode `false`; dangerFlags `[]`; supportsNumberedOptions `false`
- slash: `/help` only
- exitSendText Ctrl+D (`\u{04}`); exitHint `"or press Ctrl+C twice"`
- brand: generic `sparkles`/robot icon, accent
- authProbe nil; mcpProbe nil (report unknown/none)

## Guardrails

- Claude behavior unchanged; it is now just one profile.
- Unknown/unprofiled agent → `activeAgent` is nil → no bar, no false buttons.
- Missing rich slash/keybindings → still show arrows + Enter/Stop/Esc + `/help` + exit.
- macOS and Windows stay in sync (same profiles, same behavior).
- Follow repo conventions; keep comments minimal.

## Acceptance criteria

- Running each of the five CLIs shows a correctly-branded bar (Z-code = baseline bar).
- Doctor/install view reports install + version for each tool via the generic checker.
- Danger banner appears when a tool is launched with one of its `dangerFlags`.
- Existing Claude tests still pass; add tests for `AgentRegistry.match` covering: each
  tool's basename, path-prefixed basename, pipe/sudo/env token-skipping, and unknown → nil.
- Build passes for the platform being changed.
