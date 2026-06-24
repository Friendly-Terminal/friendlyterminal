namespace FriendlyTerminal.Core.Platform;

public interface IFileSystem
{
    bool Exists(string path);
    bool IsDirectory(string path);
    IReadOnlyList<string> ListDirectory(string path);
    void MoveToTrash(string path);
    void RestoreFromTrash(string trashedPath, string originalPath);
}
