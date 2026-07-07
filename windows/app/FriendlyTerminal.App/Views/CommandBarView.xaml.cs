using System.ComponentModel;
using System.IO;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Windows.ApplicationModel.DataTransfer;
using Windows.System;

namespace FriendlyTerminal.App.Views;

/// <summary>
/// The friendly command line under the block list. Enter runs the command via
/// the session (so undo/interception apply); while Claude Code is running it
/// becomes the chat input instead. Tab completes paths like the macOS bar.
/// </summary>
public sealed partial class CommandBarView : UserControl
{
    private static readonly string[] DangerPatterns =
    {
        "rm -rf", "rm -fr", "rm -r", "sudo rm",
        "remove-item -recurse", "-recurse -force", "rd /s", "del /f", "del /s",
        "format-volume", "diskpart", "mkfs", "dd if=",
        "--dangerously-skip-permissions",
    };

    private SessionState? _session;

    public SessionState? Session
    {
        get => _session;
        set
        {
            if (_session is not null)
            {
                _session.PrefillRequested -= OnPrefill;
                _session.PropertyChanged -= OnSessionChanged;
            }
            _session = value;
            if (_session is null) return;
            _session.PrefillRequested += OnPrefill;
            _session.PropertyChanged += OnSessionChanged;
            UpdateMode();
        }
    }

    public CommandBarView()
    {
        InitializeComponent();
    }

    public void FocusInput() => Input.Focus(FocusState.Programmatic);

    private void OnPrefill(string command)
    {
        Input.Text = command;
        Input.SelectionStart = command.Length;
        CompletionHints.Visibility = Visibility.Collapsed;
        FocusInput();
    }

