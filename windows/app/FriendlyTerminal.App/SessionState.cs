using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.CompilerServices;
using FriendlyTerminal.App.Models;
using FriendlyTerminal.Core.Output;
using FriendlyTerminal.Core.Platform;
using FriendlyTerminal.Core.ShellIntegration;
using FriendlyTerminal.Core.Undo;

namespace FriendlyTerminal.App;

public sealed record GitStatusInfo(string Branch, bool IsDirty, int UncommittedCount);

public sealed record BreadcrumbItem(string Name, string Path);

/// <summary>
/// Shared state for one terminal pane: working directory, file listing, command
/// blocks, TUI/Claude detection, git status, and undo. The host pane drives
/// <see cref="HandleShellEvent"/> from the parsed PTY stream (marshaled onto the
/// UI thread) and wires <see cref="SendToShell"/>.
/// </summary>
public sealed class SessionState : INotifyPropertyChanged
{
    private static readonly string[] WrapperTokens = { "sudo", "command", "exec", "time", "env" };

    private readonly PowerShellQuoter _quoter = new();
    private readonly UndoPlanner _undoPlanner;
    private readonly RmInterceptor _rmInterceptor;

    private string _currentDirectory = "";
    private bool _showHidden;
    private bool _isTuiActive;
    private bool _altScreenOn;
    private bool _bracketedPasteOn;
    private string _pendingCommandText = "";
    private GitStatusInfo? _gitStatus;
    private CancellationTokenSource? _gitCts;
    private (string Command, UndoPlan Plan)? _pendingUndo;

    public SessionState()
    {
        var fs = WindowsFileSystem.Instance;
        _undoPlanner = new UndoPlanner(fs, _quoter);
        _rmInterceptor = new RmInterceptor(fs);
        Blocks = new BlockStore(new OutputRenderingPipeline(fs, _quoter));
    }

    public Guid Id { get; } = Guid.NewGuid();

    public ObservableCollection<FileEntry> Files { get; } = new();

    public BlockStore Blocks { get; }

    /// <summary>Set by the host; sends text into the shell PTY (the caller adds the newline).</summary>
    public Action<string>? SendToShell { get; set; }

    /// <summary>Raised when a help/chip click wants to preload the command bar.</summary>
    public event Action<string>? PrefillRequested;

    public string CurrentDirectory
    {
        get => _currentDirectory;
        private set
        {
            if (SetField(ref _currentDirectory, value))
                OnPropertyChanged(nameof(Breadcrumbs));
        }
    }

    public bool ShowHidden
    {
        get => _showHidden;
        set
        {
            if (SetField(ref _showHidden, value))
                RefreshFiles();
        }
    }

    /// <summary>True while a full-screen or raw-mode program owns the keyboard.</summary>
    public bool IsTuiActive
    {
        get => _isTuiActive;
        private set
        {
            if (SetField(ref _isTuiActive, value))
                OnPropertyChanged(nameof(IsClaudeRunning));
        }
    }

    public GitStatusInfo? GitStatus
    {
        get => _gitStatus;
        private set => SetField(ref _gitStatus, value);
    }

    public bool IsClaudeRunning =>
        _isTuiActive && IsClaudeCommand(Blocks.CurrentBlock?.Command ?? "");

    public string? CurrentClaudeCommand =>
        IsClaudeRunning ? Blocks.CurrentBlock?.Command : null;

    public bool ClaudeRunsWithDangerousFlag =>
        CurrentClaudeCommand?.Contains("--dangerously-skip-permissions") ?? false;

    public IReadOnlyList<BreadcrumbItem> Breadcrumbs
    {
        get
        {
            var items = new List<BreadcrumbItem>();
            var parts = _currentDirectory.Split('\\', '/')
                .Where(p => p.Length > 0)
                .ToArray();
            var accumulated = "";
            foreach (var part in parts)
            {
                accumulated = accumulated.Length == 0 ? part + "\\" : Path.Combine(accumulated, part);
                items.Add(new BreadcrumbItem(part, accumulated));
            }
            return items;
        }
    }

    public int ItemCount => Files.Count;

    // MARK: - Shell events

