using System.Text;

namespace FriendlyTerminal.Core.ShellIntegration;

/// <summary>
/// Scans a PTY byte stream for OSC sequences the shell-integration profile emits,
/// without touching the bytes that still flow to the terminal renderer. Currently
/// extracts the working directory from OSC 9;9 (the iTerm/9;9 form the bundled
/// PowerShell profile writes) and OSC 7 (file:// URL) as a fallback.
///
/// State survives chunk boundaries, so a sequence split across two PTY reads still
/// resolves. OSC bodies are decoded as UTF-8 so accented folder names survive.
/// </summary>
public sealed class OscParser
{
    private const byte Esc = 0x1b;
    private const byte Bel = 0x07;
    private const byte OscStart = 0x5d;      // ]
    private const byte StTerminator = 0x5c;  // backslash, second byte of ST (ESC \)

    private bool _inOsc;
    private bool _escPending;
    private readonly List<byte> _oscBody = new();

    // Cap the buffer so a malformed/unterminated OSC sequence (e.g. from cat-ing a binary
    // file, or the shell dying mid-sequence) can't grow it without bound.
    private const int MaxOscBody = 65536;

    public event Action<string>? WorkingDirectoryChanged;

    public void Feed(byte[] buffer, int count)
    {
        for (var i = 0; i < count; i++)
            ProcessByte(buffer[i]);
    }

    public void Feed(byte[] buffer) => Feed(buffer, buffer.Length);

    private void ProcessByte(byte b)
    {
        if (_escPending)
        {
            _escPending = false;
            if (_inOsc)
            {
                if (b == StTerminator)
                {
                    _inOsc = false;
                    DispatchOsc();
                    _oscBody.Clear();
                }
                else
                {
                    // Stray ESC inside an OSC; keep the following byte, drop the ESC.
                    _oscBody.Add(b);
                    if (_oscBody.Count > MaxOscBody)
                    {
                        // Give up on this runaway sequence and resync to the ground state.
                        _inOsc = false;
                        _escPending = false;
                        _oscBody.Clear();
                    }
                }
            }
            else if (b == OscStart)
            {
                _inOsc = true;
                _oscBody.Clear();
            }
            // ESC followed by anything else (CSI, etc.) is consumed and ignored here.
            return;
        }

        if (b == Esc)
        {
            _escPending = true;
            return;
        }

        if (_inOsc)
        {
            if (b == Bel)
            {
                _inOsc = false;
                DispatchOsc();
                _oscBody.Clear();
            }
            else
            {
                _oscBody.Add(b);
                if (_oscBody.Count > MaxOscBody)
                {
                    // Give up on this runaway sequence and resync to the ground state.
                    _inOsc = false;
                    _escPending = false;
                    _oscBody.Clear();
                }
            }
        }
        // Ground bytes are ignored; the caller forwards the raw stream to the terminal.
    }

    private void DispatchOsc()
    {
        var body = Encoding.UTF8.GetString(_oscBody.ToArray());

        // OSC 9;9;<path>  (what the bundled PowerShell profile emits)
        const string cwdPrefix = "9;9;";
        if (body.StartsWith(cwdPrefix, StringComparison.Ordinal))
        {
            var path = body[cwdPrefix.Length..];
            if (!string.IsNullOrEmpty(path))
                WorkingDirectoryChanged?.Invoke(path);
            return;
        }

        // OSC 7;file://<host>/<path>  (common alternative)
        const string osc7 = "7;file://";
        if (body.StartsWith(osc7, StringComparison.Ordinal))
        {
            var uriString = body[2..]; // "file://..."
            if (Uri.TryCreate(uriString, UriKind.Absolute, out var uri))
                WorkingDirectoryChanged?.Invoke(uri.LocalPath);
        }
    }
}