    private void OnSessionChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(SessionState.IsTuiActive) or nameof(SessionState.IsClaudeRunning))
            UpdateMode();
    }

    private void UpdateMode()
    {
        if (_session is null) return;
        var claude = _session.IsClaudeRunning;
        var blocked = _session.IsTuiActive && !claude;

        Input.PlaceholderText = claude
            ? "Message Claude, or type 1 / 2 / 3 to pick an option…"
            : "Run a command…";
        Input.IsEnabled = !blocked;
        SendButton.IsEnabled = !blocked;
        Opacity = blocked ? 0.4 : 1.0;
        if (claude) FocusInput();
    }

    private void OnKeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (e.Key == VirtualKey.Enter)
        {
            e.Handled = true;
            Submit();
        }
        else if (e.Key == VirtualKey.Tab && _session is not null && !_session.IsClaudeRunning)
        {
            e.Handled = true;
            HandleTabCompletion();
        }
        else if (e.Key != VirtualKey.Tab)
        {
            CompletionHints.Visibility = Visibility.Collapsed;
        }
    }

    private void OnSend(object sender, RoutedEventArgs e) => Submit();

    private async void Submit()
    {
        if (_session is null) return;
        CompletionHints.Visibility = Visibility.Collapsed;
        var text = Input.Text.Trim();
        if (text.Length == 0) return;

        if (_session.IsClaudeRunning)
        {
            _session.SendRaw(text + "\r");
            Input.Text = "";
            return;
        }

        if (IsDangerous(text))
        {
            var dialog = new ContentDialog
            {
                Title = "Dangerous command",
                Content = $"\"{text}\" can permanently delete files or modify system settings. This cannot be undone.",
                PrimaryButtonText = "Run anyway",
                CloseButtonText = "Cancel",
                DefaultButton = ContentDialogButton.Close,
                XamlRoot = XamlRoot,
            };
            if (await dialog.ShowAsync() != ContentDialogResult.Primary) return;
        }

        _session.ExecuteCommand(text);
        Input.Text = "";
    }

    private static bool IsDangerous(string command)
    {
        var lower = command.ToLowerInvariant();
        return DangerPatterns.Any(lower.Contains);
    }

    // MARK: - Drag & drop file paths

    private void OnDragOver(object sender, DragEventArgs e)
    {
        if (e.DataView.Contains(StandardDataFormats.StorageItems))
            e.AcceptedOperation = DataPackageOperation.Copy;
    }

    private async void OnDrop(object sender, DragEventArgs e)
    {
        if (!e.DataView.Contains(StandardDataFormats.StorageItems)) return;
        var items = await e.DataView.GetStorageItemsAsync();
        foreach (var item in items)
        {
            var path = item.Path;
            if (string.IsNullOrEmpty(path)) continue;
            var safe = path.Contains(' ') ? $"'{path.Replace("'", "''")}'" : path;
            Input.Text = Input.Text.Length == 0 ? safe : Input.Text + " " + safe;
        }
        Input.SelectionStart = Input.Text.Length;
        FocusInput();
    }

    // MARK: - Tab path completion

    /// <summary>
    /// Completes the path argument at the end of the input - directories only for
    /// `cd`, files and folders otherwise. A unique match fills in completely
    /// (folders gain a trailing backslash); multiple matches extend to the common
    /// prefix and list the candidates as a hint.
    /// </summary>
    private void HandleTabCompletion()
    {
        if (_session is null) return;
        var text = Input.Text;

        var lastSpace = text.LastIndexOf(' ');
        if (lastSpace < 0) return; // only complete an argument

        var head = text[..(lastSpace + 1)];
        var token = text[(lastSpace + 1)..];
        var firstWord = text.Split(' ')[0];
        var dirsOnly = firstWord is "cd" or "Set-Location" or "sl";

        if (token.StartsWith('\'') || token.StartsWith('"')) token = token[1..];

        string dirPart, partial;
        var slash = token.LastIndexOfAny(new[] { '\\', '/' });
        if (slash >= 0)
        {
            dirPart = token[..(slash + 1)];
            partial = token[(slash + 1)..];
        }
        else
        {
            dirPart = "";
            partial = token;
        }

        var baseDir = ResolveBaseDir(dirPart);
        var matches = MatchingEntries(baseDir, partial, dirsOnly);
        if (matches.Count == 0)
        {
            CompletionHints.Visibility = Visibility.Collapsed;
            return;
        }

        string newToken;
        if (matches.Count == 1)
        {
            newToken = dirPart + matches[0].Name + (matches[0].IsDir ? "\\" : "");
            CompletionHints.Visibility = Visibility.Collapsed;
        }
        else
        {
            var common = LongestCommonPrefix(matches.Select(m => m.Name).ToList());
            newToken = dirPart + (common.Length > partial.Length ? common : partial);
            CompletionHints.Text = string.Join("   ", matches.Select(m => m.IsDir ? m.Name + "\\" : m.Name));
            CompletionHints.Visibility = Visibility.Visible;
        }

        var rendered = newToken.Contains(' ') ? $"'{newToken.Replace("'", "''")}'" : newToken;
        Input.Text = head + rendered;
        Input.SelectionStart = Input.Text.Length;
    }

    private string ResolveBaseDir(string dirPart)
    {
        var cwd = _session?.CurrentDirectory ?? "";
        if (dirPart.Length == 0) return cwd;
        if (dirPart.StartsWith('~'))
        {
            var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            return home + dirPart[1..];
        }
        return Path.IsPathRooted(dirPart) ? dirPart : Path.Combine(cwd, dirPart);
    }

    private static List<(string Name, bool IsDir)> MatchingEntries(string baseDir, string partial, bool dirsOnly)
    {
        var result = new List<(string, bool)>();
        IEnumerable<string> children;
        try { children = Directory.EnumerateFileSystemEntries(baseDir); }
        catch { return result; }

        var wantHidden = partial.StartsWith('.');
        foreach (var full in children)
        {
            var name = Path.GetFileName(full);
            if (!wantHidden && name.StartsWith('.')) continue;
            if (!name.StartsWith(partial, StringComparison.OrdinalIgnoreCase)) continue;
            var isDir = Directory.Exists(full);
            if (dirsOnly && !isDir) continue;
            result.Add((name, isDir));
        }
        result.Sort((a, b) => string.Compare(a.Item1, b.Item1, StringComparison.OrdinalIgnoreCase));
        return result;
    }

    private static string LongestCommonPrefix(List<string> strings)
    {
        if (strings.Count == 0) return "";
        var prefix = strings[0];
        foreach (var s in strings.Skip(1))
        {
            while (prefix.Length > 0 && !s.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                prefix = prefix[..^1];
            if (prefix.Length == 0) break;
        }
        return prefix;
    }
}
