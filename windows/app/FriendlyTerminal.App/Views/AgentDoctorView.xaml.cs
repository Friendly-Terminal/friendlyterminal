using System.ComponentModel;
using FriendlyTerminal.App.Models;
using FriendlyTerminal.Core.Agents;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Shapes;
using Windows.ApplicationModel.DataTransfer;

namespace FriendlyTerminal.App.Views;

/// <summary>
/// Setup checks for one AI agent: Node.js (when the tool needs it), the CLI,
/// credentials, and MCP servers, each with a status dot and a fix action where one
/// exists. Probes the active agent's profile, falling back to Claude.
/// </summary>
public sealed partial class AgentDoctorView : UserControl
{
    private readonly SessionState _session;
    private readonly AgentProfile _profile;
    private readonly AgentInstallChecker _checker;
    private readonly string? _installCommand;

    public event Action? DismissRequested;

    public AgentDoctorView(SessionState session, AgentProfile profile)
    {
        _session = session;
        _profile = profile;
        _checker = AgentInstallChecker.For(profile);
        // Only Claude ships a known one-line installer; other tools guide the user
        // to install themselves rather than inventing a package name.
        _installCommand = profile.Id == "claude" ? "npm install -g @anthropic-ai/claude-code" : null;
        InitializeComponent();
        InstallTitle.Text = $"Install {profile.DisplayName}";
        if (_installCommand is not null) InstallCommandText.Text = _installCommand;
        _checker.PropertyChanged += OnCheckerChanged;
        Unloaded += (_, _) => _checker.PropertyChanged -= OnCheckerChanged;
        _checker.Check();
        Render();
    }

    private void OnCheckerChanged(object? sender, PropertyChangedEventArgs e) => Render();

