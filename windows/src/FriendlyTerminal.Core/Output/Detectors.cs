using System.Text.Json;
using System.Text.RegularExpressions;
using FriendlyTerminal.Core.Platform;

namespace FriendlyTerminal.Core.Output;

internal static class DetectorUtil
{
    public static readonly HashSet<string> ImageExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".ico", ".tiff", ".tif"
    };

    public static string ResolvePath(string p, string cwd, string home)
    {
        if (p.StartsWith('~')) return home + p[1..];
        if (IsRooted(p)) return p;
        // Join with '/' (Windows APIs accept both separators) so fake and real
        // file systems agree on the shape.
        return cwd.TrimEnd('/', '\\') + "/" + p;
    }

    /// <summary>
    /// Windows-style rootedness, independent of the host OS. Path.IsPathRooted
    /// rejects "C:\..." when running on Linux, which broke these detectors on
    /// the Linux CI runner.
    /// </summary>
    public static bool IsRooted(string path) =>
        (path.Length >= 3 && char.IsAsciiLetter(path[0]) && path[1] == ':' && (path[2] == '\\' || path[2] == '/'))
        || path.StartsWith('\\') || path.StartsWith('/');

    public static string IconForFile(string name) =>
        System.IO.Path.GetExtension(name).ToLowerInvariant() switch
        {
            ".cs" or ".js" or ".ts" or ".jsx" or ".tsx" or ".py" or ".ps1" or ".sh" or ".bat" or ".cmd" => "code",
            ".json" or ".yaml" or ".yml" or ".toml" => "doc",
            ".md" or ".txt" => "doc",
            ".png" or ".jpg" or ".jpeg" or ".gif" or ".webp" or ".bmp" or ".ico" => "picture",
            ".pdf" => "pdf",
            ".zip" or ".gz" or ".tar" or ".7z" or ".rar" => "archive",
            _ => "file",
        };
}

/// <summary>
/// Renders `ls` / `dir` / `Get-ChildItem` (no target argument) as clickable chips
/// built from the real directory contents, matching the macOS LsListingDetector.
/// </summary>
public sealed class LsListingDetector : IOutputDetector
{
    private static readonly HashSet<string> Commands = new(StringComparer.OrdinalIgnoreCase)
    {
        "ls", "dir", "gci", "Get-ChildItem"
    };

    private readonly IFileSystem _fs;
    private readonly IShellQuoter _quoter;

    public LsListingDetector(IFileSystem fs, IShellQuoter quoter)
    {
        _fs = fs;
        _quoter = quoter;
    }

    public RenderKind? Detect(string output, string command, string cwd)
    {
        var parts = command.Trim().Split(' ', '\t').Where(p => p.Length > 0).ToArray();
        if (parts.Length == 0 || !Commands.Contains(parts[0])) return null;

        var showHidden = false;
        foreach (var arg in parts.Skip(1))
        {
            if (!arg.StartsWith('-')) return null; // listing another folder - fall through
            if (arg.Contains("Recurse", StringComparison.OrdinalIgnoreCase) || arg.Contains('R')) return null;
            if (arg.Contains("Force", StringComparison.OrdinalIgnoreCase) || arg.Contains('a')) showHidden = true;
        }

        var items = new List<CommandListItem>();
        foreach (var entry in _fs.ListEntries(cwd))
        {
            if (entry.IsHidden && !showHidden) continue;
            items.Add(new CommandListItem(
                Label: entry.Name,
                Detail: entry.IsDirectory ? "Open this folder (cd)" : "Open this file",
                Icon: entry.IsDirectory ? "folder" : DetectorUtil.IconForFile(entry.Name),
                FollowUp: entry.IsDirectory
                    ? $"cd {_quoter.Quote(entry.Name)}"
                    : $"Invoke-Item {_quoter.Quote(entry.Name)}"));
        }
        if (items.Count == 0) return null;

        items.Sort((a, b) =>
        {
            var aDir = a.Icon == "folder";
            var bDir = b.Icon == "folder";
            if (aDir != bDir) return aDir ? -1 : 1;
            return string.Compare(a.Label, b.Label, StringComparison.OrdinalIgnoreCase);
        });

        return new RenderKind.CommandList(
            "Click a folder to fill in “cd” (go into it) or a file to open it — then press Enter.",
            items);
    }
}

