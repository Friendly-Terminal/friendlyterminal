using System.IO;

namespace FriendlyTerminal.App.Models;

public sealed class FileEntry
{
    // Segoe Fluent Icons PUA code points (verified against Microsoft Learn glyph list).
    private const int Folder = 0xE8B7;
    private const int Page = 0xE7C3;
    private const int Code = 0xE943;
    private const int Picture = 0xE8B9;
    private const int Pdf = 0xEA90;
    private const int Audio = 0xE8D6;
    private const int Video = 0xEA0C;
    private const int ZipFolder = 0xF012;

    private static string GlyphFrom(int code) => char.ConvertFromUtf32(code);

    public string Name { get; }
    public string Path { get; }
    public bool IsDirectory { get; }
    public bool IsHidden { get; }
    public long Size { get; }
    public string Glyph { get; }

    public string SizeDisplay => IsDirectory ? "" : FormatSize(Size);

    public FileEntry(string name, string fullPath, bool isDirectory, bool isHidden, long size)
    {
        Name = name;
        Path = fullPath;
        IsDirectory = isDirectory;
        IsHidden = isHidden;
        Size = size;
        Glyph = isDirectory ? GlyphFrom(Folder) : GlyphForExtension(System.IO.Path.GetExtension(name));
    }

    /// <summary>Lists <paramref name="directory" />, directories first then by name, skipping
    /// anything the OS won't let us read.</summary>
    public static List<FileEntry> List(string directory)
    {
        var entries = new List<FileEntry>();
        if (string.IsNullOrEmpty(directory) || !Directory.Exists(directory))
            return entries;

        // Materialize inside the guard: enumeration is lazy, so a disconnected share,
        // deleted folder, or permission change surfaces during iteration, not construction.
        List<string> children;
        try { children = Directory.EnumerateFileSystemEntries(directory).ToList(); }
        catch { return entries; }

        foreach (var full in children)
        {
            FileAttributes attr;
            try { attr = File.GetAttributes(full); }
            catch { continue; }

            var isDirectory = attr.HasFlag(FileAttributes.Directory);
            long size = 0;
            if (!isDirectory)
            {
                try { size = new FileInfo(full).Length; } catch { }
            }

            entries.Add(new FileEntry(
                System.IO.Path.GetFileName(full),
                full,
                isDirectory,
                attr.HasFlag(FileAttributes.Hidden),
                size));
        }

        entries.Sort((a, b) =>
            a.IsDirectory != b.IsDirectory
                ? (a.IsDirectory ? -1 : 1)
                : string.Compare(a.Name, b.Name, StringComparison.OrdinalIgnoreCase));

        return entries;
    }

    private static string FormatSize(long bytes)
    {
        string[] units = ["B", "KB", "MB", "GB", "TB"];
        double size = bytes;
        var u = 0;
        while (size >= 1024 && u < units.Length - 1) { size /= 1024; u++; }
        return u == 0 ? $"{size} {units[u]}" : $"{size:0.#} {units[u]}";
    }

    private static string GlyphForExtension(string ext) => ext.ToLowerInvariant() switch
    {
        ".cs" or ".vb" or ".py" or ".js" or ".jsx" or ".ts" or ".tsx" or ".c" or ".cpp" or ".h" or ".hpp"
            or ".java" or ".go" or ".rs" or ".rb" or ".php" or ".swift" or ".ps1" or ".sh" or ".bat" or ".cmd" => GlyphFrom(Code),
        ".png" or ".jpg" or ".jpeg" or ".gif" or ".webp" or ".bmp" or ".ico" or ".svg" => GlyphFrom(Picture),
        ".pdf" => GlyphFrom(Pdf),
        ".mp3" or ".wav" or ".flac" or ".aac" or ".ogg" or ".m4a" => GlyphFrom(Audio),
        ".mp4" or ".mkv" or ".mov" or ".avi" or ".webm" => GlyphFrom(Video),
        ".zip" or ".gz" or ".tar" or ".rar" or ".7z" or ".bz2" => GlyphFrom(ZipFolder),
        _ => GlyphFrom(Page),
    };
}
