using System.IO;

namespace FriendlyTerminal.Core.Agents;

/// <summary>
/// The known set of interactive CLI AI coding agents and the command matcher that
/// identifies which one (if any) a running command line launched. Mirrors the macOS
/// registry; the profile data must match across platforms.
/// </summary>
public static class AgentRegistry
{
    private static readonly string CtrlD = ((char)0x04).ToString();

    private static readonly string[] WrapperTokens = { "sudo", "command", "exec", "time", "env" };

    // Segoe MDL2 Assets glyph for a profile's header icon.
    private static string Glyph(int codepoint) => char.ConvertFromUtf32(codepoint);

    public static AgentProfile Claude { get; } = new(
        Id: "claude",
        DisplayName: "Claude Code",
        BinaryNames: new[] { "claude" },
        VersionProbe: "claude --version",
        RequiresNode: true,
        DangerFlags: new[] { "--dangerously-skip-permissions" },
        SupportsNumberedOptions: true,
        SlashCommands: new[]
        {
            new AgentSlashCommand("/clear", "/clear\r", "Clear the conversation history"),
            new AgentSlashCommand("/compact", "/compact\r", "Compact context to save tokens"),
            new AgentSlashCommand("/help", "/help\r", "Show Claude's built-in help"),
            new AgentSlashCommand("/init", "/init\r", "Create a CLAUDE.md for this project"),
            new AgentSlashCommand("/model", "/model\r", "Switch the model"),
            new AgentSlashCommand("/resume", "/resume\r", "Resume a previous conversation"),
        },
        ExitSendText: "/exit\r",
        ExitHint: "or press Ctrl+C twice",
        Glyph: Glyph(0xE99A),
        AccentHex: null,
        AuthProbe: new AgentAuthProbe(".claude", new[] { ".credentials.json", "auth.json", "credentials.json" }),
        McpProbe: new AgentMcpProbe(new[] { ".claude/settings.json", ".claude.json" }, "mcpServers"));

    public static AgentProfile Codex { get; } = new(
        Id: "codex",
        DisplayName: "Codex",
        BinaryNames: new[] { "codex" },
        VersionProbe: "codex --version",
        RequiresNode: false,
        DangerFlags: new[] { "--dangerously-bypass-approvals-and-sandbox", "--yolo" },
        SupportsNumberedOptions: false,
        SlashCommands: new[]
        {
            new AgentSlashCommand("/status", "/status\r", "Show session status"),
            new AgentSlashCommand("/model", "/model\r", "Switch the model"),
            new AgentSlashCommand("/approvals", "/approvals\r", "Change the approval policy"),
            new AgentSlashCommand("/compact", "/compact\r", "Compact context to save tokens"),
            new AgentSlashCommand("/diff", "/diff\r", "Show pending changes"),
            new AgentSlashCommand("/new", "/new\r", "Start a new conversation"),
        },
        ExitSendText: CtrlD,
        ExitHint: "or press Ctrl+D",
        Glyph: Glyph(0xE943),
        AccentHex: "#10A37F",
        AuthProbe: new AgentAuthProbe(".codex", new[] { "auth.json" }),
        McpProbe: null);

    public static AgentProfile Gemini { get; } = new(
        Id: "gemini",
        DisplayName: "Gemini CLI",
        BinaryNames: new[] { "gemini" },
        VersionProbe: "gemini --version",
        RequiresNode: true,
        DangerFlags: new[] { "--yolo", "-y" },
        SupportsNumberedOptions: false,
        SlashCommands: new[]
        {
            new AgentSlashCommand("/help", "/help\r", "Show Gemini's built-in help"),
            new AgentSlashCommand("/tools", "/tools\r", "List available tools"),
            new AgentSlashCommand("/mcp", "/mcp\r", "Show MCP server status"),
            new AgentSlashCommand("/memory", "/memory\r", "Manage remembered context"),
            new AgentSlashCommand("/stats", "/stats\r", "Show session statistics"),
            new AgentSlashCommand("/clear", "/clear\r", "Clear the conversation"),
        },
        ExitSendText: "/quit\r",
        ExitHint: "or press Ctrl+C twice",
        Glyph: Glyph(0xE734),
        AccentHex: "#1A73E8",
        AuthProbe: new AgentAuthProbe(".gemini", Array.Empty<string>()),
        McpProbe: new AgentMcpProbe(new[] { ".gemini/settings.json" }, "mcpServers"));

