using System.IO;
using System.Text.Json;

namespace FriendlyTerminal.App.Models;

public sealed record ProjectCommandGroup(string Name, int Glyph, IReadOnlyList<ProjectCommand> Commands);

public sealed record ProjectCommand(string Label, string Command, int Glyph);

/// <summary>
/// Suggests ready-to-run commands for the project in the current folder
/// (npm/pnpm/yarn scripts, Python, Rust, Go, Make, Ruby, Docker), mirroring the
/// macOS ProjectCommandDetector. Glyphs are Segoe Fluent Icons code points.
/// </summary>
public static class ProjectCommandDetector
{
    private const int Play = 0xE768;
    private const int Build = 0xE90F;
    private const int Check = 0xE73E;
    private const int Download = 0xE896;
    private const int TerminalIcon = 0xE756;
    private const int Warn = 0xE7BA;
    private const int Trash = 0xE74D;

    public static List<ProjectCommandGroup> Suggestions(string cwd, IEnumerable<FileEntry> files)
    {
        var names = new HashSet<string>(files.Select(f => f.Name), StringComparer.OrdinalIgnoreCase);
        var groups = new List<ProjectCommandGroup>();

        if (names.Contains("package.json") && NodeGroup(cwd, names) is { } node)
            groups.Add(node);

        if (names.Contains("requirements.txt") || names.Contains("pyproject.toml") || names.Contains("setup.py"))
            groups.Add(PythonGroup(names));

        if (names.Contains("Cargo.toml"))
        {
            groups.Add(new ProjectCommandGroup("Rust", 0xE713, new[]
            {
                new ProjectCommand("Run", "cargo run", Play),
                new ProjectCommand("Build", "cargo build", Build),
                new ProjectCommand("Test", "cargo test", Check),
            }));
        }

        if (names.Contains("go.mod"))
        {
            groups.Add(new ProjectCommandGroup("Go", 0xE943, new[]
            {
                new ProjectCommand("Run", "go run .", Play),
                new ProjectCommand("Test", "go test ./...", Check),
                new ProjectCommand("Build", "go build .", Build),
            }));
        }

        if (names.Contains("Makefile"))
            groups.Add(new ProjectCommandGroup("Make", Build, MakeTargets(cwd)));

        if (names.Contains("Gemfile"))
        {
            groups.Add(new ProjectCommandGroup("Ruby", 0xE7B8, new[]
            {
                new ProjectCommand("Bundle install", "bundle install", Download),
                new ProjectCommand("RSpec", "bundle exec rspec", Check),
            }));
        }

        if (names.Contains("Dockerfile"))
        {
            groups.Add(new ProjectCommandGroup("Docker", 0xE7B8, new[]
            {
                new ProjectCommand("Build", "docker build .", Build),
            }));
        }

        return groups;
    }

    private static ProjectCommandGroup? NodeGroup(string cwd, HashSet<string> names)
    {
        string manager;
        if (names.Contains("pnpm-lock.yaml") || names.Contains("pnpm-lock.yml")) manager = "pnpm";
        else if (names.Contains("yarn.lock")) manager = "yarn";
        else manager = "npm";

        var commands = new List<ProjectCommand>();

        if (!names.Contains("node_modules"))
            commands.Add(new ProjectCommand("Install deps", $"{manager} install", Download));

        var scripts = ReadPackageScripts(Path.Combine(cwd, "package.json"));
        if (scripts.Count > 0)
        {
            string[] priority = { "dev", "start", "serve", "preview", "build", "test", "lint", "check", "format" };
            foreach (var key in priority.Where(scripts.Contains))
            {
                var cmd = manager == "npm" ? $"npm run {key}" : $"{manager} {key}";
                commands.Add(new ProjectCommand(key, cmd, ScriptGlyph(key)));
            }
            foreach (var key in scripts.Where(s => !priority.Contains(s)).OrderBy(s => s).Take(4))
            {
                var cmd = manager == "npm" ? $"npm run {key}" : $"{manager} {key}";
                commands.Add(new ProjectCommand(key, cmd, TerminalIcon));
            }
        }
        else
        {
            commands.Add(new ProjectCommand("dev", manager == "npm" ? "npm run dev" : $"{manager} dev", Play));
            commands.Add(new ProjectCommand("test", manager == "npm" ? "npm test" : $"{manager} test", Check));
            commands.Add(new ProjectCommand("build", manager == "npm" ? "npm run build" : $"{manager} build", Build));
        }

        if (commands.Count == 0) return null;
        var displayName = manager switch { "pnpm" => "pnpm", "yarn" => "Yarn", _ => "Node.js" };
        return new ProjectCommandGroup(displayName, 0xE943, commands);
    }

    private static List<string> ReadPackageScripts(string packageJsonPath)
    {
        try
        {
            using var doc = JsonDocument.Parse(File.ReadAllText(packageJsonPath));
            if (doc.RootElement.TryGetProperty("scripts", out var scripts)
                && scripts.ValueKind == JsonValueKind.Object)
                return scripts.EnumerateObject().Select(p => p.Name).ToList();
        }
        catch { }
        return new List<string>();
    }

    private static ProjectCommandGroup PythonGroup(HashSet<string> names)
    {
        var commands = new List<ProjectCommand>();

        if (names.Contains("requirements.txt"))
            commands.Add(new ProjectCommand("pip install", "pip install -r requirements.txt", Download));
        if (names.Contains("pyproject.toml") || names.Contains("setup.py"))
            commands.Add(new ProjectCommand("pip install -e", "pip install -e .", Download));

        if (names.Contains("manage.py"))
            commands.Add(new ProjectCommand("runserver", "python manage.py runserver", Play));
        else if (names.Contains("app.py"))
            commands.Add(new ProjectCommand("Run app.py", "python app.py", Play));
        else if (names.Contains("main.py"))
            commands.Add(new ProjectCommand("Run main.py", "python main.py", Play));

        commands.Add(new ProjectCommand("pytest", "pytest", Check));
        return new ProjectCommandGroup("Python", TerminalIcon, commands);
    }

    private static IReadOnlyList<ProjectCommand> MakeTargets(string cwd)
    {
        string content;
        try { content = File.ReadAllText(Path.Combine(cwd, "Makefile")); }
        catch { return new[] { new ProjectCommand("make", "make", Play) }; }

        var targets = new List<string>();
        foreach (var line in content.Split('\n'))
        {
            if (line.StartsWith('\t') || line.StartsWith('#') || line.StartsWith('.')) continue;
            var colon = line.IndexOf(':');
            if (colon <= 0) continue;
            var target = line[..colon].Trim();
            if (target.Length > 0 && !target.Contains(' ') && !target.Contains('='))
                targets.Add(target);
        }

        if (targets.Count == 0)
            return new[] { new ProjectCommand("make", "make", Play) };
        return targets.Take(6)
            .Select(t => new ProjectCommand($"make {t}", $"make {t}", ScriptGlyph(t)))
            .ToList();
    }

    private static int ScriptGlyph(string name) => name switch
    {
        "dev" or "start" or "serve" or "preview" or "runserver" => Play,
        "build" => Build,
        "test" => Check,
        "lint" or "check" or "format" => Warn,
        "clean" => Trash,
        _ => TerminalIcon,
    };
}
