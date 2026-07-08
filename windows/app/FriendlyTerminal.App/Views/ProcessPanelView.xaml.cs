using System.Diagnostics;
using FriendlyTerminal.App.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

namespace FriendlyTerminal.App.Views;

/// <summary>
/// "What's Running": processes listening on TCP ports, with Open (for web
/// servers) and a confirm-then-Kill action. Auto-refreshes every 3 seconds
/// while visible, like the macOS panel.
/// </summary>
public sealed partial class ProcessPanelView : UserControl
{
    private DispatcherTimer? _timer;
    private string? _confirmKillId;
    private bool _loading;

    public ProcessPanelView()
    {
        InitializeComponent();
        Loaded += (_, _) => StartAutoRefresh();
        Unloaded += (_, _) => StopAutoRefresh();
    }

    private void StartAutoRefresh()
    {
        Refresh();
        _timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(3) };
        _timer.Tick += (_, _) => Refresh();
        _timer.Start();
    }

    private void StopAutoRefresh()
    {
        _timer?.Stop();
        _timer = null;
    }

    private void Refresh()
    {
        if (_loading) return;
        _loading = true;
        BusyRing.IsActive = true;
        var queue = DispatcherQueue;
        Task.Run(() =>
        {
            var entries = ProcessMonitor.Load();
            queue.TryEnqueue(() =>
            {
                _loading = false;
                BusyRing.IsActive = false;
                Render(entries);
            });
        });
    }

    private void Render(List<RunningProcess> entries)
    {
        ListPanel.Children.Clear();
        EmptyPanel.Visibility = entries.Count == 0 ? Visibility.Visible : Visibility.Collapsed;

        foreach (var entry in entries)
            ListPanel.Children.Add(BuildRow(entry));
    }

    private UIElement BuildRow(RunningProcess entry)
    {
        var grid = new Grid { Padding = new Thickness(8, 8, 8, 8), ColumnSpacing = 10 };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var portBadge = new Border
        {
            Padding = new Thickness(6, 3, 6, 3),
            CornerRadius = new CornerRadius(5),
            MinWidth = 54,
            Background = entry.IsWebServer
                ? (Brush)Application.Current.Resources["AccentFillColorDefaultBrush"]
                : new SolidColorBrush(Microsoft.UI.Colors.Gray),
            Child = new TextBlock
            {
                Text = $":{entry.Port}",
                FontFamily = new FontFamily("Consolas"),
                FontSize = 11,
                FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
                Foreground = new SolidColorBrush(Microsoft.UI.Colors.White),
                HorizontalAlignment = HorizontalAlignment.Center,
            },
        };

        var info = new StackPanel { Spacing = 2, VerticalAlignment = VerticalAlignment.Center };
        info.Children.Add(new TextBlock
        {
            Text = entry.FriendlyName,
            FontSize = 13,
            FontWeight = Microsoft.UI.Text.FontWeights.Medium,
            TextTrimming = TextTrimming.CharacterEllipsis,
        });
        info.Children.Add(new TextBlock
        {
            Text = $"{entry.Command}  ·  PID {entry.Pid}",
            FontFamily = new FontFamily("Consolas"),
            FontSize = 11,
            Opacity = 0.6,
            TextTrimming = TextTrimming.CharacterEllipsis,
        });
        Grid.SetColumn(info, 1);

        var actions = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6, VerticalAlignment = VerticalAlignment.Center };

        if (entry.IsWebServer)
        {
            var open = new Button { Content = "Open", FontSize = 11, Padding = new Thickness(8, 3, 8, 3) };
            ToolTipService.SetToolTip(open, "Open in browser");
            var port = entry.Port;
            open.Click += (_, _) =>
            {
                try
                {
                    Process.Start(new ProcessStartInfo($"http://localhost:{port}") { UseShellExecute = true });
                }
                catch { }
            };
            actions.Children.Add(open);
        }

        if (_confirmKillId == entry.Id)
        {
            var confirm = new Button
            {
                Content = "Kill?",
                FontSize = 11,
                Padding = new Thickness(8, 3, 8, 3),
                Background = new SolidColorBrush(Microsoft.UI.Colors.IndianRed),
                Foreground = new SolidColorBrush(Microsoft.UI.Colors.White),
            };
            confirm.Click += (_, _) =>
            {
                _confirmKillId = null;
                var pid = entry.Pid;
                Task.Run(() => ProcessMonitor.Kill(pid));
                // Give the process a moment to die before the next refresh repaints.
                DispatcherQueue.TryEnqueue(Refresh);
            };
            actions.Children.Add(confirm);

            var cancel = new Button { Content = "Cancel", FontSize = 11, Padding = new Thickness(8, 3, 8, 3) };
            cancel.Click += (_, _) => { _confirmKillId = null; Refresh(); };
            actions.Children.Add(cancel);
        }
        else
        {
            var kill = new Button { Content = "Kill", FontSize = 11, Padding = new Thickness(8, 3, 8, 3) };
            ToolTipService.SetToolTip(kill, "Stop this process");
            var id = entry.Id;
            kill.Click += (_, _) =>
            {
                _confirmKillId = id;
                Refresh();
            };
            actions.Children.Add(kill);
        }
        Grid.SetColumn(actions, 2);

        grid.Children.Add(portBadge);
        grid.Children.Add(info);
        grid.Children.Add(actions);
        return grid;
    }
}
