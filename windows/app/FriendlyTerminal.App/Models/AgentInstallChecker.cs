using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using FriendlyTerminal.Core.Agents;

namespace FriendlyTerminal.App.Models;

/// <summary>
/// Probes one <see cref="AgentProfile"/>'s installation (CLI on PATH, Node.js when
/// the tool needs it, credentials, MCP servers). Instances are cached per profile so
/// the breadcrumb button, control-bar header, and doctor dialog share results.
/// </summary>
public sealed class AgentInstallChecker : INotifyPropertyChanged
{
    private static readonly Dictionary<string, AgentInstallChecker> Cache = new();

    /// <summary>The shared checker for a profile, created on first use.</summary>
    public static AgentInstallChecker For(AgentProfile profile)
    {
        lock (Cache)
        {
            if (!Cache.TryGetValue(profile.Id, out var checker))
            {
                checker = new AgentInstallChecker(profile);
                Cache[profile.Id] = checker;
            }
            return checker;
        }
    }

    public enum State { Unknown, Checking, Installed, NotInstalled, NotApplicable }
    public enum AuthState { Unknown, Authenticated, NotAuthenticated }

    private readonly AgentProfile _profile;

    private State _agentState = State.Unknown;
    private string? _agentPath;
    private string? _agentVersion;
    private State _nodeState = State.Unknown;
    private string? _nodeVersion;
    private AuthState _authState = AuthState.Unknown;
    private int? _mcpServerCount;

    private AgentInstallChecker(AgentProfile profile) => _profile = profile;

    public AgentProfile Profile => _profile;

    public State AgentState { get => _agentState; private set => Set(ref _agentState, value); }
    public string? AgentPath { get => _agentPath; private set => Set(ref _agentPath, value); }
    public string? AgentVersion { get => _agentVersion; private set => Set(ref _agentVersion, value); }
    public State NodeState { get => _nodeState; private set => Set(ref _nodeState, value); }
    public string? NodeVersion { get => _nodeVersion; private set => Set(ref _nodeVersion, value); }
    public AuthState Auth { get => _authState; private set => Set(ref _authState, value); }
    /// <summary>null = unknown (no probe or unreadable), 0 = none configured.</summary>
    public int? McpServerCount { get => _mcpServerCount; private set => Set(ref _mcpServerCount, value); }

    public void Check()
    {
        if (_agentState != State.Unknown) return;
        ForceRecheck();
    }

    public void ForceRecheck()
    {
        AgentState = State.Checking;
        var context = SynchronizationContext.Current;
        Task.Run(() =>
        {
            var (agentPath, agentVersion) = ProbeAgent();
            var (nodeState, nodeVersion) = ProbeNode();
            var auth = ProbeAuth();
            var mcp = ProbeMcp();

            void Apply()
            {
                AgentPath = agentPath;
                AgentVersion = agentVersion;
                AgentState = agentPath is null ? State.NotInstalled : State.Installed;
                NodeState = nodeState;
                NodeVersion = nodeVersion;
                Auth = auth;
                McpServerCount = mcp;
            }

            if (context is not null) context.Post(_ => Apply(), null);
            else Apply();
        });
    }