    /// <summary>Apply one parsed shell-integration event. Must run on the UI thread.</summary>
    public void HandleShellEvent(ShellEvent evt)
    {
        switch (evt)
        {
            case ShellEvent.CommandText text:
                _pendingCommandText = text.Text;
                break;

            case ShellEvent.OutputStart:
                Blocks.StartBlock(_pendingCommandText, _currentDirectory);
                _pendingCommandText = "";
                _altScreenOn = false;
                _bracketedPasteOn = false;
                RefreshInteractive();
                break;

            case ShellEvent.CommandEnd end:
                Blocks.FinishBlock(end.ExitCode);
                AttachUndoPlan(end.ExitCode);
                AttachAdvice(end.ExitCode);
                _altScreenOn = false;
                _bracketedPasteOn = false;
                RefreshInteractive();
                RefreshFiles();
                RefreshGitStatus();
                break;

            case ShellEvent.Output output:
                if (!_isTuiActive)
                    Blocks.AppendOutput(output.Text);
                break;

            case ShellEvent.AltScreen alt:
                _altScreenOn = alt.On;
                RefreshInteractive();
                break;

            case ShellEvent.BracketedPaste paste:
                _bracketedPasteOn = paste.On;
                RefreshInteractive();
                break;

            case ShellEvent.CwdUpdate cwd:
                SetCurrentDirectory(cwd.Path);
                break;
        }
    }

    private void RefreshInteractive()
    {
        var commandRunning = Blocks.CurrentBlock is not null;
        var interactive = _altScreenOn || (_bracketedPasteOn && commandRunning);
        if (interactive != _isTuiActive)
            IsTuiActive = interactive;
        // Claude state depends on the current block even when TUI state didn't flip.
        OnPropertyChanged(nameof(IsClaudeRunning));
    }

    /// <summary>Is this command line launching Claude Code? Mirrors the macOS check.</summary>
    public static bool IsClaudeCommand(string command)
    {
        var lastStage = command.Split('|')[^1];
        foreach (var token in lastStage.Split(' ', '\t').Where(t => t.Length > 0))
        {
            if (token.Contains('=')) continue;
            if (WrapperTokens.Contains(token)) continue;
            var name = Path.GetFileNameWithoutExtension(token);
            return string.Equals(name, "claude", StringComparison.OrdinalIgnoreCase);
        }
        return false;
    }

    // MARK: - Commands

    public void SendRaw(string text) => SendToShell?.Invoke(text);

    public void PrefillCommand(string command) => PrefillRequested?.Invoke(command);

    /// <summary>Run a command through the shell; "\r" triggers the PSReadLine Enter
    /// handler so the block markers are emitted just like a typed command.</summary>
    public void ExecuteCommand(string command)
    {
        var trimmed = command.Trim();
        if (InterceptDeletion(trimmed)) return;
        _pendingUndo = _undoPlanner.Plan(trimmed, _currentDirectory) is { } plan ? (trimmed, plan) : null;
        SendToShell?.Invoke(trimmed + "\r");
    }

    public void NavigateShellTo(string path) => ExecuteCommand($"cd {_quoter.Quote(path)}");

    private void AttachUndoPlan(int exitCode)
    {
        var pending = _pendingUndo;
        _pendingUndo = null;
        if (exitCode != 0 || Blocks.LastFinishedBlock is not { } block) return;

        if (pending is { } p && p.Command == block.Command)
            block.UndoPlan = p.Plan;
        else
            block.UndoPlan = _undoPlanner.Plan(block.Command, block.Cwd, allowPreState: false);
    }

    /// <summary>When a command failed because the shell didn't recognize it,
    /// attach a "did you mean" correction the block can offer.</summary>
    private void AttachAdvice(int exitCode)
    {
        if (exitCode == 0 || Blocks.LastFinishedBlock is not { } block) return;
        if (Core.Help.CommandNotFound.ExtractMissingTerm(block.PlainText) is not { } term) return;
        block.DidYouMean = Core.Help.CommandNotFound.SuggestCorrection(block.Command, term);
    }

    public void UndoLastCommand()
    {
        if (Blocks.LastUndoableBlock is { } block)
            PerformUndo(block);
    }

