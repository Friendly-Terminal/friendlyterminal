using System.IO;
using FriendlyTerminal.App.Views;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Windows.System;

namespace FriendlyTerminal.App;

public sealed partial class MainWindow : Window
{
    private const int MaxPanes = 6;

    private readonly List<TerminalPaneView> _panes = new();
    private TerminalPaneView? _focused;
    private bool _sidebarVisible = true;

    public MainWindow()
    {
        InitializeComponent();

        Breadcrumb.SidebarToggleRequested += ToggleSidebar;
        Breadcrumb.AddPaneRequested += AddPane;

        AddPane();
        RegisterAccelerators();

        Models.CommandNotifier.Initialize(DispatcherQueue);
        Models.CommandNotifier.ActivateWindow = Activate;
        Activated += (_, e) =>
            Models.CommandNotifier.WindowIsActive = e.WindowActivationState != WindowActivationState.Deactivated;

        Closed += OnClosed;

        try { SystemBackdrop = new MicaBackdrop(); }
        catch { /* Mica isn't available on this OS build; fall back to the default backdrop. */ }

        RootGrid.Loaded += (_, _) => OnboardingTour.StartIfFirstLaunch(this);
    }

    public SessionState? FocusedSession => _focused?.Session;

    internal BreadcrumbBarView BreadcrumbBar => Breadcrumb;
    internal SidebarColumnView SidebarColumn => Sidebar;
    internal TerminalPaneView? FocusedPane => _focused;
    internal Grid Root => RootGrid;

    private void OnClosed(object sender, WindowEventArgs args)
    {
        Models.CommandNotifier.Shutdown();
        foreach (var pane in _panes)
            pane.Shutdown();
    }

    // MARK: - Workspace (panes)

    private void AddPane()
    {
        if (_panes.Count >= MaxPanes) return;

        var pane = new TerminalPaneView();
        pane.Exited += OnPaneExited;
        pane.CloseRequested += ClosePane;
        pane.FocusRequested += FocusPane;

        PaneHost.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        Grid.SetColumn(pane, _panes.Count);
        PaneHost.Children.Add(pane);
        _panes.Add(pane);

        FocusPane(pane);
        UpdatePaneChrome();
    }

    private void ClosePane(TerminalPaneView pane)
    {
        if (_panes.Count <= 1) return;
        RemovePane(pane);
    }

    private void OnPaneExited(TerminalPaneView pane)
    {
        // The shell ended on its own (e.g. `exit`): close the pane, or the app
        // when it was the last one.
        if (_panes.Count <= 1)
        {
            Close();
            return;
        }
        RemovePane(pane);
    }

    private void RemovePane(TerminalPaneView pane)
    {
        var index = _panes.IndexOf(pane);
        if (index < 0) return;

        pane.Shutdown();
        _panes.RemoveAt(index);
        PaneHost.Children.Remove(pane);
        PaneHost.ColumnDefinitions.RemoveAt(PaneHost.ColumnDefinitions.Count - 1);
        for (var i = 0; i < _panes.Count; i++)
            Grid.SetColumn(_panes[i], i);

        if (_focused == pane)
            FocusPane(_panes[0]);
        UpdatePaneChrome();
    }

    private void FocusPane(TerminalPaneView pane)
    {
        if (_focused == pane) return;
        _focused = pane;
        foreach (var p in _panes)
            p.IsFocusedPane = p == pane;

        Sidebar.Session = pane.Session;
        Breadcrumb.Session = pane.Session;
    }

    private void UpdatePaneChrome()
    {
        var split = _panes.Count > 1;
        foreach (var pane in _panes)
        {
            pane.ShowHeader = split;
            pane.IsFocusedPane = pane == _focused;
        }
        Breadcrumb.CanAddPane = _panes.Count < MaxPanes;
    }

    // MARK: - Sidebar & shortcuts

    private void ToggleSidebar()
    {
        _sidebarVisible = !_sidebarVisible;
        SidebarHost.Visibility = _sidebarVisible ? Visibility.Visible : Visibility.Collapsed;
    }

