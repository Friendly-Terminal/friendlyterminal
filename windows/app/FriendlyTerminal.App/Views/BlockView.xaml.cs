using System.ComponentModel;
using System.Text.Json;
using FriendlyTerminal.App.Models;
using FriendlyTerminal.Core.Output;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Windows.ApplicationModel.DataTransfer;

namespace FriendlyTerminal.App.Views;

/// <summary>
/// One command block: collapsible header with exit badge and re-run, plus the
/// output rendered per <see cref="RenderKind"/> (plain text, tables, JSON tree,
/// clickable chips, or an image) and an undo bar when the command is reversible.
/// </summary>
public sealed partial class BlockView : UserControl
{
    private readonly SessionState _session;
    private readonly CommandBlock _block;
    private bool _expanded = true;
    private TextBlock? _streamingText;

    public BlockView(SessionState session, CommandBlock block)
    {
        _session = session;
        _block = block;
        InitializeComponent();

        CommandText.Text = block.Command.Length == 0 ? "(no command)" : block.Command;
        block.PropertyChanged += OnBlockChanged;
        Unloaded += (_, _) => block.PropertyChanged -= OnBlockChanged;

        BuildContextMenu();
        RenderStatus();
        RenderOutput();
        RenderUndoBar();
    }

    private void OnBlockChanged(object? sender, PropertyChangedEventArgs e)
    {
        switch (e.PropertyName)
        {
            case nameof(CommandBlock.PlainText):
                if (_streamingText is not null)
                    _streamingText.Text = _block.PlainText;
                else
                    RenderOutput();
                break;
            case nameof(CommandBlock.ExitCode):
                RenderStatus();
                break;
            case nameof(CommandBlock.RenderKind):
                RenderOutput();
                break;
            case nameof(CommandBlock.UndoPlan):
            case nameof(CommandBlock.IsUndone):
                RenderUndoBar();
                break;
        }
    }

    private void OnToggleExpand(object sender, RoutedEventArgs e)
    {
        _expanded = !_expanded;
        Chevron.Glyph = _expanded ? "" : "";
        OutputHost.Visibility = _expanded ? Visibility.Visible : Visibility.Collapsed;
        RenderUndoBar();
    }

    private void OnRerun(object sender, RoutedEventArgs e)
    {
        if (_block.Command.Length > 0)
            _session.ExecuteCommand(_block.Command);
    }

    private void BuildContextMenu()
    {
        var flyout = new MenuFlyout();

        var copyCmd = new MenuFlyoutItem { Text = "Copy command" };
        copyCmd.Click += (_, _) => CopyText(_block.Command);
        flyout.Items.Add(copyCmd);

        var copyOut = new MenuFlyoutItem { Text = "Copy output" };
        copyOut.Click += (_, _) => CopyText(_block.PlainText);
        flyout.Items.Add(copyOut);

        if (_block.Command.Length > 0)
        {
            var rerun = new MenuFlyoutItem { Text = "Re-run" };
            rerun.Click += (_, _) => _session.ExecuteCommand(_block.Command);
            flyout.Items.Add(rerun);
        }

        ContextFlyout = flyout;
    }

    private static void CopyText(string text)
    {
        try
        {
            var package = new DataPackage { RequestedOperation = DataPackageOperation.Copy };
            package.SetText(text);
            Clipboard.SetContent(package);
        }
        catch { }
    }

    private void RenderStatus()
    {
        RunningRing.IsActive = _block.IsRunning;
        RunningRing.Visibility = _block.IsRunning ? Visibility.Visible : Visibility.Collapsed;
        CheckIcon.Visibility = _block.Succeeded ? Visibility.Visible : Visibility.Collapsed;
        ExitBadge.Visibility = _block.Failed ? Visibility.Visible : Visibility.Collapsed;
        if (_block.Failed)
            ExitBadgeText.Text = $"Exit {_block.ExitCode}";
        HeaderRow.Background = _block.Failed
            ? new SolidColorBrush(Windows.UI.Color.FromArgb(18, 255, 60, 60))
            : null;
    }

    private void RenderUndoBar()
    {
        UndoBar.Children.Clear();
        if (_block.UndoPlan is not { } plan || !_expanded)
        {
            UndoBar.Visibility = Visibility.Collapsed;
            return;
        }
        UndoBar.Visibility = Visibility.Visible;

        if (_block.IsUndone)
        {
            UndoBar.Children.Add(new FontIcon
            {
                FontFamily = (FontFamily)Application.Current.Resources["SymbolThemeFontFamily"],
                FontSize = 11,
                Glyph = "",
                Opacity = 0.6,
            });
            UndoBar.Children.Add(new TextBlock { Text = "Undone", FontSize = 11, Opacity = 0.6, VerticalAlignment = VerticalAlignment.Center });
            return;
        }

        var undo = new HyperlinkButton
        {
            Content = plan.Label,
            FontSize = 11,
            Padding = new Thickness(0),
        };
        ToolTipService.SetToolTip(undo, "Reverse this command");
        undo.Click += (_, _) => _session.PerformUndo(_block);
        UndoBar.Children.Add(undo);
    }

