using System.ComponentModel;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace FriendlyTerminal.App.Views;

/// <summary>
/// The left column: files on top; below, the panel follows what the terminal is
/// doing - agent controls while a recognized AI agent runs, program hints while
/// another TUI owns the keyboard, otherwise project commands + command help.
/// </summary>
public sealed partial class SidebarColumnView : UserControl
{
    private SessionState? _session;

    /// <summary>Tour targets for onboarding.</summary>
    public FrameworkElement FilesTarget => FilesView;
    public FrameworkElement HelpTarget => HelpStack;

    public SessionState? Session
    {
        get => _session;
        set
        {
            if (_session is not null)
                _session.PropertyChanged -= OnSessionChanged;
            _session = value;
            FilesView.Session = value;
            HelpView.Session = value;
            ProjectView.Session = value;
            AgentBar.Session = value;
            HintView.Session = value;
            if (_session is not null)
                _session.PropertyChanged += OnSessionChanged;
            UpdateMode();
        }
    }

    public SidebarColumnView()
    {
        InitializeComponent();
    }

    private void OnSessionChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(SessionState.IsTuiActive) or nameof(SessionState.IsAgentRunning))
            UpdateMode();
    }

    private void UpdateMode()
    {
        var tui = _session?.IsTuiActive == true;
        var agent = _session?.IsAgentRunning == true;

        AgentBar.Visibility = tui && agent ? Visibility.Visible : Visibility.Collapsed;
        HintView.Visibility = tui && !agent ? Visibility.Visible : Visibility.Collapsed;
        HelpStack.Visibility = tui ? Visibility.Collapsed : Visibility.Visible;

        if (tui && agent)
            AgentBar.Render();
        else if (tui)
            HintView.Render();
    }
}
