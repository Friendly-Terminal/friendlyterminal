using System.Text;

namespace FriendlyTerminal.Core.ShellIntegration;

/// <summary>
/// Stateful scanner that consumes the raw PTY byte stream in arbitrarily sized
/// chunks. It pulls the shell-integration OSC markers (133/633/9;9/7) out as
/// events, discards ANSI styling/cursor escapes, and reports the remaining
/// visible text as <see cref="ShellEvent.Output"/> events. Incomplete escape or
/// UTF-8 sequences at a chunk boundary are buffered and re-processed when the
/// next chunk arrives. Port of the macOS ShellIntegrationParser.Stream.
/// </summary>
public sealed class ShellIntegrationStream
{
    // Cap on an unterminated escape sequence buffered across chunks. A malformed
    // OSC (no BEL/ST) or CSI (no final byte) would otherwise grow without bound
    // and swallow every later marker; on overflow we give up and flush it as output.
    private const int MaxPendingBytes = 64 * 1024;

    private byte[] _pending = Array.Empty<byte>();

    public List<ShellEvent> Feed(ReadOnlySpan<byte> incoming)
    {
        var bytes = new byte[_pending.Length + incoming.Length];
        _pending.CopyTo(bytes, 0);
        incoming.CopyTo(bytes.AsSpan(_pending.Length));
        _pending = Array.Empty<byte>();

        var events = new List<ShellEvent>();
        var text = new List<byte>();

        void FlushText()
        {
            if (text.Count == 0) return;
            var raw = Encoding.UTF8.GetString(text.ToArray());
            var normalized = raw.Replace("\r\n", "\n").Replace("\r", "");
            if (normalized.Length > 0)
                events.Add(new ShellEvent.Output(normalized));
            text.Clear();
        }

        var n = bytes.Length;
        var i = 0;
        var brokeEarly = false;

        while (i < n)
        {
            var b = bytes[i];

            if (b != 0x1B)
            {
                text.Add(b);
                i++;
                continue;
            }

            // ESC: need at least one more byte to classify the sequence.
            if (i + 1 >= n)
            {
                _pending = bytes[i..];
                brokeEarly = true;
                break;
            }

            var c = bytes[i + 1];

            if (c == 0x5D)
            {
                // OSC: ESC ] ... (terminated by BEL or ESC \).
                var j = i + 2;
                int end = -1;
                var terminatorLen = 1;
                var incomplete = false;
                while (j < n)
                {
                    if (bytes[j] == 0x07) { end = j; terminatorLen = 1; break; }
                    if (bytes[j] == 0x1B)
                    {
                        if (j + 1 < n)
                        {
                            if (bytes[j + 1] == 0x5C) { end = j; terminatorLen = 2; break; }
                        }
                        else
                        {
                            incomplete = true;
                            break;
                        }
                    }
                    j++;
                }
                if (end < 0 || incomplete)
                {
                    if (n - i > MaxPendingBytes)
                    {
                        // Overflow recovery: no terminator in a buffer this large
                        // means the OSC is malformed. Flush it as plain output and
                        // resume clean parsing so later markers are seen again.
                        for (var k = i; k < n; k++) text.Add(bytes[k]);
                        i = n;
                        continue;
                    }
                    _pending = bytes[i..];
                    brokeEarly = true;
                    break;
                }
                var body = Encoding.UTF8.GetString(bytes, i + 2, end - (i + 2));
                if (ParseOsc(body) is { } evt)
                {
                    FlushText();
                    events.Add(evt);
                }
                // Recognized or not, the OSC is control data - drop it from output.
                i = end + terminatorLen;
                continue;
            }

            if (c == 0x5B)
            {
                // CSI: ESC [ ... <final byte 0x40-0x7E>.
                var j = i + 2;
                int end = -1;
                while (j < n)
                {
                    var bj = bytes[j];
                    if (bj >= 0x40 && bj <= 0x7E) { end = j; break; }
                    j++;
                }
                if (end < 0)
                {
                    if (n - i > MaxPendingBytes)
                    {
                        // Overflow recovery: no final byte in a buffer this large
                        // means the CSI is malformed. Flush it as plain output and
                        // resume clean parsing so later markers are seen again.
                        for (var k = i; k < n; k++) text.Add(bytes[k]);
                        i = n;
                        continue;
                    }
                    _pending = bytes[i..];
                    brokeEarly = true;
                    break;
                }
                // Detect interactivity signals. Full-screen programs (vim, less,
                // top) switch to the alternate screen; raw-mode programs that
                // render inline (Claude Code, REPLs) instead turn on bracketed-
                // paste mode. Both mean "this program wants the keyboard."
                var finalByte = bytes[end];
                if (finalByte is 0x68 or 0x6C) // 'h' (set) / 'l' (reset)
                {
                    var isSet = finalByte == 0x68;
                    var body = Encoding.ASCII.GetString(bytes, i + 2, end - (i + 2));
                    if (body is "?1049" or "?1047" or "?47")
                    {
                        FlushText();
                        events.Add(new ShellEvent.AltScreen(isSet));
                    }
                    else if (body == "?2004")
                    {
                        FlushText();
                        events.Add(new ShellEvent.BracketedPaste(isSet));
                    }
                }
                i = end + 1;
                continue;
            }

            if (c is 0x28 or 0x29)
            {
                // Charset designation: ESC ( X / ESC ) X (3 bytes).
                if (i + 2 >= n)
                {
                    _pending = bytes[i..];
                    brokeEarly = true;
                    break;
                }
                i += 3;
                continue;
            }

            // Other two-byte escape (ESC =, ESC >, ESC M, ...).
            i += 2;
        }

        // If we consumed everything cleanly, hold back any trailing bytes that
        // form an incomplete UTF-8 scalar so we don't emit replacement chars.
        if (!brokeEarly)
        {
            var keep = IncompleteUtf8TailLength(text);
            if (keep > 0)
            {
                _pending = text.Skip(text.Count - keep).ToArray();
                text.RemoveRange(text.Count - keep, keep);
            }
        }

        FlushText();
        return events;
    }

