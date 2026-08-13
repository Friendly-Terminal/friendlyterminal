namespace FriendlyTerminal.Core.Platform;

public sealed record DirEntry(string Name, bool IsDirectory, bool IsHidden);

public interface IFileSystem
{
    string HomeDirectory { get; }
    bool Exists(string path);
    bool IsDirectory(string path);
    IReadOnlyList<string> ListDirectory(string path);
    /// <summary>Immediate children of <paramref name="path"/> with the metadata detectors need.</summary>
    IReadOnlyList<DirEntry> ListEntries(string path);
    /// <summary>Returns false when the item could not be trashed and stays in place.</summary>
    bool MoveToTrash(string path);
    /// <summary>Returns false when the item could not be restored and remains trashed.</summary>
    bool RestoreFromTrash(string trashedPath, string originalPath);
}
