using System.Collections.Specialized;
using FriendlyTerminal.App.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

namespace FriendlyTerminal.App.Views;

/// <summary>
/// "This Project" section: one-tap chips for the project type detected in the
/// current folder (npm scripts, Python, Rust, Make, ...). Hidden when nothing
/// is detected.
/// </summary>
public sealed partial class ProjectCommandsView : UserControl
{
    private SessionState? _session;

    public SessionState? Session
    {
        get => _session;
        set
        {
            if (_session is not null)
                _session.Files.CollectionChanged -= OnFilesChanged;
            _session = value;
            if (_session is null) return;
            _session.Files.CollectionChanged += OnFilesChanged;
            Render();
        }
    }

    public ProjectCommandsView()
    {
        InitializeComponent();
    }

    private void OnFilesChanged(object? sender, NotifyCollectionChangedEventArgs e) => Render();

    private void Render()
    {
        GroupsPanel.Children.Clear();
        if (_session is null) return;

        var groups = ProjectCommandDetector.Suggestions(_session.CurrentDirectory, _session.Files);
        Root.Visibility = groups.Count > 0 ? Visibility.Visible : Visibility.Collapsed;

        foreach (var group in groups)
        {
            var section = new StackPanel { Spacing = 4 };

            var header = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 4 };
            header.Children.Add(new FontIcon
            {
                FontFamily = (FontFamily)Application.Current.Resources["SymbolThemeFontFamily"],
                FontSize = 9,
                Opacity = 0.6,
                Glyph = char.ConvertFromUtf32(group.Glyph),
            });
            header.Children.Add(new TextBlock
            {
                Text = group.Name,
                FontSize = 10,
                FontWeight = Microsoft.UI.Text.FontWeights.Medium,
                Opacity = 0.6,
            });
            section.Children.Add(header);

            var grid = new VariableSizedWrapGrid
            {
                Orientation = Orientation.Horizontal,
                ItemWidth = 118,
                ItemHeight = 30,
            };
            foreach (var cmd in group.Commands)
            {
                var content = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 5 };
                content.Children.Add(new FontIcon
                {
                    FontFamily = (FontFamily)Application.Current.Resources["SymbolThemeFontFamily"],
                    FontSize = 10,
                    Foreground = (Brush)Application.Current.Resources["AccentTextFillColorPrimaryBrush"],
                    Glyph = char.ConvertFromUtf32(cmd.Glyph),
                });
                content.Children.Add(new TextBlock
                {
                    Text = cmd.Label,
                    FontSize = 11,
                    FontWeight = Microsoft.UI.Text.FontWeights.Medium,
                    TextTrimming = TextTrimming.CharacterEllipsis,
                });

                var button = new Button
                {
                    Content = content,
                    Padding = new Thickness(8, 4, 8, 4),
                    HorizontalAlignment = HorizontalAlignment.Stretch,
                    HorizontalContentAlignment = HorizontalAlignment.Left,
                    Margin = new Thickness(0, 0, 4, 4),
                };
                ToolTipService.SetToolTip(button, cmd.Command);
                var command = cmd.Command;
                button.Click += (_, _) => _session?.ExecuteCommand(command);
                grid.Children.Add(button);
            }
            section.Children.Add(grid);
            GroupsPanel.Children.Add(section);
        }
    }
}
