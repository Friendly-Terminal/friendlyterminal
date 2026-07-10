using System.Text.RegularExpressions;

namespace FriendlyTerminal.Core.Help;

/// <summary>
/// Cleans up text pasted into the command bar. Docs and tutorials prefix commands
/// with prompt symbols ("$ ", "PS C:\&gt; ", "&gt; ") that break when pasted verbatim,
/// and multi-line snippets shouldn't run in one uncontrolled burst. The view shows
/// the user exactly what was changed and why.
/// </summary>
public static class PasteRescue
{
    /// <param name="Lines">The runnable command lines, prompt prefixes removed.</param>
    /// <param name="RemovedPrefix">The first prompt symbol that was stripped, for the notice; null when nothing was removed.</param>
    /// <param name="SkippedComments">Lines dropped because they were only a # comment.</param>
    public sealed record Result(IReadOnlyList<string> Lines, string? RemovedPrefix, int SkippedComments);

    // Order matters: the PS/cmd prompts start with characters the generic
    // patterns would also match. "$" and ">" require trailing whitespace so
    // real syntax like $env:PATH or redirection is never touched.
    private static readonly (Regex Pattern, string Label)[] PromptPrefixes =
    {
        (new Regex(@"^PS(\s[^>]*)?>\s?"), "PS>"),
        (new Regex(@"^[A-Za-z]:\\[^>]*>\s?"), "C:\\>"),
        (new Regex(@"^\$\s+"), "$"),
        (new Regex(@"^>\s+"), ">"),
    };

    public static Result Clean(string pasted)
    {
        var lines = new List<string>();
        string? removed = null;
        var skippedComments = 0;

        foreach (var raw in pasted.Split('\n'))
        {
            var line = raw.Trim('\r', ' ', '\t');
            if (line.Length == 0) continue;

            foreach (var (pattern, label) in PromptPrefixes)
            {
                var match = pattern.Match(line);
                if (!match.Success) continue;
                line = line[match.Length..].TrimStart();
                removed ??= label;
                break;
            }

            if (line.Length == 0) continue;
            if (line.StartsWith('#'))
            {
                skippedComments++;
                continue;
            }
            lines.Add(line);
        }

        return new Result(lines, removed, skippedComments);
    }
}
