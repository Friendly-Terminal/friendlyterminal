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
    void MoveToTrash(string path);
    void RestoreFromTrash(string trashedPath, string originalPath);
}
