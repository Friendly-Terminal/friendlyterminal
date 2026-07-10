namespace FriendlyTerminal.Core.Help;

public sealed record InstallableTool(string DisplayName, string WingetId);

/// <summary>
/// Maps well-known command names to winget packages so a "command not found"
/// error for a real tool (not a typo) can offer a one-click install. Ids are
/// verified against the winget index; keep the list to unambiguous tools.
/// </summary>
public static class ToolInstallCatalog
{
    private static readonly Dictionary<string, InstallableTool> Map = new(StringComparer.OrdinalIgnoreCase)
    {
        ["git"] = new("Git", "Git.Git"),
        ["node"] = new("Node.js", "OpenJS.NodeJS.LTS"),
        ["npm"] = new("Node.js (includes npm)", "OpenJS.NodeJS.LTS"),
        ["npx"] = new("Node.js (includes npx)", "OpenJS.NodeJS.LTS"),
        ["python"] = new("Python", "Python.Python.3.12"),
        ["python3"] = new("Python", "Python.Python.3.12"),
        ["pip"] = new("Python (includes pip)", "Python.Python.3.12"),
        ["pip3"] = new("Python (includes pip)", "Python.Python.3.12"),
        ["code"] = new("Visual Studio Code", "Microsoft.VisualStudioCode"),
        ["docker"] = new("Docker Desktop", "Docker.DockerDesktop"),
        ["gh"] = new("GitHub CLI", "GitHub.cli"),
        ["go"] = new("Go", "GoLang.Go"),
        ["cargo"] = new("Rust (via rustup)", "Rustlang.Rustup"),
        ["rustc"] = new("Rust (via rustup)", "Rustlang.Rustup"),
        ["rustup"] = new("Rust (via rustup)", "Rustlang.Rustup"),
        ["java"] = new("OpenJDK (Java)", "Microsoft.OpenJDK.21"),
        ["javac"] = new("OpenJDK (Java)", "Microsoft.OpenJDK.21"),
        ["dotnet"] = new(".NET SDK", "Microsoft.DotNet.SDK.8"),
        ["ffmpeg"] = new("FFmpeg", "Gyan.FFmpeg"),
    };

    public static InstallableTool? Lookup(string term)
        => Map.TryGetValue(term.Trim(), out var tool) ? tool : null;

    /// <summary>The command the install button runs. Agreements are accepted up
    /// front because the flow is otherwise interactive inside the block UI.</summary>
    public static string InstallCommand(InstallableTool tool)
        => $"winget install --id {tool.WingetId} -e --accept-source-agreements --accept-package-agreements";
}
