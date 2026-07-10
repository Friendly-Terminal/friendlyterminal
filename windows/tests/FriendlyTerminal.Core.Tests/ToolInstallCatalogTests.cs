using FriendlyTerminal.Core.Help;
using Xunit;

namespace FriendlyTerminal.Core.Tests;

public class ToolInstallCatalogTests
{
    [Fact]
    public void Known_tool_is_found_case_insensitively()
    {
        var tool = ToolInstallCatalog.Lookup("Python");
        Assert.NotNull(tool);
        Assert.Equal("Python.Python.3.12", tool!.WingetId);
    }

    [Fact]
    public void Npm_maps_to_nodejs()
    {
        Assert.Equal("OpenJS.NodeJS.LTS", ToolInstallCatalog.Lookup("npm")!.WingetId);
    }

    [Fact]
    public void Unknown_term_returns_null()
    {
        Assert.Null(ToolInstallCatalog.Lookup("frobnicate"));
    }

    [Fact]
    public void Install_command_pins_the_exact_id()
    {
        var command = ToolInstallCatalog.InstallCommand(ToolInstallCatalog.Lookup("git")!);
        Assert.StartsWith("winget install --id Git.Git -e", command);
    }
}
