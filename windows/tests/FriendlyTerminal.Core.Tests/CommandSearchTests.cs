using FriendlyTerminal.Core.Help;
using Xunit;

namespace FriendlyTerminal.Core.Tests;

public class CommandSearchTests
{
    [Fact]
    public void Empty_query_returns_nothing()
    {
        Assert.Empty(CommandSearch.Search(CommandCatalog.All, ""));
        Assert.Empty(CommandSearch.Search(CommandCatalog.All, "   "));
    }

    [Fact]
    public void Single_keyword_finds_web_fetch_command()
    {
        var hits = CommandSearch.Search(CommandCatalog.All, "download").ToList();
        Assert.Contains(hits, h => h.Item.Command.StartsWith("Invoke-WebRequest"));
    }

    [Fact]
    public void Delete_keeps_the_danger_flag()
    {
        var hits = CommandSearch.Search(CommandCatalog.All, "delete").ToList();
        Assert.NotEmpty(hits);
        Assert.Contains(hits, h => h.Item.IsDangerous && h.Item.Command.StartsWith("rm"));
    }

    [Fact]
    public void Admin_finds_elevated_shell_command()
    {
        var hits = CommandSearch.Search(CommandCatalog.All, "admin").ToList();
        Assert.Contains(hits, h => h.Item.Command.Contains("RunAs") && h.Item.IsDangerous);
    }

    [Fact]
    public void Search_is_case_insensitive()
    {
        // The cmdlet name lives in the keywords; the displayed command is the alias.
        var hits = CommandSearch.Search(CommandCatalog.All, "GET-CHILDITEM").ToList();
        Assert.Contains(hits, h => h.Item.Command.StartsWith("ls"));
    }

    [Fact]
    public void Category_name_match_returns_that_categorys_items()
    {
        var hits = CommandSearch.Search(CommandCatalog.All, "winget").ToList();
        Assert.NotEmpty(hits);
        Assert.All(hits, h => Assert.Equal("Winget", h.Category.Name));
    }

    [Fact]
    public void Default_enabled_set_matches_spec()
    {
        Assert.Equal(9, CommandCatalog.DefaultEnabledIds.Count);
        Assert.Contains("Navigate", CommandCatalog.DefaultEnabledIds);
        Assert.Contains("npm", CommandCatalog.DefaultEnabledIds);
    }

    [Fact]
    public void Every_category_has_a_stable_id_and_commands()
    {
        Assert.NotEmpty(CommandCatalog.All);
        Assert.All(CommandCatalog.All, c =>
        {
            Assert.False(string.IsNullOrWhiteSpace(c.Id));
            Assert.False(string.IsNullOrWhiteSpace(c.Name));
            Assert.NotEmpty(c.Commands);
        });
    }
}
