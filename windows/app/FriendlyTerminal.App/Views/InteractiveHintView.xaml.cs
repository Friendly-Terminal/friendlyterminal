using FriendlyTerminal.App.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

namespace FriendlyTerminal.App.Views;

/// <summary>
/// Shown in the sidebar while a full-screen program (vim, less, top, ...) owns
/// the keyboard: what it is, one-tap escape actions, and its key cheat sheet.
/// </summary>
public sealed partial class InteractiveHintView : UserControl
{
    private SessionState? _session;

    public SessionState? Session
    {
        get => _session;
        set
        {
            _session = value;
            Render();
        }
    }

    public InteractiveHintView()
    {
        InitializeComponent();
    }

    /// <summary>Re-resolve the hint for the currently running command.</summary>
    public void Render()
    {
        var hint = ProgramHint.Detect(_session?.Blocks.CurrentBlock?.Command ?? "");

        TitleIcon.Glyph = char.ConvertFromUtf32(hint.Glyph);
        TitleText.Text = hint.Title;
        SubtitleText.Text = hint.Subtitle;

        ActionsPanel.Children.Clear();
        foreach (var action in hint.Actions)
        {
            var content = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
            content.Children.Add(new FontIcon
            {
                FontFamily = (FontFamily)Application.Current.Resources["SymbolThemeFontFamily"],
                FontSize = 11,
                Glyph = char.ConvertFromUtf32(action.Glyph),
            });
            content.Children.Add(new TextBlock
            {
                Text = action.Label,
                FontSize = 11,
                FontWeight = Microsoft.UI.Text.FontWeights.Medium,
            });

            var button = new Button
            {
                Content = content,
                HorizontalAlignment = HorizontalAlignment.Stretch,
                HorizontalContentAlignment = HorizontalAlignment.Left,
                Padding = new Thickness(10, 6, 10, 6),
            };
            if (action.Destructive)
                button.Foreground = new SolidColorBrush(Microsoft.UI.Colors.Orange);
            var sequence = action.Sequence;
            button.Click += (_, _) => _session?.SendRaw(sequence);
            ActionsPanel.Children.Add(button);
        }

        KeysPanel.Children.Clear();
        foreach (var key in hint.Keys)
        {
            var row = new Grid { ColumnSpacing = 8 };
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(72) });
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

            var keyBadge = new Border
            {
                Padding = new Thickness(6, 2, 6, 2),
                CornerRadius = new CornerRadius(4),
                Background = (Brush)Application.Current.Resources["ControlFillColorSecondaryBrush"],
                HorizontalAlignment = HorizontalAlignment.Left,
                Child = new TextBlock
                {
                    Text = key.Key,
                    FontFamily = new FontFamily("Consolas"),
                    FontSize = 11,
                    FontWeight = Microsoft.UI.Text.FontWeights.Medium,
                },
            };
            row.Children.Add(keyBadge);

            var desc = new TextBlock
            {
                Text = key.Description,
                FontSize = 11,
                Opacity = 0.7,
                TextWrapping = TextWrapping.Wrap,
                VerticalAlignment = VerticalAlignment.Center,
            };
            Grid.SetColumn(desc, 1);
            row.Children.Add(desc);

            KeysPanel.Children.Add(row);
        }
    }
}
