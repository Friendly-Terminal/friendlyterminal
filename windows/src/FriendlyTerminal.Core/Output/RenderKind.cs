namespace FriendlyTerminal.Core.Output;

public abstract record RenderKind
{
    public sealed record PlainText : RenderKind;
    public sealed record ErrorHighlighted : RenderKind;
    public sealed record Table(IReadOnlyList<string[]> Rows) : RenderKind;
    public sealed record CsvTable(IReadOnlyList<string[]> Rows) : RenderKind;
    public sealed record JsonTree : RenderKind;
    public sealed record ImageFile(string Path) : RenderKind;
    public sealed record CommandList(string Hint, IReadOnlyList<CommandListItem> Items) : RenderKind;
}

public sealed record CommandListItem(string Label, string? Detail, string Icon, string FollowUp);
