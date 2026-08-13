namespace FriendlyTerminal.Core.Output;

/// <summary>Path handling for `git status --porcelain` output.</summary>
public static class GitPath
{
    // Porcelain C-quotes paths with special chars; octal escapes are raw UTF-8 bytes,
    // so non-ASCII names must be unescaped or staging them silently fails.
    public static string Unquote(string path)
    {
        if (path.Length < 2 || path[0] != '"' || path[^1] != '"') return path;
        var inner = path[1..^1];
        if (!inner.Contains('\\')) return inner;
        var bytes = new List<byte>(inner.Length);
        for (var i = 0; i < inner.Length; i++)
        {
            var c = inner[i];
            if (c != '\\' || i + 1 >= inner.Length)
            {
                bytes.AddRange(System.Text.Encoding.UTF8.GetBytes(c.ToString()));
                continue;
            }
            var next = inner[++i];
            if (next is >= '0' and <= '7')
            {
                var value = 0;
                for (var d = 0; d < 3 && i < inner.Length && inner[i] is >= '0' and <= '7'; d++, i++)
                    value = value * 8 + (inner[i] - '0');
                i--;
                bytes.Add((byte)value);
                continue;
            }
            bytes.AddRange(System.Text.Encoding.UTF8.GetBytes((next switch
            {
                't' => '\t',
                'n' => '\n',
                'r' => '\r',
                _ => next,
            }).ToString()));
        }
        return System.Text.Encoding.UTF8.GetString(bytes.ToArray());
    }
}
