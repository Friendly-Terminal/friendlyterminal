using System.ComponentModel;
using System.IO;
using FriendlyTerminal.App.Pty;
using FriendlyTerminal.Core.ShellIntegration;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.Web.WebView2.Core;

namespace FriendlyTerminal.App.Views;

/// <summary>
/// A single terminal pane: its own shell (ConPTY + xterm.js in WebView2), block
/// list, and command bar. The xterm view is shown only while a full-screen or
/// raw-mode program is active; otherwise commands and output live in tidy
/// blocks, like the macOS app.
/// </summary>
public sealed partial class TerminalPaneView : UserControl
{
    private readonly ShellIntegrationStream _stream = new();
    private PtyConnection? _pty;
    private int _closing;
    private bool _isFocusedPane;
    private bool _showHeader;

    // Input typed before the shell process exists is queued rather than dropped.
    private readonly Queue<string> _pendingInput = new();

    // Coalesce PTY reads that arrive between UI ticks into a single WebView write
    // and a single batch of shell-integration events, so bursts don't queue quadratic work.
    private readonly object _pendingLock = new();
    private readonly List<ShellEvent> _pendingEvents = new();
    private readonly MemoryStream _pendingBytes = new();
    private bool _flushScheduled;

    private bool _ready;
    private bool _errorShown;
    private DispatcherQueueTimer? _readyTimer;

    public SessionState Session { get; } = new();

    /// <summary>Raised when the shell exits on its own (e.g. the user typed `exit`).</summary>
    public event Action<TerminalPaneView>? Exited;

    /// <summary>Raised when the user clicks the pane header's close button.</summary>
    public event Action<TerminalPaneView>? CloseRequested;

    /// <summary>Raised when the user interacts with this pane and it should take focus.</summary>
    public event Action<TerminalPaneView>? FocusRequested;

    public TerminalPaneView()
    {
        InitializeComponent();

        BlockList.Session = Session;
        CommandBar.Session = Session;
        Session.SendToShell = SendInput;
        Session.SetCurrentDirectory(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile));
        Session.PropertyChanged += OnSessionChanged;

