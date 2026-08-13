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

    public bool MoveToTrash(string path)
    {
        try
        {
            if (Directory.Exists(path))
                FileSystem.DeleteDirectory(path, UIOption.OnlyErrorDialogs, RecycleOption.SendToRecycleBin);
            else if (File.Exists(path))
                FileSystem.DeleteFile(path, UIOption.OnlyErrorDialogs, RecycleOption.SendToRecycleBin);
            return true;
        }
        catch
        {
            // Leaving the item in place is the safe failure; the caller reports it.
            return false;
        }
    }

    public bool RestoreFromTrash(string trashedPath, string originalPath)
    {
        try
        {
            if (Directory.Exists(trashedPath))
                Directory.Move(trashedPath, originalPath);
            else if (File.Exists(trashedPath))
                File.Move(trashedPath, originalPath);
            else
                return false;
            return true;
        }
        catch
        {
            return false;
        }
    }

    /// <summary>
    /// Moves an item into the app trash folder and returns where it landed, so an
    /// undo can move it back. Returns null if the move failed.
    /// </summary>
    public string? MoveToAppTrash(string path)
    {
        if (DeclinesAppTrash(path)) return null;
        try
        {
            // Directory.Move can't cross volumes, so other local drives get their own trash.
            var trashRoot = AppTrashDirectory;
            var volume = Path.GetPathRoot(Path.GetFullPath(path));
            if (!string.IsNullOrEmpty(volume) &&
                !string.Equals(volume, Path.GetPathRoot(trashRoot), StringComparison.OrdinalIgnoreCase))
                trashRoot = Path.Combine(volume, ".FriendlyTerminalTrash");
            var stamp = DateTime.Now.ToString("yyyyMMdd-HHmmss-fff");
            var dir = Path.Combine(trashRoot, stamp);
            for (var i = 1; Directory.Exists(dir); i++)
                dir = Path.Combine(trashRoot, $"{stamp}-{i}");
            Directory.CreateDirectory(dir);
            // Drive-root trash has no AppData cover; hide it from listings.
            try { File.SetAttributes(trashRoot, File.GetAttributes(trashRoot) | FileAttributes.Hidden); }
            catch { }
            var dest = Path.Combine(dir, Path.GetFileName(path.TrimEnd('\\', '/')));
            if (Directory.Exists(path))
                Directory.Move(path, dest);
            else
                File.Move(path, dest);
            // Sidecar so the trash panel can restore later; losing it only costs restore.
            try { File.WriteAllText(Path.Combine(dir, MetaFileName), Path.GetFullPath(path)); }
            catch { }
            return dest;
        }
        catch
        {
            return null;
        }
    }

    /// <summary>
    /// Items the app trash can't hold safely: UNC paths (a share-local trash would
    /// be invisible to the trash panel, Empty and the purge) and names that collide
    /// with the sidecar, which would be overwritten. Callers must decline
    /// interception for these and let the real command run.
    /// </summary>
    public static bool DeclinesAppTrash(string path) =>
        path.StartsWith(@"\\") || path.StartsWith("//") ||
        string.Equals(Path.GetFileName(path.TrimEnd('\\', '/')), MetaFileName,
            StringComparison.OrdinalIgnoreCase);

    // MARK: - Trash panel helpers

    private const string MetaFileName = ".ft-original";

    private static IEnumerable<string> TrashRoots()
    {
        yield return AppTrashDirectory;
        DriveInfo[] drives;
        try { drives = DriveInfo.GetDrives(); }
        catch { yield break; }
        foreach (var drive in drives)
        {
            string root;
            try
            {
                if (!drive.IsReady) continue;
                root = Path.Combine(drive.RootDirectory.FullName, ".FriendlyTerminalTrash");
            }
            catch { continue; }
            if (Directory.Exists(root))
                yield return root;
        }
    }

    public static IReadOnlyList<TrashEntry> ListAppTrash()
    {
        var entries = new List<TrashEntry>();
        foreach (var root in TrashRoots())
        {
            string[] stampDirs;
            try { stampDirs = Directory.GetDirectories(root); }
            catch { continue; }
            foreach (var dir in stampDirs)
            {
                List<string> items;
                DateTime trashedAt;
                string? original = null;
                try
                {
                    items = Directory.EnumerateFileSystemEntries(dir)
                        .Where(p => !string.Equals(Path.GetFileName(p), MetaFileName, StringComparison.OrdinalIgnoreCase))
                        .ToList();
                    trashedAt = Directory.GetCreationTime(dir);
                    var meta = Path.Combine(dir, MetaFileName);
                    // The sidecar names one item's origin; ambiguous with several items.
                    if (items.Count == 1 && File.Exists(meta))
                        original = File.ReadAllText(meta).Trim();
                }
                catch { continue; }
                foreach (var item in items)
                {
                    entries.Add(new TrashEntry(
                        Path.GetFileName(item),
                        item,
                        string.IsNullOrEmpty(original) ? null : original,
                        Path.GetPathRoot(item) ?? "",
                        SizeOf(item),
                        trashedAt));
                }
            }
        }
        return entries.OrderByDescending(e => e.TrashedAt).ToList();
    }

    public static bool RestoreTrashEntry(TrashEntry entry)
    {
        if (entry.OriginalPath is null || Instance.Exists(entry.OriginalPath)) return false;
        try { Directory.CreateDirectory(Path.GetDirectoryName(entry.OriginalPath)!); }
        catch { }
        if (!Instance.RestoreFromTrash(entry.TrashedPath, entry.OriginalPath)) return false;
        // Only the sidecar remains in the stamp folder.
        try { Directory.Delete(Path.GetDirectoryName(entry.TrashedPath)!, recursive: true); }
        catch { }
        return true;
    }

    public static void EmptyAppTrash()
    {
        foreach (var root in TrashRoots())
        {
            string[] children;
            try { children = Directory.GetFileSystemEntries(root); }
            catch { continue; }
            foreach (var child in children)
            {
                try
                {
                    if (Directory.Exists(child)) Directory.Delete(child, recursive: true);
                    else File.Delete(child);
                }
                catch { }
            }
        }
    }

    public static void PurgeAppTrash(TimeSpan maxAge)
    {
        var cutoff = DateTime.Now - maxAge;
        foreach (var root in TrashRoots())
        {
            string[] stampDirs;
            try { stampDirs = Directory.GetDirectories(root); }
            catch { continue; }
            foreach (var dir in stampDirs)
            {
                try
                {
                    if (Directory.GetCreationTime(dir) < cutoff)
                        Directory.Delete(dir, recursive: true);
                }
                catch { }
            }
        }
    }

    // ponytail: full recursive walk per listing; cache sizes if trash gets huge.
    private static long SizeOf(string path)
    {
        try
        {
            if (File.Exists(path)) return new FileInfo(path).Length;
            return Directory.EnumerateFiles(path, "*", SearchOption.AllDirectories)
                .Sum(f => { try { return new FileInfo(f).Length; } catch { return 0L; } });
        }
        catch
        {
            return 0;
        }
    }
}

public sealed record TrashEntry(
    string Name,
    string TrashedPath,
    string? OriginalPath,
    string Volume,
    long SizeBytes,
    DateTime TrashedAt);