    private void Render()
    {
        CheckingRing.IsActive = _checker.AgentState == AgentInstallChecker.State.Checking;
        InstallSection.Visibility =
            _checker.AgentState == AgentInstallChecker.State.NotInstalled && _installCommand is not null
                ? Visibility.Visible
                : Visibility.Collapsed;

        RowsPanel.Children.Clear();

        // Node.js (only when the tool is Node-based)
        if (_profile.RequiresNode)
        {
            var nodeOk = _checker.NodeState == AgentInstallChecker.State.Installed;
            RowsPanel.Children.Add(BuildRow(
                "Node.js",
                _checker.NodeState switch
                {
                    AgentInstallChecker.State.Installed => _checker.NodeVersion ?? "Installed",
                    AgentInstallChecker.State.NotInstalled => "Not installed",
                    _ => "Checking…",
                },
                nodeOk ? Microsoft.UI.Colors.SeaGreen : Microsoft.UI.Colors.IndianRed,
                nodeOk ? $"{_profile.DisplayName} is built on Node.js. All good." : $"Node.js is required by {_profile.DisplayName}.",
                nodeOk ? null : ("Open nodejs.org", () =>
                {
                    _session.ExecuteCommand("Start-Process https://nodejs.org");
                    DismissRequested?.Invoke();
                })));
        }

        // Agent CLI
        var agentOk = _checker.AgentState == AgentInstallChecker.State.Installed;
        RowsPanel.Children.Add(BuildRow(
            $"{_profile.DisplayName} CLI",
            _checker.AgentState switch
            {
                AgentInstallChecker.State.Installed => _checker.AgentVersion ?? "Installed",
                AgentInstallChecker.State.NotInstalled => "Not installed",
                _ => "Checking…",
            },
            agentOk ? Microsoft.UI.Colors.SeaGreen : Microsoft.UI.Colors.IndianRed,
            agentOk
                ? (_checker.AgentPath is { } p ? $"Found at {p}" : "")
                : _installCommand is not null
                    ? "Run the install command below, then re-check."
                    : $"Install {_profile.DisplayName} and put it on your PATH, then re-check.",
            agentOk || _installCommand is null ? null : ($"Install {_profile.DisplayName}", RunInstall)));

        // Auth
        var (authText, authColor, authDetail) = _checker.Auth switch
        {
            AgentInstallChecker.AuthState.Authenticated =>
                ("Configured", Microsoft.UI.Colors.SeaGreen, "Credentials found — you're ready to go."),
            AgentInstallChecker.AuthState.NotAuthenticated =>
                ("Not set up", Microsoft.UI.Colors.IndianRed, $"Sign in to {_profile.DisplayName} to connect your account."),
            _ => ("Unknown", Microsoft.UI.Colors.Orange,
                $"Could not verify. Try running {_profile.DisplayName} in the terminal to check."),
        };
        // "claude login" is not a real subcommand: launch the resolved install and let
        // the user run /login inside the session.
        (string, Action)? authFix = _profile.Id == "claude"
            && _checker.Auth == AgentInstallChecker.AuthState.NotAuthenticated
            && _checker.AgentPath is { Length: > 0 } agentPath
            ? ($"Open {_profile.DisplayName}, then type /login", () =>
            {
                _session.ExecuteCommand($"& '{agentPath.Replace("'", "''")}'");
                DismissRequested?.Invoke();
            })
            : null;
        RowsPanel.Children.Add(BuildRow("Authentication", authText, authColor, authDetail, authFix));

        // MCP
        var mcp = _checker.McpServerCount;
        var mcpHasProbe = _profile.McpProbe is not null;
        RowsPanel.Children.Add(BuildRow(
            "MCP Servers",
            (mcp, mcpHasProbe) switch
            {
                (null, false) => "Unknown",
                (null, true) => "Checking…",
                (0, _) => "None configured",
                _ => $"{mcp} server{(mcp == 1 ? "" : "s")}",
            },
            mcp is > 0 ? Microsoft.UI.Colors.SeaGreen : Microsoft.UI.Colors.Gray,
            mcp is > 0
                ? $"MCP servers extend {_profile.DisplayName} with extra tools."
                : mcpHasProbe
                    ? $"Optional — add MCP servers to give {_profile.DisplayName} access to databases, GitHub, and more."
                    : $"{_profile.DisplayName}'s MCP configuration can't be read from here.",
            null));
    }

    private static UIElement BuildRow(
        string title, string status, Windows.UI.Color statusColor,
        string detail, (string Label, Action Action)? fix)
    {
        var grid = new Grid { Padding = new Thickness(4, 8, 4, 8), ColumnSpacing = 12 };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var body = new StackPanel { Spacing = 2 };
        var headerLine = new TextBlock { FontSize = 13 };
        headerLine.Inlines.Add(new Microsoft.UI.Xaml.Documents.Run
        {
            Text = title + "  ",
            FontWeight = Microsoft.UI.Text.FontWeights.Medium,
        });
        headerLine.Inlines.Add(new Microsoft.UI.Xaml.Documents.Run
        {
            Text = status,
            Foreground = new SolidColorBrush(statusColor),
        });
        body.Children.Add(headerLine);
        if (detail.Length > 0)
        {
            body.Children.Add(new TextBlock
            {
                Text = detail,
                FontSize = 11,
                Opacity = 0.65,
                TextWrapping = TextWrapping.Wrap,
            });
        }
        if (fix is { } f)
        {
            var button = new HyperlinkButton
            {
                Content = f.Label,
                FontSize = 11,
                Padding = new Thickness(0),
            };
            button.Click += (_, _) => f.Action();
            body.Children.Add(button);
        }
        Grid.SetColumn(body, 0);
        grid.Children.Add(body);

        var dot = new Ellipse
        {
            Width = 8,
            Height = 8,
            Fill = new SolidColorBrush(statusColor),
            VerticalAlignment = VerticalAlignment.Top,
            Margin = new Thickness(0, 5, 0, 0),
        };
        Grid.SetColumn(dot, 1);
        grid.Children.Add(dot);

        return grid;
    }

    private void RunInstall()
    {
        if (_installCommand is null) return;
        _session.ExecuteCommand(_installCommand);
        DismissRequested?.Invoke();
    }

    private void OnRunInstall(object sender, RoutedEventArgs e) => RunInstall();

    private void OnCopyInstall(object sender, RoutedEventArgs e)
    {
        if (_installCommand is null) return;
        try
        {
            var package = new DataPackage { RequestedOperation = DataPackageOperation.Copy };
            package.SetText(_installCommand);
            Clipboard.SetContent(package);
        }
        catch { }
    }

    private void OnRecheck(object sender, RoutedEventArgs e) => _checker.ForceRecheck();
}
