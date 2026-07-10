using System.Text.RegularExpressions;

namespace FriendlyTerminal.Core.Help;

/// <summary>
/// Turns PowerShell's "The term 'gti' is not recognized..." error into a
/// friendly "Did you mean git ...?" suggestion by fuzzy-matching the missing
/// term against commands we know about (the help catalog plus common tools).
/// </summary>
public static class CommandNotFound
{
    private static readonly Regex NotRecognized = new(
        @"The term '([^']+)' is not recognized|'([^']+)' is not recognized as an internal or external command");

    /// <summary>Extra names that newcomers commonly reach for but that don't
    /// lead a catalog entry.</summary>
    private static readonly string[] CommonCommands =
    {
        "git", "ls", "cd", "dir", "pwd", "cat", "echo", "mkdir", "rmdir", "rm",
        "cp", "mv", "npm", "npx", "node", "python", "pip", "dotnet", "code",
        "winget", "ping", "ipconfig", "ssh", "scp", "curl", "tar", "docker",
        "gh", "claude", "notepad", "explorer", "cls", "clear", "exit", "where",
        "powershell", "pwsh", "java", "go", "cargo",
    };

    public static IReadOnlyList<string> KnownCommands { get; } = BuildKnownCommands();

    private static IReadOnlyList<string> BuildKnownCommands()
    {
        var set = new HashSet<string>(CommonCommands, StringComparer.OrdinalIgnoreCase);
        foreach (var category in CommandCatalog.All)
        {
            foreach (var item in category.Commands)
            {
                var first = item.Command.Split(' ')[0];
                // Skip variable syntax and dot-sourced paths; they aren't command names.
                if (first.Length == 0 || first.StartsWith('$') || first.StartsWith('.') || first.StartsWith('('))
                    continue;
                set.Add(first);
            }
        }
        return set.ToList();
    }

    /// <summary>The command name the shell reported as unknown, or null.</summary>
    public static string? ExtractMissingTerm(string output)
    {
        var match = NotRecognized.Match(output);
        if (!match.Success) return null;
        return match.Groups[1].Success ? match.Groups[1].Value : match.Groups[2].Value;
    }

    /// <summary>
    /// The full command line with the misspelled term corrected, or null when
    /// nothing known is close enough to suggest with confidence.
    /// </summary>
    public static string? SuggestCorrection(string commandLine, string missingTerm)
    {
        if (missingTerm.Length < 2) return null;

        var maxDistance = missingTerm.Length <= 4 ? 1 : 2;
        string? best = null;
        var bestDistance = maxDistance + 1;
        foreach (var candidate in KnownCommands)
        {
            var distance = EditDistance(missingTerm.ToLowerInvariant(), candidate.ToLowerInvariant());
            if (distance == 0) return null; // the command exists; the failure is something else
            if (distance < bestDistance ||
                (distance == bestDistance && best is not null && candidate.Length < best.Length))
            {
                bestDistance = distance;
                best = candidate;
            }
        }
        if (best is null) return null;

        var index = commandLine.IndexOf(missingTerm, StringComparison.OrdinalIgnoreCase);
        if (index < 0) return best;
        var corrected = commandLine[..index] + best + commandLine[(index + missingTerm.Length)..];
        return corrected == commandLine ? null : corrected;
    }

    /// <summary>Optimal string alignment distance - Levenshtein plus adjacent
    /// transpositions, so "gti" is one step from "git".</summary>
    private static int EditDistance(string a, string b)
    {
        var d = new int[a.Length + 1, b.Length + 1];
        for (var i = 0; i <= a.Length; i++) d[i, 0] = i;
        for (var j = 0; j <= b.Length; j++) d[0, j] = j;

        for (var i = 1; i <= a.Length; i++)
        {
            for (var j = 1; j <= b.Length; j++)
            {
                var cost = a[i - 1] == b[j - 1] ? 0 : 1;
                d[i, j] = Math.Min(Math.Min(d[i - 1, j] + 1, d[i, j - 1] + 1), d[i - 1, j - 1] + cost);
                if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1])
                    d[i, j] = Math.Min(d[i, j], d[i - 2, j - 2] + 1);
            }
        }
        return d[a.Length, b.Length];
    }
}
