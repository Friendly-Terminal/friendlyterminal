using FriendlyTerminal.App.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace FriendlyTerminal.App.Views;

/// <summary>
/// Lists items in the app-managed trash (deletions intercepted for undo), with
/// per-item restore and an empty-trash action. Hosted in a ContentDialog opened
/// from the sidebar footer.
/// </summary>
public sealed partial class TrashPanelView : UserControl
{
    public TrashPanelView()
    {
        InitializeComponent();
        Refresh();
    }

    private void Refresh()
    {
        var entries = WindowsFileSystem.ListAppTrash();

        ItemsPanel.Children.Clear();
        foreach (var entry in entries)
            ItemsPanel.Children.Add(BuildRow(entry));

        EmptyStatePanel.Visibility = entries.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
        EmptyButton.IsEnabled = entries.Count > 0;
        SummaryText.Text = entries.Count == 0
            ? ""
            : $"{entries.Count} item{(entries.Count == 1 ? "" : "s")} · {FormatSize(entries.Sum(e => e.SizeBytes))}";
    }

    private UIElement BuildRow(TrashEntry entry)
    {
        var name = new TextBlock
        {
            Text = entry.Name,
            FontSize = 12,
            FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
            TextTrimming = TextTrimming.CharacterEllipsis,
        };
        var origin = new TextBlock
        {
            Text = entry.OriginalPath ?? "Original location unknown",
            FontSize = 11,
            Opacity = 0.6,
            TextTrimming = TextTrimming.CharacterEllipsis,
        };
        var details = new TextBlock
        {
            Text = $"{entry.Volume} · {FormatSize(entry.SizeBytes)} · {entry.TrashedAt:g}",
            FontSize = 11,
            Opacity = 0.6,
        };
        var info = new StackPanel { Spacing = 1 };
        info.Children.Add(name);
        info.Children.Add(origin);
        info.Children.Add(details);

        var restore = new Button
        {
            Content = "Restore",
            FontSize = 12,
            VerticalAlignment = VerticalAlignment.Center,
            IsEnabled = entry.OriginalPath is not null,
        };
        if (entry.OriginalPath is null)
            ToolTipService.SetToolTip(restore, "This item's original location wasn't recorded.");
        restore.Click += (_, _) =>
        {
            if (WindowsFileSystem.RestoreTrashEntry(entry))
            {
                Refresh();
            }
            else
            {
                restore.Content = "Couldn't restore";
                restore.IsEnabled = false;
            }
        };

        var grid = new Grid { Padding = new Thickness(8, 4, 8, 4), ColumnSpacing = 8 };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        Grid.SetColumn(restore, 1);
        grid.Children.Add(info);
        grid.Children.Add(restore);
        ToolTipService.SetToolTip(grid, entry.TrashedPath);
        return grid;
    }

    private void OnEmptyConfirmed(object sender, RoutedEventArgs e)
    {
        EmptyFlyout.Hide();
        WindowsFileSystem.EmptyAppTrash();
        Refresh();
    }

    private static string FormatSize(long bytes) => bytes switch
    {
        < 1024 => $"{bytes} B",
        < 1024 * 1024 => $"{bytes / 1024.0:0.#} KB",
        < 1024 * 1024 * 1024 => $"{bytes / (1024.0 * 1024):0.#} MB",
        _ => $"{bytes / (1024.0 * 1024 * 1024):0.#} GB",
    };
}
