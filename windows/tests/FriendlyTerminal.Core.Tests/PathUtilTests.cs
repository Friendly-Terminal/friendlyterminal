using FriendlyTerminal.Core.Platform;
using Xunit;

namespace FriendlyTerminal.Core.Tests;

public class PathUtilTests
{
    [Theory]
    [InlineData("C:\\data\\x")]
    [InlineData("C:/data/x")]
    [InlineData("\\\\server\\share")]
    [InlineData("\\rooted")]
    [InlineData("/rooted")]
    public void Resolve_returns_rooted_paths_unchanged(string path)
    {
        Assert.Equal(path, PathUtil.Resolve(path, "C:\\work", "C:\\Users\\me"));
    }

    [Fact]
    public void Resolve_does_not_combine_a_windows_absolute_path_onto_cwd()
    {
        // Regression: an absolute target must not be joined onto cwd.
        var result = PathUtil.Resolve("C:\\data\\x", "C:\\work", "C:\\Users\\me");
        Assert.Equal("C:\\data\\x", result);
    }

    [Fact]
    public void Combine_uses_backslash_for_windows_cwd()
    {
        Assert.Equal("C:\\work\\build", PathUtil.Combine("C:\\work", "build"));
    }

    [Fact]
    public void Combine_uses_forward_slash_for_posix_cwd()
    {
        Assert.Equal("/Users/test/project/build", PathUtil.Combine("/Users/test/project", "build"));
    }

    [Fact]
    public void Combine_avoids_double_separators()
    {
        Assert.Equal("C:\\work\\build", PathUtil.Combine("C:\\work\\", "build"));
        Assert.Equal("/tmp/build", PathUtil.Combine("/tmp/", "build"));
    }

    [Fact]
    public void Resolve_joins_relative_paths_onto_windows_cwd()
    {
        Assert.Equal("C:\\work\\..\\x", PathUtil.Resolve("..\\x", "C:\\work", "C:\\Users\\me"));
        Assert.Equal("C:\\work\\sub\\file", PathUtil.Resolve("sub\\file", "C:\\work", "C:\\Users\\me"));
    }

    [Fact]
    public void LastComponent_handles_backslash_paths()
    {
        Assert.Equal("demo", PathUtil.LastComponent("C:\\Projects\\demo"));
        Assert.Equal("demo", PathUtil.LastComponent("C:\\Projects\\demo\\"));
        Assert.Equal("build", PathUtil.LastComponent("/Users/test/build"));
    }

    [Fact]
    public void Resolve_expands_tilde()
    {
        Assert.Equal("C:\\Users\\me\\notes", PathUtil.Resolve("~\\notes", "C:\\work", "C:\\Users\\me"));
    }
}