    // MARK: - Output rendering

    private void RenderOutput()
    {
        _streamingText = null;

        if (_block.PlainText.Length == 0 && _block.IsRunning)
        {
            OutputHost.Content = null;
            return;
        }

        OutputHost.Content = _block.RenderKind switch
        {
            RenderKind.Table t => BuildGridTable(t.Rows, 80),
            RenderKind.CsvTable c => BuildGridTable(c.Rows, 100),
            RenderKind.JsonTree => BuildJsonTree(_block.PlainText),
            RenderKind.CommandList list => BuildCommandList(list),
            RenderKind.ImageFile img => BuildImage(img.Path),
            _ => BuildPlainText(),
        };
    }

    private TextBlock BuildPlainText()
    {
        var tb = new TextBlock
        {
            Text = _block.PlainText,
            FontFamily = new FontFamily("Consolas"),
            FontSize = 12,
            TextWrapping = TextWrapping.Wrap,
            IsTextSelectionEnabled = true,
        };
        if (_block.IsRunning)
            _streamingText = tb;
        return tb;
    }

    private static UIElement BuildGridTable(IReadOnlyList<string[]> rows, double minColWidth)
    {
        var panel = new StackPanel();
        for (var r = 0; r < rows.Count; r++)
        {
            var rowPanel = new StackPanel { Orientation = Orientation.Horizontal, Padding = new Thickness(8, 3, 8, 3) };
            if (r % 2 == 1)
                rowPanel.Background = new SolidColorBrush(Windows.UI.Color.FromArgb(14, 128, 128, 128));
            foreach (var cell in rows[r])
            {
                rowPanel.Children.Add(new TextBlock
                {
                    Text = cell,
                    FontFamily = new FontFamily("Consolas"),
                    FontSize = 12,
                    FontWeight = r == 0 ? Microsoft.UI.Text.FontWeights.SemiBold : Microsoft.UI.Text.FontWeights.Normal,
                    MinWidth = minColWidth,
                    Margin = new Thickness(0, 0, 12, 0),
                    IsTextSelectionEnabled = true,
                });
            }
            panel.Children.Add(rowPanel);
        }
        return new ScrollViewer
        {
            Content = panel,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
            VerticalScrollBarVisibility = ScrollBarVisibility.Disabled,
            HorizontalScrollMode = ScrollMode.Auto,
        };
    }

    private UIElement BuildCommandList(RenderKind.CommandList list)
    {
        var panel = new StackPanel { Spacing = 6 };
        panel.Children.Add(new TextBlock
        {
            Text = list.Hint,
            FontSize = 10,
            Opacity = 0.65,
            TextWrapping = TextWrapping.Wrap,
        });

        var grid = new VariableSizedWrapGrid
        {
            Orientation = Orientation.Horizontal,
            ItemWidth = 170,
            ItemHeight = 30,
        };
        foreach (var item in list.Items.Take(300))
        {
            var content = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
            content.Children.Add(new FontIcon
            {
                FontFamily = (FontFamily)Application.Current.Resources["SymbolThemeFontFamily"],
                FontSize = 11,
                Glyph = GlyphForIcon(item.Icon),
            });
            content.Children.Add(new TextBlock
            {
                Text = item.Label,
                FontFamily = new FontFamily("Consolas"),
                FontSize = 11,
                TextTrimming = TextTrimming.CharacterEllipsis,
            });
            var button = new Button
            {
                Content = content,
                Padding = new Thickness(8, 3, 8, 3),
                HorizontalAlignment = HorizontalAlignment.Stretch,
                HorizontalContentAlignment = HorizontalAlignment.Left,
                Margin = new Thickness(0, 0, 6, 4),
            };
            ToolTipService.SetToolTip(button, item.Detail is { } d ? $"{d}\n{item.FollowUp}" : $"Fill in: {item.FollowUp}");
            var followUp = item.FollowUp;
            button.Click += (_, _) => _session.PrefillCommand(followUp);
            grid.Children.Add(button);
        }
        panel.Children.Add(grid);
        return panel;
    }

    private static string GlyphForIcon(string icon) => icon switch
    {
        "folder" => "",
        "git-branch" => "",
        "git-add" => "",
        "clock" => "",
        "history" => "",
        "tag" => "",
        "picture" => "",
        "code" => "",
        "doc" => "",
        "pdf" => "",
        "archive" => "",
        _ => "",
    };

