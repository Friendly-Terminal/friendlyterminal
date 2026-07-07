namespace FriendlyTerminal.App.Models;

/// <summary>
/// Sidebar cheat card for the interactive program currently holding the
/// keyboard (vim, nano, pagers, monitors, Claude). Windows-adapted port of the
/// macOS ProgramHint. Glyphs are Segoe Fluent Icons code points.
/// </summary>
public sealed record ProgramHint(
    string Title,
    string Subtitle,
    int Glyph,
    IReadOnlyList<ProgramHint.KeyHint> Keys,
    IReadOnlyList<ProgramHint.ActionHint> Actions)
{
    public sealed record KeyHint(string Key, string Description);

    /// <summary>A one-tap button that sends the right key sequence so the user
    /// doesn't have to know it (e.g. "Quit" sends `q`).</summary>
    public sealed record ActionHint(string Label, int Glyph, string Sequence, bool Destructive = false);

    private static readonly string[] WrapperTokens = { "sudo", "command", "exec", "time", "env" };

    // Raw key bytes, built from code points so no control characters live in source.
    private static readonly string Esc = ((char)0x1B).ToString();
    private static readonly string CtrlC = ((char)0x03).ToString();
    private static readonly string CtrlS = ((char)0x13).ToString();
    private static readonly string CtrlX = ((char)0x18).ToString();

    public static ProgramHint Detect(string command) => PrimaryProgram(command) switch
    {
        "claude" => Claude,
        "vim" or "vi" or "nvim" or "view" => Vim,
        "nano" or "pico" => Nano,
        "emacs" => Emacs,
        "less" or "more" or "man" or "git" => Pager,
        "top" or "htop" or "btop" or "ntop" => Monitor,
        _ => Generic,
    };

    private static string PrimaryProgram(string command)
    {
        var lastStage = command.Split('|')[^1];
        foreach (var token in lastStage.Split(' ', '\t').Where(t => t.Length > 0))
        {
            if (token.Contains('=')) continue;
            if (WrapperTokens.Contains(token)) continue;
            return System.IO.Path.GetFileNameWithoutExtension(token).ToLowerInvariant();
        }
        return "";
    }

    public static readonly ProgramHint Claude = new(
        "Claude Code",
        "Use the sidebar controls to drive Claude — no typing needed.",
        0xE99A,
        new KeyHint[]
        {
            new("y + Enter", "Approve a permission prompt"),
            new("n + Enter", "Reject a permission prompt"),
            new("Ctrl C", "Stop the current operation"),
            new("/clear", "Clear conversation history"),
            new("/exit", "Exit Claude and return to shell"),
        },
        Array.Empty<ActionHint>());

    public static readonly ProgramHint Pager = new(
        "Text viewer",
        "You're reading a document.",
        0xE8A5,
        new KeyHint[]
        {
            new("Space", "Scroll down one page"),
            new("b", "Scroll up one page"),
            new("Up/Down", "Move one line"),
            new("/", "Search for text"),
            new("q", "Quit and go back"),
        },
        new ActionHint[]
        {
            new("Quit (go back)", 0xE711, "q"),
            new("Page down", 0xE74B, " "),
            new("Page up", 0xE74A, "b"),
        });

    public static readonly ProgramHint Vim = new(
        "Vim editor",
        "A text editor. Use the buttons to get out:",
        0xE70F,
        new KeyHint[]
        {
            new("i", "Start typing (insert mode)"),
            new("Esc", "Stop typing"),
            new(":w", "Save (then Enter)"),
            new(":q", "Quit (then Enter)"),
            new(":wq", "Save and quit"),
            new(":q!", "Quit without saving"),
        },
        new ActionHint[]
        {
            new("Save & quit", 0xE74E, Esc + ":wq\r"),
            new("Quit, discard changes", 0xE711, Esc + ":q!\r", Destructive: true),
        });

    public static readonly ProgramHint Nano = new(
        "Nano editor",
        "A simple text editor.",
        0xE70F,
        new KeyHint[]
        {
            new("type", "Just type to edit"),
            new("Ctrl O", "Save (then Enter)"),
            new("Ctrl X", "Exit"),
            new("Ctrl K", "Cut current line"),
            new("Ctrl W", "Search"),
        },
        new ActionHint[]
        {
            new("Save & exit", 0xE74E, CtrlX + "y\r"),
            new("Exit without saving", 0xE711, CtrlX + "n", Destructive: true),
        });

    public static readonly ProgramHint Emacs = new(
        "Emacs editor",
        "A text editor.",
        0xE70F,
        new KeyHint[]
        {
            new("Ctrl X Ctrl S", "Save"),
            new("Ctrl X Ctrl C", "Exit"),
            new("Ctrl G", "Cancel current action"),
        },
        new ActionHint[]
        {
            new("Save", 0xE74E, CtrlX + CtrlS),
            new("Exit", 0xE711, CtrlX + CtrlC),
        });

    public static readonly ProgramHint Monitor = new(
        "System monitor",
        "A live activity view.",
        0xE9D9,
        new KeyHint[]
        {
            new("q", "Quit"),
            new("Space", "Refresh now"),
            new("Up/Down", "Scroll the list"),
        },
        new ActionHint[]
        {
            new("Quit", 0xE711, "q"),
        });

    public static readonly ProgramHint Generic = new(
        "Interactive program",
        "This program is reading the keyboard.",
        0xE765,
        new KeyHint[]
        {
            new("q", "Often quits"),
            new("Ctrl C", "Interrupt / stop"),
            new("Esc", "Cancel"),
        },
        new ActionHint[]
        {
            new("Try to quit", 0xE711, "q"),
            new("Force stop", 0xE71A, CtrlC, Destructive: true),
        });
}
