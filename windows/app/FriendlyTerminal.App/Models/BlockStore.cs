using System.Collections.ObjectModel;
using FriendlyTerminal.Core.Output;

namespace FriendlyTerminal.App.Models;

/// <summary>Owns the ordered list of command blocks for one terminal session.</summary>
public sealed class BlockStore
{
    private readonly OutputRenderingPipeline _pipeline;

    public BlockStore(OutputRenderingPipeline pipeline) => _pipeline = pipeline;

    public ObservableCollection<CommandBlock> Blocks { get; } = new();

    public CommandBlock? CurrentBlock => Blocks.LastOrDefault(b => b.IsRunning);
    public CommandBlock? LastFinishedBlock => Blocks.LastOrDefault(b => !b.IsRunning);
    public CommandBlock? LastUndoableBlock => Blocks.LastOrDefault(b => b.UndoPlan is not null && !b.IsUndone);

    public void StartBlock(string command, string cwd) => Blocks.Add(new CommandBlock(command, cwd));

    public void AppendOutput(string text)
    {
        if (CurrentBlock is { } block)
            block.PlainText += text;
    }

    public void FinishBlock(int exitCode)
    {
        if (CurrentBlock is not { } block) return;
        block.Duration = DateTime.Now - block.StartedAt;
        block.ExitCode = exitCode;
        var kind = _pipeline.Process(block.PlainText, block.Command, block.Cwd);
        block.RenderKind = kind ?? (block.Failed
            ? new RenderKind.ErrorHighlighted()
            : new RenderKind.PlainText());
    }

    public void Clear() => Blocks.Clear();
}
