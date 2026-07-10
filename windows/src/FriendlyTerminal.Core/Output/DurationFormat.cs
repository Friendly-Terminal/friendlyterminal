using System.Globalization;

namespace FriendlyTerminal.Core.Output;

public static class DurationFormat
{
    /// <summary>
    /// Human text for a command duration ("3.2s", "42s", "1m 12s"), or null
    /// when it ran in under 0.1s - showing near-zero times is just noise.
    /// </summary>
    public static string? Format(TimeSpan duration)
    {
        var seconds = duration.TotalSeconds;
        if (seconds < 0.1) return null;
        if (seconds < 10) return seconds.ToString("0.0", CultureInfo.InvariantCulture) + "s";
        if (seconds < 60) return Math.Round(seconds).ToString(CultureInfo.InvariantCulture) + "s";
        if (duration.TotalMinutes < 60) return $"{(int)duration.TotalMinutes}m {duration.Seconds}s";
        return $"{(int)duration.TotalHours}h {duration.Minutes}m";
    }
}