    public static AgentProfile Qwen { get; } = new(
        Id: "qwen",
        DisplayName: "Qwen Code",
        BinaryNames: new[] { "qwen" },
        VersionProbe: "qwen --version",
        RequiresNode: true,
        DangerFlags: new[] { "--yolo" },
        SupportsNumberedOptions: false,
        SlashCommands: new[]
        {
            new AgentSlashCommand("/help", "/help\r", "Show Qwen's built-in help"),
            new AgentSlashCommand("/tools", "/tools\r", "List available tools"),
            new AgentSlashCommand("/mcp", "/mcp\r", "Show MCP server status"),
            new AgentSlashCommand("/memory", "/memory\r", "Manage remembered context"),
            new AgentSlashCommand("/stats", "/stats\r", "Show session statistics"),
            new AgentSlashCommand("/approval-mode", "/approval-mode\r", "Change the approval mode"),
        },
        ExitSendText: "/quit\r",
        ExitHint: "or press Ctrl+C twice",
        Glyph: Glyph(0xE713),
        AccentHex: "#615CED",
        AuthProbe: new AgentAuthProbe(".qwen", Array.Empty<string>()),
        McpProbe: new AgentMcpProbe(new[] { ".qwen/settings.json" }, "mcpServers"));

    // Baseline / unverified: research is inconclusive on the terminal binary name.
    public static AgentProfile Zcode { get; } = new(
        Id: "zcode",
        DisplayName: "Z-code",
        BinaryNames: new[] { "zcode", "zai" },
        VersionProbe: "zcode --version",
        RequiresNode: false,
        DangerFlags: Array.Empty<string>(),
        SupportsNumberedOptions: false,
        SlashCommands: new[]
        {
            new AgentSlashCommand("/help", "/help\r", "Show built-in help"),
        },
        ExitSendText: CtrlD,
        ExitHint: "or press Ctrl+C twice",
        Glyph: Glyph(0xE99A),
        AccentHex: null,
        AuthProbe: null,
        McpProbe: null);

    public static IReadOnlyList<AgentProfile> All { get; } =
        new[] { Claude, Codex, Gemini, Qwen, Zcode };

    /// <summary>
    /// The first profile whose <see cref="AgentProfile.BinaryNames"/> contains the
    /// command's basename, or null. Mirrors the macOS token-skipping: takes the last
    /// pipeline stage, skips VAR=value assignments and the sudo/command/exec/time/env
    /// wrappers, and matches on the first real token's lowercased basename.
    /// </summary>
    public static AgentProfile? Match(string command)
    {
        if (CommandName(command) is not { } name) return null;
        foreach (var profile in All)
            if (profile.BinaryNames.Contains(name))
                return profile;
        return null;
    }

    private static string? CommandName(string command)
    {
        var lastStage = command.Split('|')[^1];
        foreach (var token in Tokenize(lastStage))
        {
            // The app launches a resolved install as `& "C:\...\claude.exe"`, so skip
            // the PowerShell call operator (quotes are stripped by the tokenizer).
            if (token == "&") continue;
            if (token.Contains('=')) continue;
            if (WrapperTokens.Contains(token)) continue;
            // Strip the directory on both separators (Windows paths use '\'), then the
            // extension, so a resolved install like C:\...\claude.cmd matches "claude".
            var sep = token.LastIndexOfAny(new[] { '/', '\\' });
            var basename = sep >= 0 ? token[(sep + 1)..] : token;
            return Path.GetFileNameWithoutExtension(basename).ToLowerInvariant();
        }
        return null;
    }

    // Unquote before splitting so "C:\Users\John Smith\...\claude.cmd" stays one token.
    public static IReadOnlyList<string> Tokenize(string command)
    {
        var tokens = new List<string>();
        var current = new System.Text.StringBuilder();
        var quote = '\0';
        foreach (var c in command)
        {
            if (quote != '\0')
            {
                if (c == quote) quote = '\0';
                else current.Append(c);
            }
            else if (c is '"' or '\'') quote = c;
            else if (c is ' ' or '\t')
            {
                if (current.Length > 0) { tokens.Add(current.ToString()); current.Clear(); }
            }
            else current.Append(c);
        }
        if (current.Length > 0) tokens.Add(current.ToString());
        return tokens;
    }
}
