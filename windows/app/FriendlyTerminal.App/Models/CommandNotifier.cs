using FriendlyTerminal.Core.Output;
using Microsoft.UI.Dispatching;
using Microsoft.Windows.AppNotifications;
using Microsoft.Windows.AppNotifications.Builder;

namespace FriendlyTerminal.App.Models;

/// <summary>
/// Windows toast when a long-running command finishes while the window is in
/// the background, so users can switch away during an npm install without
/// wondering whether it's done. Registration can fail on some setups; the app
/// simply runs without toasts then.
/// </summary>
public static class CommandNotifier
{
    private static readonly TimeSpan MinimumDuration = TimeSpan.FromSeconds(15);
    private static bool _registered;

    public static bool WindowIsActive { get; set; } = true;

    /// <summary>Set by the window; invoked on the UI thread when a toast is clicked.</summary>
    public static Action? ActivateWindow { get; set; }

    public static void Initialize(DispatcherQueue dispatcher)
    {
        try
        {
            AppNotificationManager.Default.NotificationInvoked += (_, _) =>
                dispatcher.TryEnqueue(() => ActivateWindow?.Invoke());
            AppNotificationManager.Default.Register();
            _registered = true;
        }
        catch { }
    }

    public static void Shutdown()
    {
        if (!_registered) return;
        try { AppNotificationManager.Default.Unregister(); } catch { }
    }

    public static void CommandFinished(CommandBlock block)
    {
        if (!_registered || WindowIsActive) return;
        if (block.Duration is not { } duration || duration < MinimumDuration) return;

        var title = block.Command.Length > 60 ? block.Command[..57] + "..." : block.Command;
        if (title.Length == 0) return;
        var body = block.Succeeded
            ? $"Finished successfully in {DurationFormat.Format(duration)}."
            : $"Failed (exit {block.ExitCode}) after {DurationFormat.Format(duration)}.";
        try
        {
            AppNotificationManager.Default.Show(
                new AppNotificationBuilder().AddText(title).AddText(body).BuildNotification());
        }
        catch { }
    }
}
