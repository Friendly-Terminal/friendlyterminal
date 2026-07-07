namespace FriendlyTerminal.Core.ShellIntegration;

/// <summary>
/// One shell-integration event pulled out of the PTY stream. Mirrors the macOS
/// ShellIntegrationParser.Event cases.
/// </summary>
public abstract record ShellEvent
{
    public sealed record PromptStart : ShellEvent;
    public sealed record CommandStart : ShellEvent;
    public sealed record OutputStart : ShellEvent;
    public sealed record CommandEnd(int ExitCode) : ShellEvent;
    public sealed record CommandText(string Text) : ShellEvent;
    public sealed record CwdUpdate(string Path) : ShellEvent;
    public sealed record Output(string Text) : ShellEvent;
    public sealed record AltScreen(bool On) : ShellEvent;
    public sealed record BracketedPaste(bool On) : ShellEvent;
}
