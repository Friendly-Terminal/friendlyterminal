using FriendlyTerminal.App.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

namespace FriendlyTerminal.App.Views;

/// <summary>
/// Sidebar control panel while Claude Code runs: arrows and 1-4 to answer its
/// menus, Enter/Stop/Esc, a slash-command grid, and Exit.
/// </summary>
public sealed partial class ClaudeControlBarView : UserControl
{
    private static readonly string Esc = ((char)0x1B).ToString();
    private static readonly string CtrlC = ((char)0x03).ToString();

    private static readonly (string Label, string Command, string Help)[] SlashCommands =
    {
        ("/clear", "/clear\r", "Clear the conversation history"),
        ("/compact", "/compact\r", "Compact context to save tokens"),
        ("/help", "/help\r", "Show Claude's built-in help"),
        ("/init", "/init\r", "Create a CLAUDE.md for this project"),
        ("/model", "/model\r", "Switch the model"),
        ("/resume", "/resume\r", "Resume a previous conversation"),
    };

    private SessionState? _session;
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

    public ClaudeControlBarView()
    {
        InitializeComponent();
        BuildNumberRow();
        BuildSlashGrid();
        Render();
    }

    public void Render()
    {
        DangerBanner.Visibility = _session?.ClaudeRunsWithDangerousFlag == true
            ? Visibility.Visible
            : Visibility.Collapsed;

        var version = ClaudeInstallChecker.Instance.ClaudeVersion;
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

    private void BuildSlashGrid()
    {
        var row = 0;
        var col = 0;
        foreach (var (label, command, help) in SlashCommands)
        {
            if (SlashGrid.RowDefinitions.Count <= row)
                SlashGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

            var button = new Button
            {
                Content = new TextBlock
                {
                    Text = label,
                    FontFamily = new FontFamily("Consolas"),
                    FontSize = 10,
                    FontWeight = Microsoft.UI.Text.FontWeights.Medium,
                },
                HorizontalAlignment = HorizontalAlignment.Stretch,
                Padding = new Thickness(0, 5, 0, 5),
            };
            ToolTipService.SetToolTip(button, help);
            var cmd = command;
            button.Click += (_, _) => _session?.SendRaw(cmd);
            Grid.SetRow(button, row);
            Grid.SetColumn(button, col);
            SlashGrid.Children.Add(button);

            col++;
            if (col == 2) { col = 0; row++; }
        }
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
    private void OnExit(object sender, RoutedEventArgs e) => _session?.SendRaw("/exit\r");
}
