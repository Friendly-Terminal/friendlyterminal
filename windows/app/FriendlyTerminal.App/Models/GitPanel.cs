using System.ComponentModel;

namespace FriendlyTerminal.App.Models;

/// <summary>One changed file in the working tree, from `git status --porcelain`.
/// <see cref="Index"/> is the staged (X) column, <see cref="WorkTree"/> the unstaged (Y) column.</summary>
public sealed record GitFileChange(string Path, char Index, char WorkTree)
{
    public bool IsUntracked => Index == '?';
    public bool IsStaged => Index != ' ' && Index != '?';

    private char Primary => IsStaged ? Index : WorkTree;

    public string StatusLabel => IsUntracked ? "New" : Primary switch
    {
        'M' => "Modified",
        'A' => "Added",
        'D' => "Deleted",
        'R' => "Renamed",
        'C' => "Copied",
        'U' => "Conflict",
        _ => "Changed",
    };
}

/// <summary>
/// Backs the mini Git panel: lists changes, stages/unstages, and commits - each
/// a quick `git` subprocess off the UI thread. Pushing is left to the shell so
/// credential prompts surface in the terminal.
/// </summary>
public sealed class GitPanel : INotifyPropertyChanged
{
    private readonly string _path;
    private bool _isRepo = true;
    private string _branch = "";
    private List<GitFileChange> _changes = new();
    private int _ahead;
    private bool _isBusy;
    private int _seq;

    public GitPanel(string path) => _path = path;

    public bool IsRepo { get => _isRepo; private set => Set(ref _isRepo, value); }
    public string Branch { get => _branch; private set => Set(ref _branch, value); }
    public List<GitFileChange> Changes { get => _changes; private set => Set(ref _changes, value); }
    public int Ahead { get => _ahead; private set => Set(ref _ahead, value); }
    public bool IsBusy { get => _isBusy; private set => Set(ref _isBusy, value); }

    public int StagedCount => _changes.Count(c => c.IsStaged);

    public void Refresh() => Mutate(null);

    public void ToggleStage(GitFileChange change) =>
        Mutate(change.IsStaged
            ? $"restore --staged -- \"{change.Path}\""
            : $"add -- \"{change.Path}\"");

    public void StageAll() => Mutate("add -A");
    public void UnstageAll() => Mutate("reset -q");

    public void Commit(string message)
    {
        var trimmed = message.Trim();
        if (trimmed.Length == 0) return;
        Mutate($"commit -m \"{trimmed.Replace("\"", "\\\"")}\"");
    }

    private void Mutate(string? args)
    {
        IsBusy = true;
        var seq = ++_seq;
        var context = SynchronizationContext.Current;
        Task.Run(() =>
        {
            if (args is not null)
                SessionState.RunGit(_path, args);
            var snap = LoadSync(_path);

            void Apply()
            {
                // Latest-wins: a newer refresh has already superseded this snapshot.
                if (seq != _seq) return;
                IsRepo = snap.IsRepo;
                Branch = snap.Branch;
                Changes = snap.Changes;
                Ahead = snap.Ahead;
                IsBusy = false;
            }
            if (context is not null) context.Post(_ => Apply(), null);
            else Apply();
        });
    }

    private sealed record Snapshot(bool IsRepo, string Branch, List<GitFileChange> Changes, int Ahead);

    private static Snapshot LoadSync(string path)
    {
        var branch = SessionState.RunGit(path, "rev-parse --abbrev-ref HEAD");
        if (branch is null)
            return new Snapshot(false, "", new List<GitFileChange>(), 0);

        var porcelain = SessionState.RunGit(path, "status --porcelain", trim: false) ?? "";
        var changes = ParsePorcelain(porcelain);

        var ahead = 0;
        if (SessionState.RunGit(path, "rev-list --count --left-right @{upstream}...HEAD") is { } counts)
        {
            var parts = counts.Split(new[] { '\t', ' ' }, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length == 2 && int.TryParse(parts[1], out var n)) ahead = n;
        }
        return new Snapshot(true, branch, changes, ahead);
    }

    internal static List<GitFileChange> ParsePorcelain(string porcelain)
    {
        var result = new List<GitFileChange>();
        foreach (var line in porcelain.Split('\n'))
        {
            if (line.Length < 4) continue;
            var path = line[3..].Trim();
            var arrow = path.IndexOf(" -> ", StringComparison.Ordinal);
            if (arrow >= 0) path = path[(arrow + 4)..];
            path = path.Trim('"');
            if (path.Length == 0) continue;
            result.Add(new GitFileChange(path, line[0], line[1]));
        }
        return result;
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    private void Set<T>(ref T field, T value, [System.Runtime.CompilerServices.CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
