using System.Text;
using FriendlyTerminal.Core.Platform;

namespace FriendlyTerminal.Core.Undo;

public sealed class RmInterceptor
{
    private static readonly char[] UnsafeChars = "*?[]{}|&;<>$`~".ToCharArray();
    private static readonly HashSet<char> AllowedFlags = new("rfRdiv");

    // Aliases and cmdlets that delete: rm/del/erase/ri/rmdir/rd map to
    // Remove-Item in PowerShell. Matched case-insensitively.
    private static readonly HashSet<string> DeleteCommands =
        new(new[] { "rm", "del", "erase", "ri", "rmdir", "rd", "remove-item" },
            StringComparer.OrdinalIgnoreCase);

    private readonly IFileSystem _fs;

    public RmInterceptor(IFileSystem fs) => _fs = fs;

    public IReadOnlyList<string>? SafeTargets(string command, string cwd)
    {
        var trimmed = command.Trim();
        if (trimmed.Length == 0) return null;
        if (!TryTokenize(trimmed, out var parts)) return null;
        if (parts.Count == 0 || !DeleteCommands.Contains(parts[0])) return null;

        var targets = new List<string>();
        foreach (var arg in parts.Skip(1))
        {
            if (arg.StartsWith('-'))
            {
                if (!IsAcceptedFlag(arg)) return null;
                continue;
            }
            if (arg.Length == 0) return null;
            if (arg.IndexOfAny(UnsafeChars) >= 0) return null;
            var path = PathUtil.Resolve(arg, cwd, _fs.HomeDirectory);
            if (!_fs.Exists(path)) return null;
            targets.Add(path);
        }

        return targets.Count == 0 ? null : targets;
    }

    // Accepts POSIX bundled short flags (-rf, -r) and PowerShell switches given as
    // an unambiguous prefix of -Recurse or -Force (e.g. -re, -fo, -Recurse).
    private static bool IsAcceptedFlag(string arg)
    {
        var body = arg[1..];
        if (body.Length == 0) return false;
        if (body.All(AllowedFlags.Contains)) return true;
        return IsPrefixOf(body, "recurse") || IsPrefixOf(body, "force");
    }

    private static bool IsPrefixOf(string value, string full) =>
        value.Length <= full.Length &&
        full.StartsWith(value, StringComparison.OrdinalIgnoreCase);

    // Whitespace-splits while honoring single/double quotes so paths with spaces
    // survive as one token. Unbalanced quotes reject the command outright.
    private static bool TryTokenize(string input, out List<string> tokens)
    {
        tokens = new List<string>();
        var sb = new StringBuilder();
        var inToken = false;

        for (var i = 0; i < input.Length; i++)
        {
            var c = input[i];
            if (c is '\'' or '"')
            {
                inToken = true;
                var quote = c;
                i++;
                var closed = false;
                for (; i < input.Length; i++)
                {
                    if (input[i] == quote) { closed = true; break; }
                    sb.Append(input[i]);
                }
                if (!closed) return false;
                continue;
            }
            if (c is ' ' or '\t')
            {
                if (inToken) { tokens.Add(sb.ToString()); sb.Clear(); inToken = false; }
                continue;
            }
            inToken = true;
            sb.Append(c);
        }
        if (inToken) tokens.Add(sb.ToString());
        return true;
    }
}
