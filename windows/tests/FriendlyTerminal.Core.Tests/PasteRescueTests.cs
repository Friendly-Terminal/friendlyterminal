using FriendlyTerminal.Core.Help;
using Xunit;

namespace FriendlyTerminal.Core.Tests;

public class PasteRescueTests
{
    [Fact]
    public void Plain_text_passes_through_untouched()
    {
        var result = PasteRescue.Clean("git status");
        Assert.Equal(new[] { "git status" }, result.Lines);
        Assert.Null(result.RemovedPrefix);
        Assert.Equal(0, result.SkippedComments);
    }

    [Fact]
    public void Dollar_prompt_prefix_is_stripped_and_reported()
    {
        var result = PasteRescue.Clean("$ npm install");
        Assert.Equal(new[] { "npm install" }, result.Lines);
        Assert.Equal("$", result.RemovedPrefix);
    }

    [Fact]
    public void Powershell_prompt_with_path_is_stripped()
    {
        var result = PasteRescue.Clean(@"PS C:\Users\me> Get-Date");
        Assert.Equal(new[] { "Get-Date" }, result.Lines);
        Assert.Equal("PS>", result.RemovedPrefix);
    }

    [Fact]
    public void Bare_ps_prompt_is_stripped()
    {
        var result = PasteRescue.Clean("PS> git log");
        Assert.Equal(new[] { "git log" }, result.Lines);
    }

    [Fact]
    public void Cmd_prompt_is_stripped()
    {
        var result = PasteRescue.Clean(@"C:\Projects\app> dir");
        Assert.Equal(new[] { "dir" }, result.Lines);
        Assert.Equal("C:\\>", result.RemovedPrefix);
    }

    [Fact]
    public void Generic_angle_prompt_is_stripped()
    {
        var result = PasteRescue.Clean("> node file.js");
        Assert.Equal(new[] { "node file.js" }, result.Lines);
        Assert.Equal(">", result.RemovedPrefix);
    }

    [Fact]
    public void Env_variable_syntax_is_not_mistaken_for_a_prompt()
    {
        var result = PasteRescue.Clean("$env:PATH");
        Assert.Equal(new[] { "$env:PATH" }, result.Lines);
        Assert.Null(result.RemovedPrefix);
    }

    [Fact]
    public void Multi_line_paste_splits_and_drops_blank_lines()
    {
        var result = PasteRescue.Clean("$ cd app\r\n\r\n$ npm install\n$ npm run dev\n");
        Assert.Equal(new[] { "cd app", "npm install", "npm run dev" }, result.Lines);
        Assert.Equal("$", result.RemovedPrefix);
    }

    [Fact]
    public void Comment_lines_are_skipped_and_counted()
    {
        var result = PasteRescue.Clean("# install the deps\nnpm install\n# then start it\nnpm start");
        Assert.Equal(new[] { "npm install", "npm start" }, result.Lines);
        Assert.Equal(2, result.SkippedComments);
    }

    [Fact]
    public void Comment_only_paste_yields_no_lines()
    {
        var result = PasteRescue.Clean("# just a note");
        Assert.Empty(result.Lines);
        Assert.Equal(1, result.SkippedComments);
    }

    [Fact]
    public void Indented_snippet_from_markdown_is_trimmed()
    {
        var result = PasteRescue.Clean("    $ git push");
        Assert.Equal(new[] { "git push" }, result.Lines);
        Assert.Equal("$", result.RemovedPrefix);
    }
}