    private static UIElement BuildImage(string path)
    {
        try
        {
            return new Image
            {
                Source = new BitmapImage(new Uri(path)),
                MaxHeight = 400,
                Stretch = Stretch.Uniform,
                HorizontalAlignment = HorizontalAlignment.Left,
            };
        }
        catch
        {
            return new TextBlock { Text = path, FontSize = 12 };
        }
    }

    // MARK: - JSON tree

    private UIElement BuildJsonTree(string text)
    {
        try
        {
            using var doc = JsonDocument.Parse(text.Trim());
            var root = BuildJsonNode(doc.RootElement.Clone(), key: null, depth: 0);
            return new ScrollViewer
            {
                Content = root,
                MaxHeight = 420,
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
            };
        }
        catch (JsonException)
        {
            return BuildPlainText();
        }
    }

    private UIElement BuildJsonNode(JsonElement element, string? key, int depth)
    {
        switch (element.ValueKind)
        {
            case JsonValueKind.Object:
            case JsonValueKind.Array:
            {
                var isArray = element.ValueKind == JsonValueKind.Array;
                var count = isArray ? element.GetArrayLength() : element.EnumerateObject().Count();
                var container = new StackPanel();

                var header = new HyperlinkButton
                {
                    Padding = new Thickness(0),
                    FontSize = 12,
                    Content = JsonLabel(key, isArray ? $"[ {count} ]" : $"{{ {count} }}"),
                };

                var children = new StackPanel { Margin = new Thickness(14, 0, 0, 0) };
                var expanded = depth < 3;
                children.Visibility = expanded ? Visibility.Visible : Visibility.Collapsed;
                var built = false;

                void BuildChildren()
                {
                    if (built) return;
                    built = true;
                    var i = 0;
                    if (isArray)
                    {
                        foreach (var item in element.EnumerateArray())
                        {
                            if (i >= 200) break;
                            children.Children.Add(BuildJsonNode(item, $"[{i}]", depth + 1));
                            i++;
                        }
                    }
                    else
                    {
                        foreach (var prop in element.EnumerateObject())
                        {
                            if (i >= 200) break;
                            children.Children.Add(BuildJsonNode(prop.Value, prop.Name, depth + 1));
                            i++;
                        }
                    }
                    if (count > 200)
                        children.Children.Add(new TextBlock
                        {
                            Text = $"… {count - 200} more",
                            FontFamily = new FontFamily("Consolas"),
                            FontSize = 11,
                            Opacity = 0.6,
                        });
                }

                if (expanded) BuildChildren();
                header.Click += (_, _) =>
                {
                    BuildChildren();
                    children.Visibility = children.Visibility == Visibility.Visible
                        ? Visibility.Collapsed
                        : Visibility.Visible;
                };

                container.Children.Add(header);
                container.Children.Add(children);
                return container;
            }

            case JsonValueKind.String:
                return JsonLeaf(key, $"\"{element.GetString()}\"", Colors.SeaGreen);
            case JsonValueKind.Number:
                return JsonLeaf(key, element.GetRawText(), Colors.CornflowerBlue);
            case JsonValueKind.True:
            case JsonValueKind.False:
                return JsonLeaf(key, element.GetRawText(), Colors.Orange);
            default:
                return JsonLeaf(key, "null", Colors.Gray);
        }
    }

    private static TextBlock JsonLabel(string? key, string suffix)
    {
        var tb = new TextBlock { FontFamily = new FontFamily("Consolas"), FontSize = 12 };
        if (key is not null)
        {
            tb.Inlines.Add(new Microsoft.UI.Xaml.Documents.Run
            {
                Text = key.StartsWith('[') ? $"{key}: " : $"\"{key}\": ",
            });
        }
        tb.Inlines.Add(new Microsoft.UI.Xaml.Documents.Run { Text = suffix });
        tb.Opacity = 0.85;
        return tb;
    }

    private static TextBlock JsonLeaf(string? key, string value, Windows.UI.Color color)
    {
        var tb = new TextBlock
        {
            FontFamily = new FontFamily("Consolas"),
            FontSize = 12,
            IsTextSelectionEnabled = true,
            Margin = new Thickness(0, 1, 0, 1),
        };
        if (key is not null)
        {
            tb.Inlines.Add(new Microsoft.UI.Xaml.Documents.Run
            {
                Text = key.StartsWith('[') ? $"{key}: " : $"\"{key}\": ",
            });
        }
        tb.Inlines.Add(new Microsoft.UI.Xaml.Documents.Run
        {
            Text = value,
            Foreground = new SolidColorBrush(color),
        });
        return tb;
    }
}
