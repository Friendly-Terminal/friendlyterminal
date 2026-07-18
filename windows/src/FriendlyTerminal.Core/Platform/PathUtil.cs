namespace FriendlyTerminal.Core.Platform;

public static class PathUtil
{
    private static readonly char[] Separators = { '/', '\\' };

    public static string Resolve(string path, string cwd, string home)
    {
        if (path.Length == 0) return cwd;
        if (path[0] == '~') return home + path[1..];
        if (IsRooted(path)) return path;
        return Combine(cwd, path);
    }

    /// <summary>Absolute on Windows or POSIX: drive-rooted (C:\x), drive-relative
    /// or UNC (\\server\share), or a leading separator. PowerShell accepts both
    /// separators, so either form counts.</summary>
    public static bool IsRooted(string path)
    {
        if (path.Length == 0) return false;
        var c = path[0];
        if (c == '/' || c == '\\') return true;
        return path.Length >= 2 && path[1] == ':' &&
               (char.IsAsciiLetterUpper(c) || char.IsAsciiLetterLower(c));
    }

    public static string LastComponent(string path)
    {
        var trimmed = path.TrimEnd(Separators);
        var slash = trimmed.LastIndexOfAny(Separators);
        return slash < 0 ? trimmed : trimmed[(slash + 1)..];
    }

    public static string Combine(string a, string b)
    {
        if (a.Length == 0) return b;
        var sep = a.IndexOf('\\') >= 0 ? '\\' : '/';
        return a.TrimEnd(Separators) + sep + b;
    }
}
