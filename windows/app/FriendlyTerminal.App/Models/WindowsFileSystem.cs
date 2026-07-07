using System.IO;
using FriendlyTerminal.Core.Platform;
using Microsoft.VisualBasic.FileIO;
using SearchOption = System.IO.SearchOption;

namespace FriendlyTerminal.App.Models;

/// <summary>
/// Real-filesystem backing for Core logic. "Trash" for plain deletes is the
/// Recycle Bin; intercepted deletions that must be restorable go to an
/// app-managed trash folder instead (the Recycle Bin API doesn't report where a
/// recycled item landed, so it can't be programmatically restored).
/// </summary>
public sealed class WindowsFileSystem : IFileSystem
{
    public static readonly WindowsFileSystem Instance = new();

    public string HomeDirectory => Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);

    public static string AppTrashDirectory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "FriendlyTerminal", "Trash");

    public bool Exists(string path) => File.Exists(path) || Directory.Exists(path);

    public bool IsDirectory(string path) => Directory.Exists(path);

    public IReadOnlyList<string> ListDirectory(string path)
    {
        try { return Directory.EnumerateFileSystemEntries(path, "*", SearchOption.TopDirectoryOnly).ToList(); }
        catch { return Array.Empty<string>(); }
    }

    public IReadOnlyList<DirEntry> ListEntries(string path)
    {
        var entries = new List<DirEntry>();
        IEnumerable<string> children;
        try { children = Directory.EnumerateFileSystemEntries(path); }
        catch { return entries; }

        foreach (var full in children)
        {
            FileAttributes attr;
            try { attr = File.GetAttributes(full); }
            catch { continue; }
            entries.Add(new DirEntry(
                Path.GetFileName(full),
                attr.HasFlag(FileAttributes.Directory),
                attr.HasFlag(FileAttributes.Hidden)));
        }
        return entries;
    }

    public void MoveToTrash(string path)
    {
        try
        {
            if (Directory.Exists(path))
                FileSystem.DeleteDirectory(path, UIOption.OnlyErrorDialogs, RecycleOption.SendToRecycleBin);
            else if (File.Exists(path))
                FileSystem.DeleteFile(path, UIOption.OnlyErrorDialogs, RecycleOption.SendToRecycleBin);
        }
        catch { /* best effort - leaving the item in place is the safe failure */ }
    }

    public void RestoreFromTrash(string trashedPath, string originalPath)
    {
        try
        {
            if (Directory.Exists(trashedPath))
                Directory.Move(trashedPath, originalPath);
            else if (File.Exists(trashedPath))
                File.Move(trashedPath, originalPath);
        }
        catch { }
    }

    /// <summary>
    /// Moves an item into the app trash folder and returns where it landed, so an
    /// undo can move it back. Returns null if the move failed.
    /// </summary>
    public string? MoveToAppTrash(string path)
    {
        try
        {
            var stamp = DateTime.Now.ToString("yyyyMMdd-HHmmss-fff");
            var dir = Path.Combine(AppTrashDirectory, stamp);
            Directory.CreateDirectory(dir);
            var dest = Path.Combine(dir, Path.GetFileName(path.TrimEnd('\\', '/')));
            if (Directory.Exists(path))
                Directory.Move(path, dest);
            else
                File.Move(path, dest);
            return dest;
        }
        catch
        {
            return null;
        }
    }
}
