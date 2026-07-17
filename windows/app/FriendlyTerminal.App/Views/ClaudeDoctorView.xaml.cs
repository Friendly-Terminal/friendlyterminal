using System.ComponentModel;
using FriendlyTerminal.App.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Shapes;
using Windows.ApplicationModel.DataTransfer;

namespace FriendlyTerminal.App.Views;

/// <summary>
/// Claude Code setup checks: Node.js, the CLI, credentials, and MCP servers,
/// each with a status dot and a fix action where one exists.
/// </summary>
public sealed partial class ClaudeDoctorView : UserControl
{
    private const string InstallCommand = "npm install -g @anthropic-ai/claude-code";

    private readonly SessionState _session;
    private readonly ClaudeInstallChecker _checker = ClaudeInstallChecker.Instance;

    public event Action? DismissRequested;

    public ClaudeDoctorView(SessionState session)
    {
        _session = session;
        InitializeComponent();
        _checker.PropertyChanged += OnCheckerChanged;
        Unloaded += (_, _) => _checker.PropertyChanged -= OnCheckerChanged;
        _checker.Check();
        Render();
    }

    private void OnCheckerChanged(object? sender, PropertyChangedEventArgs e) => Render();

    private void Render()
    {
        CheckingRing.IsActive = _checker.ClaudeState == ClaudeInstallChecker.State.Checking;
        InstallSection.Visibility = _checker.ClaudeState == ClaudeInstallChecker.State.NotInstalled
            ? Visibility.Visible
            : Visibility.Collapsed;

        RowsPanel.Children.Clear();

        // Node.js
        var nodeOk = _checker.NodeState == ClaudeInstallChecker.State.Installed;
        RowsPanel.Children.Add(BuildRow(
            "", "Node.js",
            _checker.NodeState switch
            {
                ClaudeInstallChecker.State.Installed => _checker.NodeVersion ?? "Installed",
                ClaudeInstallChecker.State.NotInstalled => "Not installed",
                _ => "Checking…",
            },
            nodeOk ? Microsoft.UI.Colors.SeaGreen : Microsoft.UI.Colors.IndianRed,
            nodeOk ? "Claude Code is built on Node.js. All good." : "Node.js is required by Claude Code.",
            nodeOk ? null : ("Open nodejs.org", () =>
            {
                _session.ExecuteCommand("Start-Process https://nodejs.org");
                DismissRequested?.Invoke();
            })));

        // Claude CLI
        var claudeOk = _checker.ClaudeState == ClaudeInstallChecker.State.Installed;
        RowsPanel.Children.Add(BuildRow(
            "", "Claude Code CLI",
            _checker.ClaudeState switch
            {
                ClaudeInstallChecker.State.Installed => _checker.ClaudeVersion ?? "Installed",
                ClaudeInstallChecker.State.NotInstalled => "Not installed",
                _ => "Checking…",
            },
            claudeOk ? Microsoft.UI.Colors.SeaGreen : Microsoft.UI.Colors.IndianRed,
            claudeOk
                ? (_checker.ClaudePath is { } p ? $"Found at {p}" : "")
                : "Run the install command below, then re-check.",
            claudeOk ? null : ("Install Claude Code", RunInstall)));

        // Auth
        var (authText, authColor, authDetail) = _checker.Auth switch
        {
            ClaudeInstallChecker.AuthState.Authenticated =>
                ("Configured", Microsoft.UI.Colors.SeaGreen, "Credentials found — you're ready to go."),
            ClaudeInstallChecker.AuthState.NotAuthenticated =>
                ("Not set up", Microsoft.UI.Colors.IndianRed, "Run 'claude login' to connect your Anthropic account."),
            _ => ("Probably configured", Microsoft.UI.Colors.Orange,
                "Could not verify. Try running claude in the terminal to check."),
        };
        RowsPanel.Children.Add(BuildRow(
            "", "Authentication", authText, authColor, authDetail,
            _checker.Auth == ClaudeInstallChecker.AuthState.NotAuthenticated
                ? ("Run claude login", () =>
                {
                    // Invoke the resolved path (a fallback install isn't on PATH); bare
                    // `claude` only when nothing was resolved.
                    var path = _checker.ClaudePath;
                    var login = string.IsNullOrEmpty(path) ? "claude login" : $"& \"{path}\" login";
                    _session.ExecuteCommand(login);
                    DismissRequested?.Invoke();
                })
                : null));

        // MCP
        var mcp = _checker.McpServerCount;
        RowsPanel.Children.Add(BuildRow(
            "", "MCP Servers",
            mcp switch
            {
                null => "Checking…",
                0 => "None configured",
                _ => $"{mcp} server{(mcp == 1 ? "" : "s")}",
            },
            mcp is > 0 ? Microsoft.UI.Colors.SeaGreen : Microsoft.UI.Colors.Gray,
            mcp is > 0
                ? "MCP servers extend Claude with extra tools."
                : "Optional — add MCP servers to give Claude access to databases, GitHub, and more.",
            null));
    }

    private static UIElement BuildRow(
        string glyph, string title, string status, Windows.UI.Color statusColor,
        string detail, (string Label, Action Action)? fix)
    {
        var grid = new Grid { Padding = new Thickness(4, 8, 4, 8), ColumnSpacing = 12 };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        grid.Children.Add(new FontIcon
        {
            FontFamily = (FontFamily)Application.Current.Resources["SymbolThemeFontFamily"],
            FontSize = 16,
            Glyph = glyph,
            Foreground = new SolidColorBrush(statusColor),
            VerticalAlignment = VerticalAlignment.Top,
        });

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
        Grid.SetColumn(body, 1);
        grid.Children.Add(body);

        var dot = new Ellipse
        {
            Width = 8,
            Height = 8,
            Fill = new SolidColorBrush(statusColor),
            VerticalAlignment = VerticalAlignment.Top,
            Margin = new Thickness(0, 5, 0, 0),
        };
        Grid.SetColumn(dot, 2);
        grid.Children.Add(dot);

        return grid;
    }

    private void RunInstall()
    {
        _session.ExecuteCommand(InstallCommand);
        DismissRequested?.Invoke();
    }

    private void OnRunInstall(object sender, RoutedEventArgs e) => RunInstall();

    private void OnCopyInstall(object sender, RoutedEventArgs e)
    {
        try
        {
            var package = new DataPackage { RequestedOperation = DataPackageOperation.Copy };
            package.SetText(InstallCommand);
            Clipboard.SetContent(package);
        }
        catch { }
    }

    private void OnRecheck(object sender, RoutedEventArgs e) => _checker.ForceRecheck();
}
