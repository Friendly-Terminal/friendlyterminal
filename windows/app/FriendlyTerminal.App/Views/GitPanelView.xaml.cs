using System.ComponentModel;
using FriendlyTerminal.App.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

namespace FriendlyTerminal.App.Views;

/// <summary>
/// A small "GitHub Desktop"-style panel: see the current branch, check off files
/// to stage, write a message, and commit - then push. Hosted in a ContentDialog
/// opened from the branch chip in the breadcrumb bar.
/// </summary>
public sealed partial class GitPanelView : UserControl
{
    private readonly GitPanel _panel;
    private readonly SessionState _session;

    /// <summary>Raised when the panel ran a command in the terminal and the dialog should close.</summary>
    public event Action? DismissRequested;

    public GitPanelView(SessionState session)
    {
        _session = session;
        _panel = new GitPanel(session.CurrentDirectory);
        InitializeComponent();
        _panel.PropertyChanged += OnPanelChanged;
        _panel.Refresh();
    }

    private void OnPanelChanged(object? sender, PropertyChangedEventArgs e) => Render();

    private void Render()
    {
        BusyRing.IsActive = _panel.IsBusy;
        BranchText.Text = _panel.IsRepo ? $"On branch {_panel.Branch}" : "";
        PushLabel.Text = _panel.Ahead > 0 ? $"Push {_panel.Ahead}" : "Push";

        var staged = _panel.StagedCount;
        SummaryText.Text = _panel.IsRepo && _panel.Changes.Count > 0
            ? $"{_panel.Changes.Count} changed · {staged} staged"
            : "";
        StageAllButton.Content = staged == _panel.Changes.Count && staged > 0 ? "Unstage all" : "Stage all";
        StageAllButton.Visibility = _panel.IsRepo && _panel.Changes.Count > 0 ? Visibility.Visible : Visibility.Collapsed;

        ChangesPanel.Children.Clear();
        if (!_panel.IsRepo)
        {
            EmptyPanel.Visibility = Visibility.Visible;
            EmptyIcon.Glyph = "";
            EmptyText.Text = "This folder isn't a Git repository.";
            GitInitButton.Visibility = Visibility.Visible;
        }
        else if (_panel.Changes.Count == 0)
        {
            EmptyPanel.Visibility = Visibility.Visible;
            EmptyIcon.Glyph = "";
            EmptyText.Text = "Nothing to commit — working tree clean.";
            GitInitButton.Visibility = Visibility.Collapsed;
        }
        else
        {
            EmptyPanel.Visibility = Visibility.Collapsed;
            foreach (var change in _panel.Changes)
                ChangesPanel.Children.Add(BuildChangeRow(change));
        }

        UpdateCommitEnabled();
    }

    private UIElement BuildChangeRow(GitFileChange change)
    {
        var check = new CheckBox
        {
            IsChecked = change.IsStaged,
            MinWidth = 0,
            Padding = new Thickness(0),
        };
        check.Click += (_, _) => _panel.ToggleStage(change);

        var path = new TextBlock
        {
            Text = change.Path,
            FontFamily = new FontFamily("Consolas"),
            FontSize = 11,
            VerticalAlignment = VerticalAlignment.Center,
            TextTrimming = TextTrimming.CharacterEllipsis,
        };

        var status = new TextBlock
        {
            Text = change.StatusLabel,
            FontSize = 10,
            VerticalAlignment = VerticalAlignment.Center,
            Opacity = 0.7,
            Foreground = StatusBrush(change.StatusLabel),
        };

        var grid = new Grid { Padding = new Thickness(8, 4, 8, 4), ColumnSpacing = 8 };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        Grid.SetColumn(path, 1);
        Grid.SetColumn(status, 2);
        grid.Children.Add(check);
        grid.Children.Add(path);
        grid.Children.Add(status);
        ToolTipService.SetToolTip(grid, change.IsStaged ? "Staged — uncheck to unstage" : "Check to stage");
        return grid;
    }

    private static SolidColorBrush StatusBrush(string label) => label switch
    {
        "New" or "Added" => new SolidColorBrush(Microsoft.UI.Colors.SeaGreen),
        "Deleted" => new SolidColorBrush(Microsoft.UI.Colors.IndianRed),
        "Conflict" => new SolidColorBrush(Microsoft.UI.Colors.Orange),
        _ => new SolidColorBrush(Microsoft.UI.Colors.Gray),
    };

    private void UpdateCommitEnabled()
    {
        var staged = _panel.StagedCount;
        CommitButton.Content = staged > 0 ? $"Commit {staged} file{(staged == 1 ? "" : "s")}" : "Commit";
        CommitButton.IsEnabled = staged > 0
            && CommitMessage.Text.Trim().Length > 0
            && !_panel.IsBusy;
    }

    private void OnMessageChanged(object sender, TextChangedEventArgs e) => UpdateCommitEnabled();

    private void OnRefresh(object sender, RoutedEventArgs e) => _panel.Refresh();

    private void OnStageAll(object sender, RoutedEventArgs e)
    {
        if (_panel.StagedCount == _panel.Changes.Count && _panel.StagedCount > 0)
            _panel.UnstageAll();
        else
            _panel.StageAll();
    }

    private void OnCommit(object sender, RoutedEventArgs e)
    {
        _panel.Commit(CommitMessage.Text);
        CommitMessage.Text = "";
    }

    private void OnPush(object sender, RoutedEventArgs e)
    {
        _session.ExecuteCommand("git push");
        DismissRequested?.Invoke();
    }

    private void OnGitInit(object sender, RoutedEventArgs e)
    {
        _session.ExecuteCommand("git init");
        DismissRequested?.Invoke();
    }
}