    public void PerformUndo(CommandBlock block)
    {
        if (block.UndoPlan is not { } plan || block.IsUndone) return;
        var fs = WindowsFileSystem.Instance;
        foreach (var action in plan.Actions)
        {
            switch (action)
            {
                case UndoAction.Shell shell:
                    ExecuteCommand(shell.Command);
                    break;
                case UndoAction.Trash trash:
                    fs.MoveToTrash(trash.Path);
                    break;
                case UndoAction.Restore restore:
                    fs.RestoreFromTrash(restore.TrashedPath, restore.OriginalPath);
                    break;
            }
        }
        block.IsUndone = true;
        RefreshFiles();
        RefreshGitStatus();
    }

    /// <summary>
    /// Routes a simple `rm` to the app trash folder (restorable) instead of letting
    /// the shell delete permanently. Returns true when the command was handled.
    /// </summary>
    private bool InterceptDeletion(string command)
    {
        if (_rmInterceptor.SafeTargets(command, _currentDirectory) is not { } targets) return false;

        var fs = WindowsFileSystem.Instance;
        var restores = new List<UndoAction>();
        var moved = new List<string>();
        foreach (var path in targets)
        {
            if (fs.MoveToAppTrash(path) is { } trashed)
            {
                moved.Add(Path.GetFileName(path.TrimEnd('\\', '/')));
                restores.Add(new UndoAction.Restore(trashed, path));
            }
        }

        Blocks.StartBlock(command, _currentDirectory);
        if (moved.Count == 0)
        {
            Blocks.AppendOutput("Couldn't move those items to the trash.\n");
            Blocks.FinishBlock(1);
        }
        else
        {
            Blocks.AppendOutput(
                $"Moved {moved.Count} item{(moved.Count == 1 ? "" : "s")} to the trash: {string.Join(", ", moved)}\n");
            Blocks.FinishBlock(0);
            if (Blocks.LastFinishedBlock is { } block && restores.Count > 0)
            {
                block.UndoPlan = new UndoPlan(
                    $"Undo delete (restore {restores.Count} item{(restores.Count == 1 ? "" : "s")})",
                    restores);
            }
        }
        RefreshFiles();
        return true;
    }

    // MARK: - Directory & git

    public void SetCurrentDirectory(string path)
    {
        if (!string.Equals(path, _currentDirectory, StringComparison.OrdinalIgnoreCase))
            CurrentDirectory = path;
        // Refresh either way: contents can change without the directory changing.
        RefreshFiles();
        RefreshGitStatus();
    }

    public void RefreshFiles()
    {
        Files.Clear();
        foreach (var entry in FileEntry.List(_currentDirectory))
            if (_showHidden || !entry.IsHidden)
                Files.Add(entry);
        OnPropertyChanged(nameof(ItemCount));
    }

    public void RefreshGitStatus()
    {
        _gitCts?.Cancel();
        var cts = new CancellationTokenSource();
        _gitCts = cts;
        var path = _currentDirectory;
        var context = SynchronizationContext.Current;

        Task.Run(() =>
        {
            var status = QueryGitStatus(path);
            if (cts.Token.IsCancellationRequested) return;
            if (context is not null)
                context.Post(_ => { if (!cts.Token.IsCancellationRequested) GitStatus = status; }, null);
            else
                GitStatus = status;
        }, cts.Token);
    }

    private static GitStatusInfo? QueryGitStatus(string path)
    {
        var branch = RunGit(path, "rev-parse --abbrev-ref HEAD");
        if (branch is null) return null;
        var porcelain = RunGit(path, "status --porcelain") ?? "";
        var changed = porcelain.Split('\n').Count(l => l.Trim().Length > 0);
        return new GitStatusInfo(branch, changed > 0, changed);
    }

    /// <param name="trim">Pass false for porcelain output whose leading columns are significant.</param>
    internal static string? RunGit(string cwd, string args, bool trim = true)
    {
        try
        {
            using var p = Process.Start(new ProcessStartInfo
            {
                FileName = "git.exe",
                Arguments = $"-C \"{cwd}\" {args}",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true,
            });
            if (p is null) return null;
            var output = p.StandardOutput.ReadToEnd();
            p.WaitForExit(10_000);
            return p.ExitCode == 0 ? (trim ? output.Trim() : output) : null;
        }
        catch
        {
            return null;
        }
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    private void OnPropertyChanged([CallerMemberName] string? name = null)
        => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));

    private bool SetField<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return false;
        field = value;
        OnPropertyChanged(name);
        return true;
    }
}
