using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Text.Json;

namespace FriendlyTerminal.App.Models;

/// <summary>
/// Probes the Claude Code CLI installation (CLI on PATH, Node.js, credentials,
/// MCP servers), mirroring the macOS ClaudeInstallChecker. Results drive the
/// breadcrumb Claude button and the doctor dialog.
/// </summary>
public sealed class ClaudeInstallChecker : INotifyPropertyChanged
{
    public static ClaudeInstallChecker Instance { get; } = new();

    public enum State { Unknown, Checking, Installed, NotInstalled }
    public enum AuthState { Unknown, Authenticated, NotAuthenticated }

    private State _claudeState = State.Unknown;
    private string? _claudePath;
    private string? _claudeVersion;
    private State _nodeState = State.Unknown;
    private string? _nodeVersion;
    private AuthState _authState = AuthState.Unknown;
    private int? _mcpServerCount;

    private ClaudeInstallChecker() { }

    public State ClaudeState { get => _claudeState; private set => Set(ref _claudeState, value); }
    public string? ClaudePath { get => _claudePath; private set => Set(ref _claudePath, value); }
    public string? ClaudeVersion { get => _claudeVersion; private set => Set(ref _claudeVersion, value); }
    public State NodeState { get => _nodeState; private set => Set(ref _nodeState, value); }
    public string? NodeVersion { get => _nodeVersion; private set => Set(ref _nodeVersion, value); }
    public AuthState Auth { get => _authState; private set => Set(ref _authState, value); }
    /// <summary>null = unknown, 0 = none configured.</summary>
    public int? McpServerCount { get => _mcpServerCount; private set => Set(ref _mcpServerCount, value); }

    public void Check()
    {
        if (_claudeState != State.Unknown) return;
        ForceRecheck();
    }

    public void ForceRecheck()
    {
        ClaudeState = State.Checking;
        var context = SynchronizationContext.Current;
        Task.Run(() =>
        {
            var (claudePath, claudeVersion) = ProbeClaude();
            var nodeVersion = RunCapture("cmd.exe", "/c node --version");
            var auth = ProbeAuth();
            var mcp = ProbeMcp();

            void Apply()
            {
                ClaudePath = claudePath;
                ClaudeVersion = claudeVersion;
                ClaudeState = claudePath is null ? State.NotInstalled : State.Installed;
                NodeVersion = nodeVersion;
                NodeState = nodeVersion is null ? State.NotInstalled : State.Installed;
                Auth = auth;
                McpServerCount = mcp;
            }

            if (context is not null) context.Post(_ => Apply(), null);
            else Apply();
        });
    }

    private static (string? Path, string? Version) ProbeClaude()
    {
        var path = RunCapture("where.exe", "claude")?.Split('\n').FirstOrDefault()?.Trim();
        if (string.IsNullOrEmpty(path))
        {
            var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            var candidates = new[]
            {
                Path.Combine(home, "AppData", "Roaming", "npm", "claude.cmd"),
                Path.Combine(home, ".local", "bin", "claude.exe"),
            };
            path = candidates.FirstOrDefault(File.Exists);
            if (path is null) return (null, null);
        }
        var version = RunCapture("cmd.exe", "/c claude --version")?.Split('\n').FirstOrDefault()?.Trim();
        return (path, version);
    }

    private static AuthState ProbeAuth()
    {
        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        var claudeDir = Path.Combine(home, ".claude");
        if (!Directory.Exists(claudeDir)) return AuthState.NotAuthenticated;

        var candidates = new[] { ".credentials.json", "auth.json", "credentials.json" };
        foreach (var name in candidates)
        {
            var path = Path.Combine(claudeDir, name);
            try
            {
                if (File.Exists(path) && new FileInfo(path).Length > 10)
                    return AuthState.Authenticated;
            }
            catch { }
        }
        return AuthState.Unknown;
    }

    private static int? ProbeMcp()
    {
        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        var candidates = new[]
        {
            Path.Combine(home, ".claude", "settings.json"),
            Path.Combine(home, ".claude.json"),
        };
        foreach (var path in candidates)
        {
            try
            {
                if (!File.Exists(path)) continue;
                using var doc = JsonDocument.Parse(File.ReadAllText(path));
                if (doc.RootElement.TryGetProperty("mcpServers", out var servers)
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
            var output = p.StandardOutput.ReadToEnd();
            p.WaitForExit(15_000);
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