        Loaded += OnLoaded;
        AddHandler(PointerPressedEvent, new PointerEventHandler((_, _) => FocusRequested?.Invoke(this)), true);
        GotFocus += (_, _) => FocusRequested?.Invoke(this);
    }

    public bool IsFocusedPane
    {
        get => _isFocusedPane;
        set
        {
            _isFocusedPane = value;
            UpdateHeader();
        }
    }

    public bool ShowHeader
    {
        get => _showHeader;
        set
        {
            _showHeader = value;
            UpdateHeader();
        }
    }

    public void FocusCommandBar() => CommandBar.FocusInput();

    /// <summary>Tour target for onboarding.</summary>
    public FrameworkElement CommandBarTarget => CommandBar;

    private bool _started;

    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        if (_started) return;
        _started = true;

        try
        {
            await Xterm.EnsureCoreWebView2Async();
            if (Volatile.Read(ref _closing) != 0 || Xterm.CoreWebView2 is null) return;

            Xterm.CoreWebView2.WebMessageReceived += OnWebMessage;
            Xterm.CoreWebView2.NavigationCompleted += OnNavigationCompleted;

            var html = Path.Combine(AppContext.BaseDirectory, "Assets", "terminal.html");
            Xterm.CoreWebView2.Navigate(new Uri(html).AbsoluteUri);

            _readyTimer = DispatcherQueue.CreateTimer();
            _readyTimer.Interval = TimeSpan.FromSeconds(8);
            _readyTimer.IsRepeating = false;
            _readyTimer.Tick += (_, _) =>
            {
                if (!_ready)
                    ShowTerminalError("The terminal did not finish loading.");
            };
            _readyTimer.Start();
        }
        catch (Exception ex)
        {
            ShowTerminalError("The terminal failed to start.", ex);
        }
    }

    private void OnNavigationCompleted(CoreWebView2 sender, CoreWebView2NavigationCompletedEventArgs args)
    {
        if (Volatile.Read(ref _closing) != 0 || _ready || _errorShown) return;
        if (!args.IsSuccess)
            ShowTerminalError($"The terminal view failed to load ({args.WebErrorStatus}).");
    }

    private void OnWebMessage(CoreWebView2 sender, CoreWebView2WebMessageReceivedEventArgs args)
    {
        var message = args.TryGetWebMessageAsString();
        if (string.IsNullOrEmpty(message)) return;

        if (message == "ready")
        {
            if (_errorShown) return;
            _ready = true;
            _readyTimer?.Stop();
            StartShell();
        }
        else if (message.StartsWith("i:"))
            SendInput(message[2..]);
        else if (message.StartsWith("r:") && message.Length > 2)
        {
            var parts = message[2..].Split('x');
            if (parts.Length == 2 && int.TryParse(parts[0], out var cols) && int.TryParse(parts[1], out var rows) && cols > 0 && rows > 0)
                _pty?.Resize(cols, rows);
        }
    }

    private void ShowTerminalError(string message, Exception? ex = null)
    {
        if (_errorShown || Volatile.Read(ref _closing) != 0) return;
        _errorShown = true;
        _readyTimer?.Stop();

        var text = ex is null ? message : $"{message}\n\n{ex.Message}";
        if (Xterm.Parent is not Panel host) return;

        Xterm.Visibility = Visibility.Collapsed;
        BlockList.Visibility = Visibility.Collapsed;
        host.Children.Add(new TextBlock
        {
            Text = text,
            TextWrapping = TextWrapping.Wrap,
            Padding = new Thickness(24),
            VerticalAlignment = VerticalAlignment.Center,
            Foreground = new SolidColorBrush(Microsoft.UI.Colors.Salmon),
        });
    }

    private void StartShell()
    {
        // Source the shell-integration profile so the prompt emits the OSC markers
        // (cwd, block boundaries, command text) the stream parser reads. -ExecutionPolicy
        // Bypass (process-scoped, not persisted) lets the unsigned profile dot-source under
        // the default Restricted policy on client SKUs, where it would otherwise be blocked.
        var profilePath = Path.Combine(AppContext.BaseDirectory, "Shell", "Microsoft.PowerShell_profile.ps1");
        var command = File.Exists(profilePath)
            ? $"powershell.exe -NoLogo -NoExit -ExecutionPolicy Bypass -Command \". '{profilePath.Replace("'", "''")}'\""
            : "powershell.exe -NoLogo -NoExit";

        _pty = new PtyConnection(command, 120, 30);
        _pty.OutputReceived += OnPtyOutput;
        _pty.Exited += () => DispatcherQueue.TryEnqueue(() =>
        {
            if (Volatile.Read(ref _closing) == 0)
                Exited?.Invoke(this);
        });
        _pty.Start();

        while (_pendingInput.Count > 0)
            _pty.WriteInput(_pendingInput.Dequeue());
    }

    // Queue input typed or dispatched before the shell process exists so it isn't lost;
    // StartShell drains the queue once the PTY is up.
    private void SendInput(string text)
    {
        if (_pty is null)
            _pendingInput.Enqueue(text);
        else
            _pty.WriteInput(text);
    }

    private void OnPtyOutput(byte[] data)
    {
        // Raised on the PTY reader thread; stop forwarding once the pane is closing.
        if (Volatile.Read(ref _closing) != 0) return;

        // Parse shell-integration events off-thread; buffer bytes+events for the next UI tick.
        var events = _stream.Feed(data);

        bool schedule;
        lock (_pendingLock)
        {
            _pendingEvents.AddRange(events);
            _pendingBytes.Write(data, 0, data.Length);
            schedule = !_flushScheduled;
            _flushScheduled = true;
        }

        if (schedule)
            DispatcherQueue.TryEnqueue(FlushPtyOutput);
    }

    private void FlushPtyOutput()
    {
        ShellEvent[] events;
        byte[] bytes;
        lock (_pendingLock)
        {
            _flushScheduled = false;
            events = _pendingEvents.ToArray();
            _pendingEvents.Clear();
            bytes = _pendingBytes.ToArray();
            _pendingBytes.SetLength(0);
        }

        if (Volatile.Read(ref _closing) != 0) return;

        foreach (var evt in events)
            Session.HandleShellEvent(evt);

        if (bytes.Length == 0 || Xterm.CoreWebView2 is null) return;

        var b64 = Convert.ToBase64String(bytes);
        // Fire-and-forget is safe here: a discarded Task won't crash the process
        // the way an async-void queued handler would if the call fails mid-teardown.
        try { _ = Xterm.CoreWebView2.ExecuteScriptAsync($"window.ptyWrite('{b64}')"); }
        catch { /* racing teardown; losing this chunk during shutdown is harmless */ }
    }

    private void OnSessionChanged(object? sender, PropertyChangedEventArgs e)
    {
        switch (e.PropertyName)
        {
            case nameof(SessionState.IsTuiActive):
            case nameof(SessionState.IsClaudeRunning):
                var tui = Session.IsTuiActive;
                Xterm.Visibility = tui ? Visibility.Visible : Visibility.Collapsed;
                BlockList.Visibility = tui ? Visibility.Collapsed : Visibility.Visible;
                // While Claude runs, the command bar is the input surface, not xterm.
                Xterm.IsHitTestVisible = tui && !Session.IsClaudeRunning;
                if (tui && !Session.IsClaudeRunning)
                    Xterm.Focus(FocusState.Programmatic);
                break;
            case nameof(SessionState.CurrentDirectory):
                UpdateHeader();
                break;
        }
    }

    private void UpdateHeader()
    {
        PaneHeader.Visibility = _showHeader ? Visibility.Visible : Visibility.Collapsed;
        FocusStrip.Visibility = _showHeader && _isFocusedPane ? Visibility.Visible : Visibility.Collapsed;
        var name = Path.GetFileName(Session.CurrentDirectory.TrimEnd('\\', '/'));
        PaneTitle.Text = string.IsNullOrEmpty(name) ? Session.CurrentDirectory : name;
        PaneTitle.FontWeight = _isFocusedPane
            ? Microsoft.UI.Text.FontWeights.SemiBold
            : Microsoft.UI.Text.FontWeights.Normal;
        PaneTitle.Opacity = _isFocusedPane ? 1.0 : 0.7;
    }

    private void OnCloseClicked(object sender, RoutedEventArgs e) => CloseRequested?.Invoke(this);

    public void Shutdown()
    {
        Volatile.Write(ref _closing, 1);
        _readyTimer?.Stop();
        _pty?.Dispose();
        Xterm.Close();
    }
}