public sealed class GitLogOnelineDetector : IOutputDetector
{
    public RenderKind? Detect(string output, string command, string cwd)
    {
        var trimmed = command.Trim();
        if (!trimmed.StartsWith("git log") || !trimmed.Contains("--oneline")) return null;

        var items = new List<CommandListItem>();
        foreach (var rawLine in output.Split('\n'))
        {
            var line = rawLine.Trim();
            if (line.Length == 0) continue;
            var hash = line.Split(' ', 2)[0];
            if (hash.Length < 4 || !hash.All(Uri.IsHexDigit)) continue;
            items.Add(new CommandListItem(
                Label: line,
                Detail: "Show this commit (git show)",
                Icon: "clock",
                FollowUp: $"git show {hash}"));
        }
        if (items.Count == 0) return null;
        return new RenderKind.CommandList(
            "Click a commit to fill in “git show” — then press Enter to view it.",
            items);
    }
}

public sealed class GitTagDetector : IOutputDetector
{
    private readonly IShellQuoter _quoter;

    public GitTagDetector(IShellQuoter quoter) => _quoter = quoter;

    public RenderKind? Detect(string output, string command, string cwd)
    {
        var trimmed = command.Trim();
        if (trimmed != "git tag" && !trimmed.StartsWith("git tag -l") && !trimmed.StartsWith("git tag --list"))
            return null;

        var items = new List<CommandListItem>();
        foreach (var rawLine in output.Split('\n'))
        {
            var line = rawLine.Trim();
            if (line.Length == 0 || line.Contains(' ')) continue;
            items.Add(new CommandListItem(
                Label: line,
                Detail: "Check out this tag",
                Icon: "tag",
                FollowUp: $"git checkout {_quoter.Quote(line)}"));
        }
        if (items.Count == 0) return null;
        return new RenderKind.CommandList(
            "Click a tag to fill in “git checkout” — then press Enter to check it out.",
            items);
    }
}

/// <summary>
/// PowerShell `history` / `Get-History` output: an Id column followed by the
/// command line. Clicking a row loads that command into the command bar.
/// </summary>
public sealed class HistoryDetector : IOutputDetector
{
    private static readonly HashSet<string> Commands = new(StringComparer.OrdinalIgnoreCase)
    {
        "history", "h", "Get-History"
    };

    public RenderKind? Detect(string output, string command, string cwd)
    {
        var first = command.Trim().Split(' ', 2)[0];
        if (!Commands.Contains(first)) return null;

        var items = new List<CommandListItem>();
        foreach (var rawLine in output.Split('\n'))
        {
            var line = rawLine.Trim();
            if (line.Length == 0) continue;
            var pieces = line.Split(' ', 2, StringSplitOptions.RemoveEmptyEntries);
            if (pieces.Length != 2 || !int.TryParse(pieces[0], out _)) continue;
            var past = pieces[1].Trim();
            if (past.Length == 0) continue;
            items.Add(new CommandListItem(
                Label: past,
                Detail: "Use this command again",
                Icon: "history",
                FollowUp: past));
        }
        if (items.Count == 0) return null;
        if (items.Count > 200) items = items.Skip(items.Count - 200).ToList();
        return new RenderKind.CommandList(
            "Click a past command to load it into the command bar — then press Enter to run it again.",
            items);
    }
}

/// <summary>`cat` / `Get-Content` on an image file: show the picture instead of bytes.</summary>
public sealed class CatImageDetector : IOutputDetector
{
    private static readonly HashSet<string> Commands = new(StringComparer.OrdinalIgnoreCase)
    {
        "cat", "gc", "type", "Get-Content"
    };

    private readonly IFileSystem _fs;

    public CatImageDetector(IFileSystem fs) => _fs = fs;