    private void RegisterAccelerators()
    {
        void Add(VirtualKey key, VirtualKeyModifiers modifiers, Action action)
        {
            var accelerator = new KeyboardAccelerator { Key = key, Modifiers = modifiers };
            accelerator.Invoked += (_, e) =>
            {
                action();
                e.Handled = true;
            };
            RootGrid.KeyboardAccelerators.Add(accelerator);
        }

        // Ctrl+B: toggle sidebar
        Add(VirtualKey.B, VirtualKeyModifiers.Control, ToggleSidebar);
        // Ctrl+Shift+D: split (add another terminal)
        Add(VirtualKey.D, VirtualKeyModifiers.Control | VirtualKeyModifiers.Shift, AddPane);
        // Ctrl+K: clear the block list
        Add(VirtualKey.K, VirtualKeyModifiers.Control, () => FocusedSession?.Blocks.Clear());
        // Ctrl+Shift+Z: undo the last undoable command
        Add(VirtualKey.Z, VirtualKeyModifiers.Control | VirtualKeyModifiers.Shift,
            () => FocusedSession?.UndoLastCommand());
        // Ctrl+Shift+C: interrupt (Ctrl+C into the shell)
        Add(VirtualKey.C, VirtualKeyModifiers.Control | VirtualKeyModifiers.Shift,
            () => FocusedSession?.SendRaw(((char)0x03).ToString()));
        // F1: replay the welcome tour
        Add(VirtualKey.F1, VirtualKeyModifiers.None, () => OnboardingTour.Start(this));
    }
}

/// <summary>
/// TeachingTip-based welcome tour, the Windows counterpart of the macOS
/// coachmark overlay. Walks new users through the main parts of the window.
/// </summary>
internal static class OnboardingTour
{
    private static string MarkerPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "FriendlyTerminal", "onboarding-done");

    private sealed record Step(string Title, string Message, Func<MainWindow, FrameworkElement?> Target);

    private static readonly Step[] Steps =
    {
        new("Welcome to FriendlyTerminal",
            "A friendlier way to use the terminal. Here's a quick 30-second tour of the main parts — you can skip it anytime.",
            _ => null),
        new("Run commands here",
            "Type a command and press Enter to run it. Each command and its output are grouped into a tidy block above.",
            w => w.FocusedPane?.CommandBarTarget),
        new("Browse your files",
            "This shows the folder you're currently in. Click a folder to move into it, or a file to open it — no commands needed.",
            w => w.SidebarColumn.FilesTarget),
        new("Find the right command",
            "Not sure what to type? Search or browse common commands by category, then tap one to drop it into the command bar.",
            w => w.SidebarColumn.HelpTarget),
        new("Know where you are",
            "This trail shows the folder you're in. Click any part of it to jump straight to that folder.",
            w => w.BreadcrumbBar.CrumbsTarget),
        new("Work side by side",
            "Open another terminal next to this one when you want to do two things at once. You can have several at a time.",
            w => w.BreadcrumbBar.AddPaneTarget),
        new("Chat with Claude AI",
            "Click here to start Claude Code — an AI that reads your files, fixes bugs, and builds features. While Claude is running, the sidebar becomes a control panel with clickable buttons.",
            w => w.BreadcrumbBar.ClaudeTarget),
        new("You're all set",
            "That's the tour. You can replay it anytime with F1. Happy exploring!",
            _ => null),
    };

    public static void StartIfFirstLaunch(MainWindow window)
    {
        if (File.Exists(MarkerPath)) return;
        Start(window);
    }

    public static void Start(MainWindow window) => ShowStep(window, 0);

    private static void ShowStep(MainWindow window, int index)
    {
        if (index >= Steps.Length)
        {
            MarkDone();
            return;
        }

        var step = Steps[index];
        var isLast = index == Steps.Length - 1;

        var tip = new TeachingTip
        {
            Title = step.Title,
            Subtitle = $"{step.Message}\n\nStep {index + 1} of {Steps.Length}",
            Target = step.Target(window),
            PreferredPlacement = TeachingTipPlacementMode.Auto,
            ActionButtonContent = isLast ? "Done" : "Next",
            CloseButtonContent = isLast ? null : "Skip",
            IsLightDismissEnabled = false,
        };

        var advanced = false;
        tip.ActionButtonClick += (t, _) =>
        {
            advanced = true;
            t.IsOpen = false;
        };
        tip.Closed += (t, _) =>
        {
            window.Root.Children.Remove(t);
            if (advanced)
                ShowStep(window, index + 1);
            else
                MarkDone(); // skipped or dismissed
        };

        window.Root.Children.Add(tip);
        tip.IsOpen = true;
    }

    private static void MarkDone()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(MarkerPath)!);
            File.WriteAllText(MarkerPath, "");
        }
        catch { }
    }
}
