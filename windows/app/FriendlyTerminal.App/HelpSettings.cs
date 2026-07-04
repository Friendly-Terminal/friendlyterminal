using System.IO;
using System.Text.Json;
using FriendlyTerminal.Core.Help;

namespace FriendlyTerminal.App;

/// <summary>
/// Persists which command-help categories the user has chosen to show in the sidebar.
/// Mirrors the macOS CommandHelpSettings. This is an unpackaged app, so state is stored
/// as JSON under %LOCALAPPDATA%\FriendlyTerminal rather than ApplicationData.LocalSettings.
/// </summary>
public sealed class HelpSettings
{
    public static HelpSettings Instance { get; } = new();

    private readonly string _path;
    private HashSet<string> _enabled;

    private HelpSettings()
    {
        var dir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "FriendlyTerminal");
        _path = Path.Combine(dir, "help-settings.json");
        _enabled = Load() ?? new HashSet<string>(CommandCatalog.DefaultEnabledIds);
    }

    public bool IsEnabled(string id) => _enabled.Contains(id);

    /// <summary>Category IDs enabled, in the canonical catalog order.</summary>
    public IReadOnlyList<string> EnabledIds =>
        CommandCatalog.All.Select(c => c.Id).Where(_enabled.Contains).ToList();

    public void SetEnabled(string id, bool enabled)
    {
        if (enabled ? _enabled.Add(id) : _enabled.Remove(id))
            Save();
    }

    private HashSet<string>? Load()
    {
        try
        {
            if (!File.Exists(_path)) return null;
            var ids = JsonSerializer.Deserialize<string[]>(File.ReadAllText(_path));
            return ids is null ? null : new HashSet<string>(ids);
        }
        catch
        {
            return null;
        }
    }

    private void Save()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(_path)!);
            File.WriteAllText(_path, JsonSerializer.Serialize(_enabled.ToArray()));
        }
        catch
        {
            // Best-effort persistence; a failed write should not crash the UI.
        }
    }
}
