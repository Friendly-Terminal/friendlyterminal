using System.IO;
using FriendlyTerminal.App.Pty;
using FriendlyTerminal.App.Views;
using FriendlyTerminal.Core.ShellIntegration;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using Microsoft.Web.WebView2.Core;

namespace FriendlyTerminal.App;

public sealed partial class MainWindow : Window
{
    private readonly SessionState _session = new();
    private readonly OscParser _osc = new();
    private PtyConnection? _pty;
    // Set on close so the PTY reader thread stops forwarding output into a tearing-down WebView2.
    private int _closing;

    public MainWindow()
    {
        InitializeComponent();

        Sidebar.Session = _session;
        _session.SendToShell = text => _pty?.WriteInput(text);
        _osc.WorkingDirectoryChanged += OnCwdChanged;

        // Seed the file panel before the first OSC arrives so it isn't blank on launch.
        _session.SetCurrentDirectory(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile));

        Terminal.Loaded += OnTerminalLoaded;
        Closed += OnClosed;

        try { SystemBackdrop = new MicaBackdrop(); }
        catch { /* Mica isn't available on this OS build; fall back to the default backdrop. */ }
    }

    private void OnClosed(object sender, WindowEventArgs args)
    {
        Volatile.Write(ref _closing, 1);
        _pty?.Dispose();
        Terminal.Close();
    }

    private async void OnTerminalLoaded(object sender, RoutedEventArgs e)
    {
        await Terminal.EnsureCoreWebView2Async();
        Terminal.CoreWebView2.WebMessageReceived += OnWebMessage;

        var html = Path.Combine(AppContext.BaseDirectory, "Assets", "terminal.html");
        Terminal.CoreWebView2.Navigate(new Uri(html).AbsoluteUri);
    }

    private void OnWebMessage(CoreWebView2 sender, CoreWebView2WebMessageReceivedEventArgs args)
    {
        var message = args.TryGetWebMessageAsString();
        if (string.IsNullOrEmpty(message)) return;

        if (message == "ready")
            StartShell();
        else if (message.StartsWith("i:"))
            _pty?.WriteInput(message[2..]);
        else if (message.StartsWith("r:") && message.Length > 2)
        {
            var parts = message[2..].Split('x');
            if (parts.Length == 2 && int.TryParse(parts[0], out var cols) && int.TryParse(parts[1], out var rows) && cols > 0 && rows > 0)
                _pty?.Resize(cols, rows);
        }
    }

    private void StartShell()
    {
        // Source the shell-integration profile so the prompt emits OSC 9;9 (cwd) + 133
        // markers the OscParser reads. Falls back to a plain shell if the file is missing.
        var profilePath = Path.Combine(AppContext.BaseDirectory, "Shell", "Microsoft.PowerShell_profile.ps1");
        var command = File.Exists(profilePath)
            ? $"powershell.exe -NoLogo -NoExit -Command \". '{profilePath.Replace("'", "''")}'\""
            : "powershell.exe -NoLogo -NoExit";

        _pty = new PtyConnection(command, 120, 30);
        _pty.OutputReceived += OnPtyOutput;
        _pty.Start();
    }

    private void OnPtyOutput(byte[] data)
    {
        // Feed the parser a copy of the stream for cwd tracking; raw bytes still go to xterm.
        _osc.Feed(data, data.Length);

        // Raised on the PTY reader thread; stop forwarding once the window is closing.
        if (Volatile.Read(ref _closing) != 0) return;

        var b64 = Convert.ToBase64String(data);
        DispatcherQueue.TryEnqueue(() =>
        {
            if (Volatile.Read(ref _closing) != 0) return;
            if (Terminal.CoreWebView2 is null) return;
            // Fire-and-forget is safe here: a discarded Task won't crash the process the way
            // an async-void queued handler would if the script call fails mid-teardown.
            try { _ = Terminal.CoreWebView2.ExecuteScriptAsync($"window.ptyWrite('{b64}')"); }
            catch { /* racing teardown; losing this chunk during shutdown is harmless */ }
        });
    }

    private void OnCwdChanged(string path)
    {
        // Raised on the PTY reader thread; marshal to the UI thread before touching state.
        DispatcherQueue.TryEnqueue(() => _session.SetCurrentDirectory(path));
    }
}