    public static ShellEvent? ParseOsc(string osc)
    {
        if (osc == "133;A") return new ShellEvent.PromptStart();
        if (osc == "133;B") return new ShellEvent.CommandStart();
        if (osc == "133;C") return new ShellEvent.OutputStart();

        if (osc.StartsWith("133;D", StringComparison.Ordinal))
        {
            if (osc == "133;D") return new ShellEvent.CommandEnd(0);
            var rest = osc["133;D;".Length..];
            return new ShellEvent.CommandEnd(int.TryParse(rest, out var code) ? code : 0);
        }

        if (osc.StartsWith("633;E;", StringComparison.Ordinal))
        {
            var b64 = osc["633;E;".Length..];
            try
            {
                var text = Encoding.UTF8.GetString(Convert.FromBase64String(b64));
                return new ShellEvent.CommandText(text);
            }
            catch (FormatException)
            {
                return null;
            }
        }

        if (osc.StartsWith("9;9;", StringComparison.Ordinal))
        {
            var path = osc["9;9;".Length..];
            return path.Length > 0 ? new ShellEvent.CwdUpdate(path) : null;
        }

        if (osc.StartsWith("7;", StringComparison.Ordinal))
        {
            var uriString = osc[2..];
            if (Uri.TryCreate(uriString, UriKind.Absolute, out var uri) && uri.IsFile)
                return new ShellEvent.CwdUpdate(uri.LocalPath);
            return new ShellEvent.CwdUpdate(uriString);
        }

        return null;
    }

    private static int IncompleteUtf8TailLength(List<byte> b)
    {
        var idx = b.Count - 1;
        var continuations = 0;
        while (idx >= 0 && (b[idx] & 0xC0) == 0x80)
        {
            continuations++;
            idx--;
            if (continuations > 3) return 0;
        }
        if (idx < 0) return 0;

        var lead = b[idx];
        int expected;
        if ((lead & 0x80) == 0) return 0;
        if ((lead & 0xE0) == 0xC0) expected = 1;
        else if ((lead & 0xF0) == 0xE0) expected = 2;
        else if ((lead & 0xF8) == 0xF0) expected = 3;
        else return 0;

        return continuations < expected ? continuations + 1 : 0;
    }
}
