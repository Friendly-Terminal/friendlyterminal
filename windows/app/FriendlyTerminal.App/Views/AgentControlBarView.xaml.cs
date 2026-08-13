using System.ComponentModel;
using System.Globalization;
using FriendlyTerminal.App.Models;
using FriendlyTerminal.Core.Agents;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

namespace FriendlyTerminal.App.Views;

/// <summary>
/// Sidebar control panel while a recognized AI agent runs: arrows (and 1-4 when the
/// agent uses numbered menus), Enter/Stop/Esc, a slash-command grid, and Exit — all
/// rendered from the active <see cref="AgentProfile"/>.
/// </summary>
public sealed partial class AgentControlBarView : UserControl
{
    private static readonly string Esc = ((char)0x1B).ToString();
    private static readonly string CtrlC = ((char)0x03).ToString();

    private SessionState? _session;
    private AgentInstallChecker? _checker;
    private string? _renderedAgentId;
    private bool _slashExpanded;

    public SessionState? Session
    {
        get => _session;
        set
        {
            _session = value;
            Render();
        }
    }

    public AgentControlBarView()
    {
        InitializeComponent();
        BuildNumberRow();
        Unloaded += (_, _) =>
        {
            if (_checker is not null)
                _checker.PropertyChanged -= OnCheckerChanged;
        };
        Render();
    }

    public void Render()
    {
        if (_session?.ActiveAgent is not { } agent)
            return;

        if (_renderedAgentId != agent.Id)
        {
            _renderedAgentId = agent.Id;
            RenderProfile(agent);
        }

        DangerBanner.Visibility = _session.AgentRunsWithDangerousFlag
            ? Visibility.Visible
            : Visibility.Collapsed;

        UpdateVersion();
    }

    private void RenderProfile(AgentProfile agent)
    {
        HeaderText.Text = agent.DisplayName;
        HeaderIcon.Glyph = agent.Glyph;
        HeaderIcon.Foreground = AccentBrush(agent.AccentHex);

        DangerText.Text = $"Auto-approve mode — {agent.DisplayName} can act without asking";

        NumberRow.Visibility = agent.SupportsNumberedOptions ? Visibility.Visible : Visibility.Collapsed;

        ExitLabel.Text = $"Exit {agent.DisplayName}";
        ExitButton.SetValue(AutomationProperties.NameProperty, $"Exit {agent.DisplayName}");
        ToolTipService.SetToolTip(ExitButton, $"End the {agent.DisplayName} session");
        ExitHint.Text = agent.ExitHint;

        BuildSlashGrid(agent);
        BindChecker(agent);
    }

    private void BindChecker(AgentProfile agent)
    {
        if (_checker is not null)
            _checker.PropertyChanged -= OnCheckerChanged;
        _checker = AgentInstallChecker.For(agent);
        _checker.PropertyChanged += OnCheckerChanged;
        _checker.Check();
    }

    private void OnCheckerChanged(object? sender, PropertyChangedEventArgs e) => UpdateVersion();

    private void UpdateVersion()
    {
        var version = _checker?.AgentVersion;
        VersionText.Text = version ?? "";
        VersionText.Visibility = version is null ? Visibility.Collapsed : Visibility.Visible;
    }

    private void BuildNumberRow()
    {
        for (var n = 1; n <= 4; n++)
        {
            var button = new Button
            {
                Content = new TextBlock
                {
                    Text = n.ToString(),
                    FontFamily = new FontFamily("Consolas"),
                    FontSize = 13,
                    FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
                    HorizontalAlignment = HorizontalAlignment.Center,
                },
                HorizontalAlignment = HorizontalAlignment.Stretch,
                Padding = new Thickness(0, 6, 0, 6),
            };
            ToolTipService.SetToolTip(button, $"Select option {n}");
            var digit = n.ToString();
            button.Click += (_, _) => _session?.SendRaw(digit + "\r");
            Grid.SetColumn(button, n - 1);
            NumberRow.Children.Add(button);
        }
    }

    private void BuildSlashGrid(AgentProfile agent)
    {
        SlashGrid.Children.Clear();
        SlashGrid.RowDefinitions.Clear();

        var row = 0;
        var col = 0;
        foreach (var command in agent.SlashCommands)
        {
            if (SlashGrid.RowDefinitions.Count <= row)
                SlashGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

            var button = new Button
            {
                Content = new TextBlock
                {
                    Text = command.Label,
                    FontFamily = new FontFamily("Consolas"),
                    FontSize = 10,
                    FontWeight = Microsoft.UI.Text.FontWeights.Medium,
                },
                HorizontalAlignment = HorizontalAlignment.Stretch,
                Padding = new Thickness(0, 5, 0, 5),
            };
            ToolTipService.SetToolTip(button, command.Help);
            var send = command.SendText;
            button.Click += (_, _) => _session?.SendRaw(send);
            Grid.SetRow(button, row);
            Grid.SetColumn(button, col);
            SlashGrid.Children.Add(button);

            col++;
            if (col == 2) { col = 0; row++; }
        }
    }

    private Brush AccentBrush(string? hex)
    {
        if (hex is not null && ParseHex(hex) is { } color)
            return new SolidColorBrush(color);
        return (Brush)Application.Current.Resources["AccentTextFillColorPrimaryBrush"];
    }

    private static Windows.UI.Color? ParseHex(string hex)
    {
        var value = hex.TrimStart('#');
        if (value.Length != 6
            || !byte.TryParse(value.AsSpan(0, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var r)
            || !byte.TryParse(value.AsSpan(2, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var g)
            || !byte.TryParse(value.AsSpan(4, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var b))
            return null;
        return Windows.UI.Color.FromArgb(0xFF, r, g, b);
    }

    private void OnToggleSlash(object sender, RoutedEventArgs e)
    {
        _slashExpanded = !_slashExpanded;
        SlashGrid.Visibility = _slashExpanded ? Visibility.Visible : Visibility.Collapsed;
        SlashChevron.Glyph = char.ConvertFromUtf32(_slashExpanded ? 0xE70E : 0xE70D);
    }

    private void OnArrowUp(object sender, RoutedEventArgs e) => _session?.SendRaw(Esc + "[A");
    private void OnArrowDown(object sender, RoutedEventArgs e) => _session?.SendRaw(Esc + "[B");
    private void OnEnter(object sender, RoutedEventArgs e) => _session?.SendRaw("\r");
    private void OnStop(object sender, RoutedEventArgs e) => _session?.SendRaw(CtrlC);
    private void OnEscape(object sender, RoutedEventArgs e) => _session?.SendRaw(Esc);
    private void OnExit(object sender, RoutedEventArgs e) => _session?.SendRaw(_session.ActiveAgent?.ExitSendText ?? "");
}