    public RenderKind? Detect(string output, string command, string cwd)
    {
        var parts = command.Trim().Split(' ', '\t').Where(p => p.Length > 0).ToArray();
        if (parts.Length < 2 || !Commands.Contains(parts[0])) return null;

        var filePath = parts[^1];
        if (!DetectorUtil.ImageExtensions.Contains(System.IO.Path.GetExtension(filePath))) return null;

        var resolved = DetectorUtil.ResolvePath(filePath, cwd, _fs.HomeDirectory);
        return _fs.Exists(resolved) ? new RenderKind.ImageFile(resolved) : null;
    }
}

/// <summary>Output whose last line is an absolute path to an existing image: show it.</summary>
public sealed class ImagePathDetector : IOutputDetector
{
    private readonly IFileSystem _fs;

    public ImagePathDetector(IFileSystem fs) => _fs = fs;

    public RenderKind? Detect(string output, string command, string cwd)
    {
        var lastLine = output.Split('\n')
            .Select(l => l.Trim())
            .LastOrDefault(l => l.Length > 0);
        if (lastLine is null || !DetectorUtil.IsRooted(lastLine)) return null;
        if (!DetectorUtil.ImageExtensions.Contains(System.IO.Path.GetExtension(lastLine))) return null;
        return _fs.Exists(lastLine) ? new RenderKind.ImageFile(lastLine) : null;
    }
}

public sealed class JsonDetector : IOutputDetector
{
    public RenderKind? Detect(string output, string command, string cwd)
    {
        var trimmed = output.Trim();
        if (!trimmed.StartsWith('{') && !trimmed.StartsWith('[')) return null;
        if (trimmed.Split('\n').Length < 2) return null;
        try
        {
            using var _ = JsonDocument.Parse(trimmed);
            return new RenderKind.JsonTree();
        }
        catch (JsonException)
        {
            return null;
        }
    }
}

public sealed class CsvDetector : IOutputDetector
{
    public RenderKind? Detect(string output, string command, string cwd)
    {
        var lines = output.Split('\n').Where(l => l.Length > 0).ToArray();
        if (lines.Length < 2) return null;

        var firstLine = lines[0];
        var commas = firstLine.Count(c => c == ',');
        var tabs = firstLine.Count(c => c == '\t');
        char sep;
        if (commas >= 2) sep = ',';
        else if (tabs >= 1) sep = '\t';
        else return null;

        var expectedCols = firstLine.Split(sep).Length;
        if (expectedCols < 2) return null;

        var sample = Math.Min(lines.Length, 20);
        var consistent = lines.Take(sample).Count(l => l.Split(sep).Length == expectedCols);
        if ((double)consistent / sample < 0.8) return null;

        var rows = lines
            .Select(l => l.Split(sep).Select(c => c.Trim().Trim('"')).ToArray())
            .ToList();
        return new RenderKind.CsvTable(rows);
    }
}

public sealed class TableDetector : IOutputDetector
{
    private const int MinCols = 3;
    private const int MinRows = 3;
    private const int MaxRows = 500;

    private static readonly Regex MultiSpace = new("  +", RegexOptions.Compiled);

    public RenderKind? Detect(string output, string command, string cwd)
    {
        var lines = output.Split('\n').Where(l => l.Trim().Length > 0).ToArray();
        if (lines.Length < MinRows) return null;

        var rows = lines.Take(MaxRows).Select(SplitIntoColumns).ToList();

        var colCounts = rows.Select(r => r.Length).ToArray();
        var medianCols = colCounts.OrderBy(c => c).ElementAt(colCounts.Length / 2);
        if (medianCols < MinCols) return null;

        var consistent = colCounts.Count(c => Math.Abs(c - medianCols) <= 2);
        if ((double)consistent / colCounts.Length <= 0.7) return null;

        return new RenderKind.Table(rows);
    }

    private static string[] SplitIntoColumns(string line) =>
        MultiSpace.Replace(line, "\t")
            .Split('\t')
            .Select(c => c.Trim())
            .Where(c => c.Length > 0)
            .ToArray();
}
