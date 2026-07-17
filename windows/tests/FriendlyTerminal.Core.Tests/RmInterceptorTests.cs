using FriendlyTerminal.Core.Undo;
using Xunit;

namespace FriendlyTerminal.Core.Tests;

public class RmInterceptorTests
{
    private const string Cwd = "/Users/test/project";

    [Fact]
    public void Recognizes_safe_rm_of_existing_targets()
    {
        var fs = new FakeFileSystem().AddDir("/Users/test/project/build");
        var targets = new RmInterceptor(fs).SafeTargets("rm -rf build", Cwd);
        Assert.Equal(new[] { "/Users/test/project/build" }, targets);
    }

    [Fact]
    public void Rejects_globs_and_metacharacters()
    {
        var fs = new FakeFileSystem();
        Assert.Null(new RmInterceptor(fs).SafeTargets("rm *.txt", Cwd));
    }

    [Fact]
    public void Rejects_missing_targets()
    {
        var fs = new FakeFileSystem();
        Assert.Null(new RmInterceptor(fs).SafeTargets("rm gone.txt", Cwd));
    }

    [Fact]
    public void Rejects_unknown_flags()
    {
        var fs = new FakeFileSystem().AddFile("/Users/test/project/a.txt");
        Assert.Null(new RmInterceptor(fs).SafeTargets("rm -z a.txt", Cwd));
    }

    [Theory]
    [InlineData("Remove-Item -Recurse -Force build")]
    [InlineData("del build")]
    [InlineData("rd build")]
    [InlineData("ri build")]
    [InlineData("erase build")]
    [InlineData("rmdir build")]
    [InlineData("Rm -rf build")]
    [InlineData("REMOVE-ITEM build")]
    [InlineData("rm -re -fo build")]
    public void Recognizes_powershell_deletion_forms(string command)
    {
        var fs = new FakeFileSystem().AddDir("/Users/test/project/build");
        var targets = new RmInterceptor(fs).SafeTargets(command, Cwd);
        Assert.Equal(new[] { "/Users/test/project/build" }, targets);
    }

    [Fact]
    public void Recognizes_quoted_path_with_spaces()
    {
        var fs = new FakeFileSystem().AddDir("/Users/test/project/my build");
        var targets = new RmInterceptor(fs).SafeTargets("Remove-Item -Recurse \"my build\"", Cwd);
        Assert.Equal(new[] { "/Users/test/project/my build" }, targets);
    }

    [Fact]
    public void Resolves_windows_absolute_target()
    {
        var fs = new FakeFileSystem().AddDir("C:\\proj\\build");
        var targets = new RmInterceptor(fs).SafeTargets("Remove-Item -Recurse C:\\proj\\build", "C:\\proj");
        Assert.Equal(new[] { "C:\\proj\\build" }, targets);
    }

    [Fact]
    public void Rejects_powershell_switch_that_is_not_recurse_or_force()
    {
        var fs = new FakeFileSystem().AddFile("/Users/test/project/a.txt");
        Assert.Null(new RmInterceptor(fs).SafeTargets("Remove-Item -WhatIf a.txt", Cwd));
    }

    [Fact]
    public void Rejects_unbalanced_quotes()
    {
        var fs = new FakeFileSystem().AddDir("/Users/test/project/build");
        Assert.Null(new RmInterceptor(fs).SafeTargets("rm \"build", Cwd));
    }
}