    private (string? Path, string? Version) ProbeAgent()
    {
        string? path = null;
        foreach (var binary in _profile.BinaryNames)
        {
            var candidates = RunCapture("where.exe", binary)?
                .Split('\n').Select(l => l.Trim()).Where(l => l.Length > 0).ToArray();
            if (candidates is not { Length: > 0 }) continue;
            // where.exe can list npm's extensionless sh-shim first; prefer runnable forms.
            path = new[] { ".cmd", ".exe", ".bat", ".ps1" }
                .Select(ext => candidates.FirstOrDefault(
                    c => c.EndsWith(ext, StringComparison.OrdinalIgnoreCase)))
                .FirstOrDefault(c => c is not null) ?? candidates[0];
            break;
        }

        if (string.IsNullOrEmpty(path))
        {
            // Extra PATH fallbacks for claude only; other tools rely on PATH resolution.
            if (_profile.Id == "claude")
            {
                var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
                var candidates = new[]
                {
                    Path.Combine(home, "AppData", "Roaming", "npm", "claude.cmd"),
                    Path.Combine(home, ".local", "bin", "claude.exe"),
                };
                path = candidates.FirstOrDefault(File.Exists);
            }
            if (string.IsNullOrEmpty(path)) return (null, null);
        }

        // Invoke the resolved path, not the bare binary: a fallback install isn't on
        // PATH, so `<tool> --version` would be command-not-found. Quote for cmd.exe.
        var args = VersionArgs(_profile.VersionProbe);
        var version = RunCapture("cmd.exe", $"/c \"\"{path}\" {args}\"")?.Split('\n').FirstOrDefault()?.Trim();
        return (path, version);
    }

    /// <summary>The argument portion of a "tool --version" probe (defaults to --version).</summary>
    private static string VersionArgs(string versionProbe)
    {
        var space = versionProbe.IndexOf(' ');
        return space < 0 ? "--version" : versionProbe[(space + 1)..];
    }

    private (State, string?) ProbeNode()
    {
        if (!_profile.RequiresNode) return (State.NotApplicable, null);
        var version = RunCapture("cmd.exe", "/c node --version");
        return (version is null ? State.NotInstalled : State.Installed, version);
    }

    private AuthState ProbeAuth()
    {
        if (_profile.AuthProbe is not { } probe) return AuthState.Unknown;
        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        var dir = Path.Combine(home, probe.HomeRelativeDir);
        if (!Directory.Exists(dir)) return AuthState.NotAuthenticated;

        // Dir-only probe (no named credential files): presence alone can't confirm sign-in.
        if (probe.CredentialFiles.Count == 0) return AuthState.Unknown;

        foreach (var name in probe.CredentialFiles)
        {
            var path = Path.Combine(dir, name);
            try
            {
                if (File.Exists(path) && new FileInfo(path).Length > 10)
                    return AuthState.Authenticated;
            }
            catch { }
        }
        return AuthState.Unknown;
    }

    private int? ProbeMcp()
    {
        if (_profile.McpProbe is not { } probe) return null;
        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        foreach (var relative in probe.HomeRelativeConfigFiles)
        {
            var parts = new List<string> { home };
            parts.AddRange(relative.Split('/', '\\'));
            var path = Path.Combine(parts.ToArray());
            try
            {
                if (!File.Exists(path)) continue;
                using var doc = JsonDocument.Parse(File.ReadAllText(path));
                if (doc.RootElement.TryGetProperty(probe.JsonKey, out var servers)
                    && servers.ValueKind == JsonValueKind.Object)
                    return servers.EnumerateObject().Count();
            }
            catch { }
        }
        return 0;
    }

    private static string? RunCapture(string fileName, string arguments)
    {
        try
        {
            using var p = Process.Start(new ProcessStartInfo
            {
                FileName = fileName,
                Arguments = arguments,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true,
            });
            if (p is null) return null;

            // Read both streams async so neither pipe can fill and deadlock, then
            // enforce a real timeout that kills the whole subprocess tree on hang.
            var stdout = p.StandardOutput.ReadToEndAsync();
            var stderr = p.StandardError.ReadToEndAsync();
            if (!p.WaitForExit(15_000))
            {
                try { p.Kill(entireProcessTree: true); } catch { }
                return null;
            }
            p.WaitForExit(); // let the async readers drain after exit
            var output = stdout.GetAwaiter().GetResult();
            _ = stderr.GetAwaiter().GetResult();
            var trimmed = output.Trim();
            return p.ExitCode == 0 && trimmed.Length > 0 ? trimmed : null;
        }
        catch
        {
            return null;
        }
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    private void Set<T>(ref T field, T value, [System.Runtime.CompilerServices.CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
