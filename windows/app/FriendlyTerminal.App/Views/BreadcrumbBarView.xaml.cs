using System.ComponentModel;
using FriendlyTerminal.App.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

namespace FriendlyTerminal.App.Views;

/// <summary>
/// The bar above the terminal: sidebar toggle, clickable folder trail, git
/// branch chip, Claude launcher, process panel, refresh, and add-pane.
/// </summary>
public sealed partial class BreadcrumbBarView : UserControl
{
    private SessionState? _session;
    private readonly ClaudeInstallChecker _checker = ClaudeInstallChecker.Instance;

    public event Action? SidebarToggleRequested;
    public event Action? AddPaneRequested;

    /// <summary>Tour targets for onboarding.</summary>
    public FrameworkElement AddPaneTarget => AddPaneButton;
    public FrameworkElement ClaudeTarget => ClaudeButton.Visibility == Visibility.Visible
        ? ClaudeButton
        : ClaudeSetupButton;
    public FrameworkElement CrumbsTarget => CrumbScroller;

    public SessionState? Session
    {
        get => _session;
        set
        {
            if (_session is not null)
                _session.PropertyChanged -= OnSessionChanged;
            _session = value;
            if (_session is null) return;
            _session.PropertyChanged += OnSessionChanged;
            RenderCrumbs();
            RenderGit();
        }
    }

    public BreadcrumbBarView()
    {
        InitializeComponent();
        _checker.PropertyChanged += OnCheckerChanged;
        Unloaded += (_, _) => _checker.PropertyChanged -= OnCheckerChanged;
        _checker.Check();
        RenderClaudeButton();
    }

    public bool CanAddPane
    {
        set => AddPaneButton.IsEnabled = value;
    }

    private void OnSessionChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(SessionState.CurrentDirectory))
            RenderCrumbs();
        else if (e.PropertyName == nameof(SessionState.GitStatus))
            RenderGit();
    }

    private void OnCheckerChanged(object? sender, PropertyChangedEventArgs e) => RenderClaudeButton();

    private void RenderCrumbs()
    {
        CrumbsPanel.Children.Clear();
        if (_session is null) return;

        var crumbs = _session.Breadcrumbs;
        for (var i = 0; i < crumbs.Count; i++)
        {
            if (i > 0)
            {
                CrumbsPanel.Children.Add(new FontIcon
                {
                    FontFamily = (FontFamily)Application.Current.Resources["SymbolThemeFontFamily"],
                    FontSize = 9,
                    Glyph = char.ConvertFromUtf32(0xE76C), // ChevronRight
                    Opacity = 0.45,
                    VerticalAlignment = VerticalAlignment.Center,
                });
            }

            var isLast = i == crumbs.Count - 1;
            var crumb = crumbs[i];
            var button = new Button
            {
                Content = new TextBlock
                {
                    Text = crumb.Name,
                    FontSize = 12,
                    FontWeight = isLast ? Microsoft.UI.Text.FontWeights.SemiBold : Microsoft.UI.Text.FontWeights.Normal,
                    Opacity = isLast ? 1.0 : 0.7,
                },
                Padding = new Thickness(4, 2, 4, 2),
                Background = null,
                BorderThickness = new Thickness(0),
            };
            ToolTipService.SetToolTip(button, crumb.Path);
            var path = crumb.Path;
            button.Click += (_, _) => _session?.NavigateShellTo(path);
            CrumbsPanel.Children.Add(button);
        }

        // Keep the trail pinned to the current folder when it overflows.
        DispatcherQueue.TryEnqueue(() =>
            CrumbScroller.ChangeView(CrumbScroller.ScrollableWidth, null, null, disableAnimation: true));
    }

    private void RenderGit()
    {
        var git = _session?.GitStatus;
        GitChip.Visibility = git is null ? Visibility.Collapsed : Visibility.Visible;
        if (git is null) return;
        GitBranchText.Text = git.Branch;
        GitDirtyText.Text = $"·{git.UncommittedCount}";
        GitDirtyText.Visibility = git.IsDirty ? Visibility.Visible : Visibility.Collapsed;
        ToolTipService.SetToolTip(GitChip, git.IsDirty
            ? $"{git.UncommittedCount} uncommitted file(s) — open Source Control"
            : "Clean working tree — open Source Control");
    }

    private void RenderClaudeButton()
    {
        ClaudeButton.Visibility = Visibility.Collapsed;
        ClaudeSetupButton.Visibility = Visibility.Collapsed;
        ClaudeChecking.Visibility = Visibility.Collapsed;
        ClaudeChecking.IsActive = false;

        switch (_checker.ClaudeState)
        {
            case ClaudeInstallChecker.State.Installed:
                ClaudeButton.Visibility = Visibility.Visible;
                break;
            case ClaudeInstallChecker.State.NotInstalled:
                ClaudeSetupButton.Visibility = Visibility.Visible;
                break;
            case ClaudeInstallChecker.State.Checking:
                ClaudeChecking.Visibility = Visibility.Visible;
                ClaudeChecking.IsActive = true;
                break;
        }
    }

    private void OnToggleSidebar(object sender, RoutedEventArgs e) => SidebarToggleRequested?.Invoke();
    private void OnAddPane(object sender, RoutedEventArgs e) => AddPaneRequested?.Invoke();
    private void OnRefresh(object sender, RoutedEventArgs e) => _session?.RefreshFiles();

    private void OnClaudeNew(object sender, RoutedEventArgs e) => _session?.ExecuteCommand(ClaudeCommand(null));
    private void OnClaudeContinue(object sender, RoutedEventArgs e) => _session?.ExecuteCommand(ClaudeCommand("--continue"));
    private void OnClaudeResume(object sender, RoutedEventArgs e) => _session?.ExecuteCommand(ClaudeCommand("--resume"));

    // Launch the resolved Claude executable via PowerShell's call operator; a fallback
    // install isn't on PATH, so bare `claude` would be command-not-found there. Only
    // drop to bare `claude` when no path was resolved.
    private string ClaudeCommand(string? args)
    {
        var path = _checker.ClaudePath;
        var launcher = string.IsNullOrEmpty(path) ? "claude" : $"& \"{path}\"";
        return string.IsNullOrEmpty(args) ? launcher : $"{launcher} {args}";
    }

    private async void OnClaudeDoctor(object sender, RoutedEventArgs e)
    {
        if (_session is null) return;
        var view = new ClaudeDoctorView(_session);
        var dialog = new ContentDialog
        {
            Title = "Claude Code Setup",
            Content = view,
            CloseButtonText = "Done",
            XamlRoot = XamlRoot,
        };
        view.DismissRequested += () => dialog.Hide();
        await dialog.ShowAsync();
    }

    private async void OnGitChip(object sender, RoutedEventArgs e)
    {
        if (_session is null) return;
        var view = new GitPanelView(_session);
        var dialog = new ContentDialog
        {
            Title = "Source Control",
            Content = view,
            CloseButtonText = "Done",
            XamlRoot = XamlRoot,
        };
        view.DismissRequested += () => dialog.Hide();
        await dialog.ShowAsync();
        _session.RefreshGitStatus();
    }

    private async void OnProcessPanel(object sender, RoutedEventArgs e)
    {
        var dialog = new ContentDialog
        {
            Title = "What's Running",
            Content = new ProcessPanelView(),
            CloseButtonText = "Done",
            XamlRoot = XamlRoot,
        };
        await dialog.ShowAsync();
    }
}
