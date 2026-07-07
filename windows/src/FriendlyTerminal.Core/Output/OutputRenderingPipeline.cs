using FriendlyTerminal.Core.Platform;

namespace FriendlyTerminal.Core.Output;

/// <summary>
/// Runs the detectors in priority order and returns the first match, or null if
/// the output should stay plain text. Command-specific "list" detectors run
/// first so their output isn't mistaken for a generic table.
/// </summary>
public sealed class OutputRenderingPipeline
{
    private readonly IReadOnlyList<IOutputDetector> _detectors;

    public OutputRenderingPipeline(IFileSystem fs, IShellQuoter quoter)
    {
        _detectors = new IOutputDetector[]
        {
            new LsListingDetector(fs, quoter),
            new GitBranchDetector(quoter),
            new GitStatusDetector(quoter),
            new GitLogOnelineDetector(),
            new GitTagDetector(quoter),
            new HistoryDetector(),
            new CatImageDetector(fs),
            new ImagePathDetector(fs),
            new JsonDetector(),
            new CsvDetector(),
            new TableDetector(),
        };
    }

    public RenderKind? Process(string output, string command, string cwd)
    {
        if (string.IsNullOrEmpty(output)) return null;
        foreach (var detector in _detectors)
        {
            if (detector.Detect(output, command, cwd) is { } kind)
                return kind;
        }
        return null;
    }
}
