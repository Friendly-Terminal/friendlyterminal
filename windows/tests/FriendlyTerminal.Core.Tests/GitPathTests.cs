using FriendlyTerminal.Core.Output;
using Xunit;

namespace FriendlyTerminal.Core.Tests;

public class GitPathTests
{
    [Fact]
    public void Unquoted_paths_pass_through()
    {
        Assert.Equal("src/main.cs", GitPath.Unquote("src/main.cs"));
        Assert.Equal("", GitPath.Unquote(""));
        Assert.Equal("\"", GitPath.Unquote("\""));
    }

    [Fact]
    public void Plain_quoted_paths_are_unwrapped()
    {
        Assert.Equal("with space.txt", GitPath.Unquote("\"with space.txt\""));
    }

    [Fact]
    public void Octal_escapes_decode_as_utf8_bytes()
    {
        // ä = 0xC3 0xA4 = \303\244
        Assert.Equal("ä.txt", GitPath.Unquote("\"\\303\\244.txt\""));
        // 日 = 0xE6 0x97 0xA5
        Assert.Equal("日.md", GitPath.Unquote("\"\\346\\227\\245.md\""));
    }

    [Theory]
    [InlineData("\"a\\tb\"", "a\tb")]
    [InlineData("\"a\\nb\"", "a\nb")]
    [InlineData("\"a\\rb\"", "a\rb")]
    [InlineData("\"a\\\"b\"", "a\"b")]
    [InlineData("\"a\\\\b\"", "a\\b")]
    public void Backslash_escapes_decode(string quoted, string expected)
    {
        Assert.Equal(expected, GitPath.Unquote(quoted));
    }

    [Fact]
    public void Mixed_escapes_and_literals_decode_together()
    {
        Assert.Equal("dir/ä b\t.txt", GitPath.Unquote("\"dir/\\303\\244 b\\t.txt\""));
    }
}
