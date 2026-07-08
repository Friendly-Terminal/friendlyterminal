using System.Collections.Specialized;
using System.ComponentModel;
using FriendlyTerminal.App.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace FriendlyTerminal.App.Views;

/// <summary>
/// Scrolling list of command blocks with a running indicator + Stop button while
/// a command executes. Children are managed by hand (blocks only append/clear),
/// which lets each BlockView carry the session for re-run/undo actions.
/// </summary>
public sealed partial class BlockListView : UserControl
{
    private SessionState? _session;
    private CommandBlock? _watchedBlock;

    public SessionState? Session
    {
        get => _session;
        set
        {
            if (_session is not null)
                _session.Blocks.Blocks.CollectionChanged -= OnBlocksChanged;
            _session = value;
            BlocksPanel.Children.Clear();
            if (_session is null) return;
            foreach (var block in _session.Blocks.Blocks)
                BlocksPanel.Children.Add(new BlockView(_session, block));
            _session.Blocks.Blocks.CollectionChanged += OnBlocksChanged;
            UpdateChrome();
        }
    }

    public BlockListView()
    {
        InitializeComponent();
    }

    private void OnBlocksChanged(object? sender, NotifyCollectionChangedEventArgs e)
    {
        if (_session is null) return;
        switch (e.Action)
        {
            case NotifyCollectionChangedAction.Add:
                foreach (var item in e.NewItems!.OfType<CommandBlock>())
                {
                    BlocksPanel.Children.Add(new BlockView(_session, item));
                    WatchBlock(item);
                }
                break;
            case NotifyCollectionChangedAction.Reset:
                BlocksPanel.Children.Clear();
                break;
        }
        UpdateChrome();
        ScrollToBottom();
    }

    /// <summary>Track the running block so streamed output keeps the view pinned to the bottom.</summary>
    private void WatchBlock(CommandBlock block)
    {
        if (_watchedBlock is not null)
            _watchedBlock.PropertyChanged -= OnWatchedBlockChanged;
        _watchedBlock = block;
        block.PropertyChanged += OnWatchedBlockChanged;
    }

    private void OnWatchedBlockChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(CommandBlock.PlainText))
        {
            ScrollToBottom();
        }
        else if (e.PropertyName == nameof(CommandBlock.ExitCode))
        {
            UpdateChrome();
            ScrollToBottom();
        }
    }

    private void UpdateChrome()
    {
        var running = _session?.Blocks.CurrentBlock is not null;
        RunningRow.Visibility = running ? Visibility.Visible : Visibility.Collapsed;
        EmptyHint.Visibility = (_session?.Blocks.Blocks.Count ?? 0) == 0 && !running
            ? Visibility.Visible
            : Visibility.Collapsed;
    }

    private void ScrollToBottom()
    {
        // Let layout settle before measuring the new extent.
        DispatcherQueue.TryEnqueue(() =>
            Scroller.ChangeView(null, Scroller.ScrollableHeight, null, disableAnimation: true));
    }

    private void OnStop(object sender, RoutedEventArgs e) => _session?.SendRaw("\u0003");
}
