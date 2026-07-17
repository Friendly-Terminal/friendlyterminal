using System.Text;
using FriendlyTerminal.Core.ShellIntegration;
using Xunit;

namespace FriendlyTerminal.Core.Tests;

public class ShellIntegrationStreamTests
{
    private static byte[] B(string s) => Encoding.UTF8.GetBytes(s);

    private static List<ShellEvent> FeedAll(ShellIntegrationStream stream, byte[] bytes, int chunkSize = int.MaxValue)
    {
        var events = new List<ShellEvent>();
        for (var i = 0; i < bytes.Length; i += chunkSize)
        {
            var len = Math.Min(chunkSize, bytes.Length - i);
            events.AddRange(stream.Feed(bytes.AsSpan(i, len)));
        }
        return events;
    }

    [Fact]
    public void Emits_prompt_command_output_end_cycle()
    {
        var stream = new ShellIntegrationStream();
        var input = "\x1b]133;A\a\x1b]133;B\a\x1b]133;C\aout\n\x1b]133;D;0\a";
        var events = FeedAll(stream, B(input));

        Assert.Collection(events,
            e => Assert.IsType<ShellEvent.PromptStart>(e),
            e => Assert.IsType<ShellEvent.CommandStart>(e),
            e => Assert.IsType<ShellEvent.OutputStart>(e),
            e => Assert.Equal("out\n", Assert.IsType<ShellEvent.Output>(e).Text),
            e => Assert.Equal(0, Assert.IsType<ShellEvent.CommandEnd>(e).ExitCode));
    }

    [Fact]
    public void Decodes_633_E_command_text_base64()
    {
        var stream = new ShellIntegrationStream();
        var b64 = Convert.ToBase64String(B("git status"));
        var events = FeedAll(stream, B($"\x1b]633;E;{b64}\a"));

        var cmd = Assert.IsType<ShellEvent.CommandText>(Assert.Single(events));
        Assert.Equal("git status", cmd.Text);
    }

    [Fact]
    public void Parses_exit_code_from_133_D()
    {
        var stream = new ShellIntegrationStream();
        var events = FeedAll(stream, B("\x1b]133;D;42\x1b\\"));
        Assert.Equal(42, Assert.IsType<ShellEvent.CommandEnd>(Assert.Single(events)).ExitCode);
    }

    [Fact]
    public void Parses_cwd_from_9_9()
    {
        var stream = new ShellIntegrationStream();
        var events = FeedAll(stream, B("\x1b]9;9;C:\\Projects\\demo\a"));
        Assert.Equal("C:\\Projects\\demo", Assert.IsType<ShellEvent.CwdUpdate>(Assert.Single(events)).Path);
    }

    [Fact]
    public void Detects_alt_screen_and_bracketed_paste()
    {
        var stream = new ShellIntegrationStream();
        var events = FeedAll(stream, B("\x1b[?1049h\x1b[?1049l\x1b[?2004h"));

        Assert.Collection(events,
            e => Assert.True(Assert.IsType<ShellEvent.AltScreen>(e).On),
            e => Assert.False(Assert.IsType<ShellEvent.AltScreen>(e).On),
            e => Assert.True(Assert.IsType<ShellEvent.BracketedPaste>(e).On));
    }

    [Fact]
    public void Strips_csi_styling_and_normalizes_newlines()
    {
        var stream = new ShellIntegrationStream();
        var events = FeedAll(stream, B("\x1b[31mred\x1b[0m\r\nnext\r"));
        Assert.Equal("red\nnext", Assert.IsType<ShellEvent.Output>(Assert.Single(events)).Text);
    }

    [Theory]
    [InlineData(1)]
    [InlineData(2)]
    [InlineData(3)]
    [InlineData(7)]
    public void Survives_arbitrary_chunk_boundaries(int chunkSize)
    {
        var stream = new ShellIntegrationStream();
        var input = "\x1b]133;C\ahello\x1b]9;9;C:\\x\aworld\x1b]133;D;1\a";
        var events = FeedAll(stream, B(input), chunkSize);

        Assert.Contains(events, e => e is ShellEvent.OutputStart);
        Assert.Contains(events, e => e is ShellEvent.CwdUpdate c && c.Path == "C:\\x");
        Assert.Contains(events, e => e is ShellEvent.CommandEnd { ExitCode: 1 });
        var text = string.Concat(events.OfType<ShellEvent.Output>().Select(o => o.Text));
        Assert.Equal("helloworld", text);
    }

    [Fact]
    public void Holds_back_incomplete_utf8_tail()
    {
        var stream = new ShellIntegrationStream();
        var full = B("héllo"); // é = 0xC3 0xA9
        var first = stream.Feed(full.AsSpan(0, 2)); // "h" + first byte of é
        var second = stream.Feed(full.AsSpan(2));

        var text = string.Concat(first.Concat(second).OfType<ShellEvent.Output>().Select(o => o.Text));
        Assert.Equal("héllo", text);
    }

    [Fact]
    public void Unknown_osc_is_dropped_from_output()
    {
        var stream = new ShellIntegrationStream();
        var events = FeedAll(stream, B("a\x1b]0;title\ab"));
        Assert.Equal("ab", string.Concat(events.OfType<ShellEvent.Output>().Select(o => o.Text)));
    }

    [Fact]
    public void Oversized_unterminated_osc_recovers_so_later_markers_still_parse()
    {
        var stream = new ShellIntegrationStream();

        // A malformed OSC that never terminates, larger than the internal cap.
        var junk = "\x1b]" + new string('x', 100_000);
        var first = stream.Feed(B(junk));

        // On overflow the buffered junk is flushed as plain output, not held forever.
        Assert.Contains(first, e => e is ShellEvent.Output);

        // A real command-end marker in the next chunk must be seen, not swallowed.
        var second = stream.Feed(B("\x1b]133;D;7\a"));
        Assert.Contains(second, e => e is ShellEvent.CommandEnd { ExitCode: 7 });
    }

    [Fact]
    public void Unterminated_osc_under_cap_is_still_buffered_across_chunks()
    {
        var stream = new ShellIntegrationStream();
        var b64 = Convert.ToBase64String(B("git status"));
        var full = B($"\x1b]633;E;{b64}\a");

        // Split mid-sequence: the first half has no terminator yet.
        var first = stream.Feed(full.AsSpan(0, full.Length - 3).ToArray());
        Assert.Empty(first.OfType<ShellEvent.CommandText>());

        var second = stream.Feed(full.AsSpan(full.Length - 3).ToArray());
        Assert.Equal("git status", Assert.IsType<ShellEvent.CommandText>(Assert.Single(second)).Text);
    }

    [Fact]
    public void Oversized_unterminated_csi_recovers_so_later_markers_still_parse()
    {
        var stream = new ShellIntegrationStream();

        // A malformed CSI that never reaches a final byte, larger than the internal cap.
        var junk = "\x1b[" + new string('0', 100_000);
        var first = stream.Feed(B(junk));

        // On overflow the buffered junk is flushed as plain output, not held forever.
        Assert.Contains(first, e => e is ShellEvent.Output);

        // A real command-end marker in the next chunk must be seen, not swallowed.
        var second = stream.Feed(B("\x1b]133;D;7\a"));
        Assert.Contains(second, e => e is ShellEvent.CommandEnd { ExitCode: 7 });
    }
}
