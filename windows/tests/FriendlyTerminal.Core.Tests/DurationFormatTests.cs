using FriendlyTerminal.Core.Output;
using Xunit;

namespace FriendlyTerminal.Core.Tests;

public class DurationFormatTests
{
    [Fact]
    public void Under_a_tenth_of_a_second_is_hidden()
    {
        Assert.Null(DurationFormat.Format(TimeSpan.FromMilliseconds(60)));
    }

    [Fact]
    public void Short_durations_show_one_decimal()
    {
        Assert.Equal("3.2s", DurationFormat.Format(TimeSpan.FromSeconds(3.24)));
        Assert.Equal("0.1s", DurationFormat.Format(TimeSpan.FromMilliseconds(120)));
    }

    [Fact]
    public void Under_a_minute_shows_whole_seconds()
    {
        Assert.Equal("43s", DurationFormat.Format(TimeSpan.FromSeconds(42.6)));
    }

    [Fact]
    public void Minutes_and_seconds()
    {
        Assert.Equal("1m 12s", DurationFormat.Format(TimeSpan.FromSeconds(72)));
    }

    [Fact]
    public void Hours_and_minutes()
    {
        Assert.Equal("1h 5m", DurationFormat.Format(TimeSpan.FromMinutes(65)));
    }
}
