using System.ComponentModel;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace FriendlyTerminal.App.Views;

/// <summary>
/// The left column: files on top; below, the panel follows what the terminal is
/// doing - Claude controls while Claude runs, program hints while another TUI
/// owns the keyboard, otherwise project commands + command help.
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
            ClaudeBar.Session = value;
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
        if (e.PropertyName is nameof(SessionState.IsTuiActive) or nameof(SessionState.IsClaudeRunning))
            UpdateMode();
    }

    private void UpdateMode()
    {
        var tui = _session?.IsTuiActive == true;
        var claude = _session?.IsClaudeRunning == true;

        ClaudeBar.Visibility = tui && claude ? Visibility.Visible : Visibility.Collapsed;
        HintView.Visibility = tui && !claude ? Visibility.Visible : Visibility.Collapsed;
        HelpStack.Visibility = tui ? Visibility.Collapsed : Visibility.Visible;

        if (tui && claude)
            ClaudeBar.Render();
        else if (tui)
            HintView.Render();
    }
}
