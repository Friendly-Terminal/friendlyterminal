namespace FriendlyTerminal.Core.Agents;

/// <summary>One clickable slash command in the agent control bar.</summary>
public sealed record AgentSlashCommand(string Label, string SendText, string Help);

/// <summary>Where an agent stores its credentials, relative to the home directory.</summary>
public sealed record AgentAuthProbe(string HomeRelativeDir, IReadOnlyList<string> CredentialFiles);

/// <summary>Config files (home-relative) that list MCP servers, and the JSON key holding them.</summary>
public sealed record AgentMcpProbe(IReadOnlyList<string> HomeRelativeConfigFiles, string JsonKey);

/// <summary>
/// Data-only description of a recognized interactive CLI AI coding agent. Drives
/// detection, the control bar, and the doctor. Transcribed from the shared
/// ai-agent-profiler spec; must stay in sync with the macOS profiles.
/// </summary>
public sealed record AgentProfile(
    string Id,
    string DisplayName,
    IReadOnlyList<string> BinaryNames,
    string VersionProbe,
    bool RequiresNode,
    IReadOnlyList<string> DangerFlags,
    bool SupportsNumberedOptions,
    IReadOnlyList<AgentSlashCommand> SlashCommands,
    string ExitSendText,
    string ExitHint,
    string Glyph,
    string? AccentHex,
    AgentAuthProbe? AuthProbe,
    AgentMcpProbe? McpProbe);
